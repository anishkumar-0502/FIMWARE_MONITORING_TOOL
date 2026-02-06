import 'dart:async';
import 'dart:typed_data';
import 'package:get/get.dart';
import '../../../data/models/bms_data.dart';
import '../../../data/models/bms_frame.dart';
import '../../../data/models/predefined_command.dart';
import '../../../data/services/serial_service.dart';
import '../../../data/services/logging_service.dart';

class BmsController extends GetxController {
  final SerialService _serialService = Get.find<SerialService>();
  final LoggingService _logService = Get.find<LoggingService>();

  final Rx<BmsData> bmsData = BmsData.empty().obs;
  final RxBool isPolling = false.obs;
  Timer? _pollingTimer;

  final List<PredefinedCommand> predefinedCommands = [
    PredefinedCommand(name: "NET_MODE_4G", hexData: "01 01"),
    PredefinedCommand(name: "ETHERNET", hexData: "01 02"),
    PredefinedCommand(name: "PERCENTAGE", hexData: "02 02"),
    PredefinedCommand(name: "VOLTAGE_MSB", hexData: "03 02 00"),
    PredefinedCommand(name: "VOLTAGE_LSB", hexData: "03 00 00 13 D9"),
    PredefinedCommand(name: "CURRENT_MSB", hexData: "04 00 00"),
    PredefinedCommand(name: "CURRENT_LSB", hexData: "04 00 00 00 00"),
    PredefinedCommand(name: "IP_PORT", hexData: "05 AC EB 1D 43 0C E4"),
    PredefinedCommand(name: "PRINT_ALL_VALUES", hexData: "06"),
    PredefinedCommand(name: "DOMAIN_NAME", hexData: "07 AC EB 1D 43 3A 0C E4"),
    PredefinedCommand(name: "END_POINT", hexData: "08 65 6E 64 2F 62 6D 73"),
    PredefinedCommand(name: "4G_URL", hexData: "09 68 74 74 70 73 3A 2F 2F 73 65 6E 73 65 64 67 65 74 73 73 2E 69 6E 2F 64 65 6D 6F 73 2F 62 68 6D 73 2F 6F 75 74 64 69 64 2F 73 65 6E 64 2D 69 70 2D 64 61 74 61"),
    PredefinedCommand(name: "PRINT_DEBUG_MSG", hexData: "0A 01"),
    PredefinedCommand(name: "PRINT_ALL_INFORMATION", hexData: "0A 02"),
    PredefinedCommand(name: "TEMPERATURE_MSB", hexData: "0B 00 00"),
    PredefinedCommand(name: "TEMPERATURE_LSB", hexData: "0B 00 00 00 00"),
    PredefinedCommand(name: "CURRENT_THRESHOLD_MSB", hexData: "0C 00 00"),
    PredefinedCommand(name: "CURRENT_THRESHOLD_LSB", hexData: "0C 00 00 00 00"),
  ];

  final RxBool showTerminal = false.obs;

  void toggleTerminal() {
    showTerminal.value = !showTerminal.value;
  }

  @override
  void onInit() {
    super.onInit();
    _serialService.receivedDataStream.listen(_handleDataReceived);
  }

  final List<int> _rxBuffer = [];

  void _handleDataReceived(Uint8List data) {
    _logService.logFrame("RX", data);
    _rxBuffer.addAll(data);
    
    // Process buffer to find frames
    while (_rxBuffer.length >= 6) {
      // Look for header 0xAA
      if (_rxBuffer[0] != 0xAA) {
        _rxBuffer.removeAt(0);
        continue;
      }
      
      final length = _rxBuffer[3];
      final totalFrameSize = 4 + length + 2;
      
      if (_rxBuffer.length < totalFrameSize) break; // Wait for more data
      
      final frameData = Uint8List.fromList(_rxBuffer.sublist(0, totalFrameSize));
      
      try {
        final frame = BmsFrame.parse(frameData);
        if (frame != null && frame.command == 0x03) {
          bmsData.value = BmsData.fromPayload(frame.payload);
        }
      } catch (e) {
        _logService.error("Parse error: $e");
      }
      
      // Remove processed frame
      _rxBuffer.removeRange(0, totalFrameSize);
    }
  }

  Future<void> sendCommand(int command, Uint8List payload) async {
    final frame = BmsFrame.build(
      header: 0xAA,
      deviceId: 0x01,
      command: command,
      payload: payload,
    );
    
    _logService.logFrame("TX", frame);
    await _serialService.write(frame);
  }

  final RxString customInput = "".obs;
  final RxString selectedFormat = "HEX".obs;
  final RxString searchQuery = "".obs;
  final Rx<Uint8List> currentBytes = Uint8List(0).obs;
  final List<String> formats = ["ASCII", "HEX", "Decimal", "Binary"];

  List<PredefinedCommand> get filteredCommands {
    if (searchQuery.isEmpty) return predefinedCommands;
    return predefinedCommands.where((cmd) => 
      cmd.name.toLowerCase().contains(searchQuery.value.toLowerCase())
    ).toList();
  }

  void selectPredefinedCommand(PredefinedCommand cmd) {
    currentBytes.value = sendRawParseHex(cmd.hexData);
    _updateInputFromBytes();
  }

  void _updateInputFromBytes() {
    final bytes = currentBytes.value;
    if (bytes.isEmpty) {
      customInput.value = "";
      return;
    }

    switch (selectedFormat.value) {
      case "ASCII":
        customInput.value = String.fromCharCodes(bytes.map((b) => (b >= 32 && b <= 126) ? b : 46));
        break;
      case "Decimal":
        customInput.value = bytes.join(' ');
        break;
      case "Binary":
        customInput.value = bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');
        break;
      case "HEX":
      default:
        customInput.value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        break;
    }
  }

  void updateFormat(String newFormat) {
    selectedFormat.value = newFormat;
    _updateInputFromBytes();
  }

  void onInputChange(String value) {
    try {
      currentBytes.value = _parseInput(value, selectedFormat.value);
    } catch (_) {}
  }

  Uint8List sendRawParseHex(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleanHex.isEmpty) return Uint8List(0);
    if (cleanHex.length % 2 != 0) return Uint8List(0);
    final bytes = Uint8List(cleanHex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  Uint8List _parseInput(String input, String format) {
    input = input.trim();
    if (input.isEmpty) return Uint8List(0);

    switch (format) {
      case "ASCII":
        return Uint8List.fromList(input.codeUnits);
      case "Decimal":
        try {
          return Uint8List.fromList(
            input.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).map((e) => int.parse(e.trim())).toList(),
          );
        } catch (e) {
          throw Exception("Invalid decimal format");
        }
      case "Binary":
        try {
          return Uint8List.fromList(
            input.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).map((e) => int.parse(e.trim(), radix: 2)).toList(),
          );
        } catch (e) {
          throw Exception("Invalid binary format");
        }
      case "HEX":
      default:
        try {
          return sendRawParseHex(input);
        } catch (e) {
          throw Exception("Invalid hex format");
        }
    }
  }

  Future<void> sendCustom() async {
    try {
      if (currentBytes.value.isNotEmpty) {
        await sendRaw(currentBytes.value, "Manual (${selectedFormat.value})");
      }
    } catch (e) {
      _logService.error("Send error: $e");
    }
  }

  Future<void> sendRaw(Uint8List data, String name) async {
    _logService.logFrame("TX", data, message: "Raw: $name");
    await _serialService.write(data);
  }

  void startPolling() {
    isPolling.value = true;
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (_serialService.isConnected) {
        sendCommand(0x03, Uint8List(0)); // Request status
      }
    });
  }

  void stopPolling() {
    isPolling.value = false;
    _pollingTimer?.cancel();
  }

  @override
  void onClose() {
    stopPolling();
    super.onClose();
  }
}
