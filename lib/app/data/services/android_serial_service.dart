import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:get/get.dart';
import 'serial_service.dart';
import 'logging_service.dart';

class AndroidSerialService extends SerialService {
  final _logService = Get.find<LoggingService>();
  UsbPort? _port;
  StreamSubscription? _subscription;

  @override
  Future<List<String>> getAvailablePorts() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    return devices.map((d) => d.deviceName).toList();
  }

  @override
  Future<bool> connect({
    required String portName,
    required int baudRate,
    int dataBits = 8,
    int stopBits = 1,
    int parity = 0,
  }) async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      UsbDevice? device = devices.firstWhere((d) => d.deviceName == portName);
      
      UsbPort? port = await device.create();
      if (port == null) return false;

      bool openResult = await port.open();
      if (!openResult) return false;

      await port.setPortParameters(baudRate, dataBits, stopBits, parity);
      
      _port = port;
      _subscription = _port!.inputStream!.listen((data) {
        onDataReceived(data);
      });

      isConnected = true;
      return true;
    } catch (e) {
      _logService.error("Android connection error: $e");
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _port?.close();
    isConnected = false;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_port != null && isConnected) {
      await _port!.write(data);
    }
  }
}
