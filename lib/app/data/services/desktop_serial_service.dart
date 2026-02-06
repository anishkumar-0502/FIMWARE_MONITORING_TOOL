import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart' as lib_serial;
import 'package:serial_port_win32/serial_port_win32.dart' as win32_serial;
import 'serial_service.dart';
import 'logging_service.dart';

class DesktopSerialService extends SerialService {
  final _logService = Get.find<LoggingService>();
  
  // Windows-specific
  win32_serial.SerialPort? _winPort;
  
  // Linux/macOS fallback
  lib_serial.SerialPort? _libPort;
  lib_serial.SerialPortReader? _libReader;
  StreamSubscription? _subscription;

  bool _isReading = false;

  @override
  Future<List<String>> getAvailablePorts() async {
    if (Platform.isWindows) {
      return win32_serial.SerialPort.getAvailablePorts();
    }
    return lib_serial.SerialPort.availablePorts;
  }

  // Store baud rate for write timing
  int _currentBaudRate = 9600;

  @override
  Future<bool> connect({
    required String portName,
    required int baudRate,
    int dataBits = 8,
    int stopBits = 1,
    int parity = 0,
  }) async {
    _currentBaudRate = baudRate;
    try {
      await disconnect();
      
      if (Platform.isWindows) {
        return _connectWindows(portName, baudRate, dataBits, stopBits, parity);
      } else {
        return _connectLibSerial(portName, baudRate, dataBits, stopBits, parity);
      }
    } catch (e) {
      _logService.error("Connection error: $e");
      return false;
    }
  }

  Future<bool> _connectWindows(String portName, int baudRate, int dataBits, int stopBits, int parity) async {
    try {
      // For Windows COM ports > 9, the \\.\ prefix is mandatory.
      final fullPortName = portName.startsWith(r'\\.\') ? portName : r'\\.\' + portName;

      // Create port with NO settings to avoid immediate SetCommState failures
      _winPort = win32_serial.SerialPort(fullPortName, openNow: false);
      
      try {
        await _winPort!.open();
      } catch (e) {
        // If SetCommState failed but the port is actually opened, we treat it as a warning
        if (e.toString().contains("SetCommState") && _winPort!.isOpened) {
          _logService.info("Win32: Open succeeded with SetCommState warning (Error 0)");
        } else {
          // Fallback to raw port name if prefix failed
          _winPort = win32_serial.SerialPort(portName, openNow: false);
          await _winPort!.open();
        }
      }
      
      if (!_winPort!.isOpened) {
        _logService.error("Win32: Failed to open $portName.");
        return false;
      }

      // Small delay to allow driver to settle
      await Future.delayed(const Duration(milliseconds: 100));

      // Map stop bits: 1 -> ONESTOPBIT (0), 2 -> TWOSTOPBITS (2)
      int winStopBits = 0; 
      if (stopBits == 2) winStopBits = 2;
      else if (stopBits == 1.5) winStopBits = 1;

      // Apply settings individually and SILENTLY ignore errors if the port is already working
      try {
        _winPort!.BaudRate = baudRate;
        _winPort!.ByteSize = dataBits;
        _winPort!.StopBits = winStopBits;
        _winPort!.Parity = parity;
      } catch (e) {
        _logService.info("Win32: Note - Some port settings could not be applied ($e).");
      }

      isConnected = true;
      _isReading = true;
      _startReadLoop();

      _logService.info("Win32: Connected to $portName @ $baudRate");
      return true;
    } catch (e) {
      _logService.error("Win32 Connection Error: $e");
      return false;
    }
  }

  void _startReadLoop() async {
    while (isConnected && _isReading && _winPort != null) {
      try {
        final port = _winPort;
        if (port == null || !port.isOpened) break;

        // Use a safe read with explicit length and timeout
        final data = await port.readBytes(1024, timeout: const Duration(milliseconds: 50));
        if (data.isNotEmpty) {
          onDataReceived(data);
        }
      } catch (e) {
        if (!e.toString().contains("timeout")) {
          _logService.error("Win32 Read Loop Error: $e");
        }
        if (e.toString().contains("closed") || e.toString().contains("handle")) break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isReading = false;
  }

  Future<bool> _connectLibSerial(String portName, int baudRate, int dataBits, int stopBits, int parity) async {
    _libPort = lib_serial.SerialPort(portName);
    if (!_libPort!.openReadWrite()) {
      return false;
    }
    
    _libPort!.config = lib_serial.SerialPortConfig()
      ..baudRate = baudRate
      ..bits = dataBits
      ..stopBits = stopBits
      ..parity = parity;

    _libReader = lib_serial.SerialPortReader(_libPort!);
    _subscription = _libReader!.stream.listen((data) => onDataReceived(data));
    
    isConnected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _isReading = false;
    isConnected = false;
    
    // Give read loop time to stop
    await Future.delayed(const Duration(milliseconds: 50));

    // Cleanup Windows
    try {
      _winPort?.close();
    } catch (_) {}
    _winPort = null;

    // Cleanup LibSerial
    await _subscription?.cancel();
    _subscription = null;
    try {
      _libPort?.close();
      _libPort?.dispose();
    } catch (_) {}
    _libPort = null;
    _libReader = null;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (!isConnected) return;

    if (Platform.isWindows && _winPort != null) {
      try {
        final port = _winPort;
        if (port == null || !port.isOpened) return;

        // Toggle RTS for RS485 half-duplex direction control
        try {
          port.setFlowControlSignal(win32_serial.SerialPort.SETDTR);
          port.setFlowControlSignal(win32_serial.SerialPort.SETRTS);
        } catch (_) {}
        
        final success = await _winPort!.writeBytesFromUint8List(data);
        
        // Calculate transmission time: (bits_per_byte / baud_rate) * data_length * 1000ms
        // bit_per_byte is usually 10 (1 start, 8 data, 1 stop)
        final txTimeMs = ((10 / _currentBaudRate) * data.length * 1000).ceil();
        // Give extra buffer for RS485 turnaround
        await Future.delayed(Duration(milliseconds: txTimeMs + 10));
        
        try {
          _winPort!.setFlowControlSignal(win32_serial.SerialPort.CLRRTS);
          _winPort!.setFlowControlSignal(win32_serial.SerialPort.CLRDTR);
        } catch (_) {}

        if (!success) {
          _logService.error("Win32: Failed to write bytes to port.");
        }
      } catch (e) {
        _logService.error("Win32 Write Error: $e");
      }
    } else if (_libPort != null) {
      _libPort!.write(data);
    }
  }
}
