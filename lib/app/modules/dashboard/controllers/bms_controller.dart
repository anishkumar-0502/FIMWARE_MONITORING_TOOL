import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
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

  final RxList<SendSequence> sendSequences = <SendSequence>[
    SendSequence(name: "NET_MODE_4G", sequence: "01 01"),
    SendSequence(name: "ETHERNET", sequence: "01 02"),
    SendSequence(name: "PERCENTAGE", sequence: "02 02"),
    SendSequence(name: "VOLTAGE_MIN", sequence: "03 01"),
    SendSequence(name: "VOLTAGE_MAX", sequence: "03 00 00 13"),
    SendSequence(name: "CURRENT_MIN", sequence: "04 01"),
    SendSequence(name: "CURRENT_MAX", sequence: "04 00 00 03"),
    SendSequence(name: "IP_PORT", sequence: "05 1D 43 0C"),
    SendSequence(name: "RTC", sequence: "06 05 02 1A 01 0F 02 28"),
    SendSequence(name: "DOMAIN_NAME", sequence: "07 1D 43 0C"),
    SendSequence(name: "END_POINT", sequence: "08 65 6E 64 2F 62 6D 73"),
    SendSequence(name: "4G_URL", sequence: "09 68 74 74 70 73 3A 2F 2F 73 65 6E 73 65 64 67 65 74 73 73 2E 69 6E 2F 64 65 6D 6F 73 2F 62 68 6D 73 2F 6F 75 74"),
    SendSequence(name: "PRINT_DEBUG_MSG", sequence: "0A 01"),
    SendSequence(name: "PRINT_ALL_INFORMATION", sequence: "0A 02"),
    SendSequence(name: "TEMPERATURE_thershlod", sequence: "0B 00 00"),
    SendSequence(name: "CURRENT_THERSHOLD", sequence: "0C 0B"),
  ].obs;

  final RxList<ReceiveSequence> receiveSequences = <ReceiveSequence>[
    ReceiveSequence(name: "Example Response", sequence: "AA 01 03", answer: "OK"),
  ].obs;

  final RxString searchQuery = "".obs;
  final RxString customInput = "".obs;
  final RxString selectedFormat = "HEX".obs;
  final Rx<Uint8List> currentBytes = Uint8List(0).obs;
  final List<String> formats = ["ASCII", "HEX", "Decimal", "Binary"];
  final RxBool showTerminal = true.obs;
  final RxInt selectedSendIndex = (-1).obs;
  
  final TextEditingController commandInputController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _serialService.receivedDataStream.listen(_handleDataReceived);
    loadSequences();
  }

  // Local Persistence
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/sequences.json');
  }

  Future<void> saveSequences() async {
    try {
      final file = await _localFile;
      final data = {
        'send': sendSequences.map((s) => s.toJson()).toList(),
        'receive': receiveSequences.map((r) => r.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      _logService.error("Failed to save sequences: $e");
    }
  }

  Future<void> loadSequences() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        if (data['send'] != null) {
          sendSequences.assignAll((data['send'] as List).map((s) => SendSequence.fromJson(s)).toList());
        }
        if (data['receive'] != null) {
          receiveSequences.assignAll((data['receive'] as List).map((r) => ReceiveSequence.fromJson(r)).toList());
        }
      }
    } catch (e) {
      _logService.error("Failed to load sequences: $e");
    }
  }

  List<SendSequence> get filteredSendSequences {
    if (searchQuery.isEmpty) return sendSequences;
    return sendSequences.where((s) => s.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
  }

  List<ReceiveSequence> get filteredReceiveSequences {
    if (searchQuery.isEmpty) return receiveSequences;
    return receiveSequences.where((s) => s.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();
  }

  void addSendSequence(String name, String sequence) {
    sendSequences.add(SendSequence(name: name, sequence: sequence));
    saveSequences();
  }

  void updateSendSequence(int index, String name, String sequence) {
    sendSequences[index] = SendSequence(name: name, sequence: sequence);
    saveSequences();
  }

  void removeSendSequence(int index) {
    sendSequences.removeAt(index);
    saveSequences();
  }

  void addReceiveSequence(String name, String sequence, String answer) {
    receiveSequences.add(ReceiveSequence(name: name, sequence: sequence, answer: answer));
    saveSequences();
  }

  void updateReceiveSequence(int index, String name, String sequence, String answer) {
    receiveSequences[index] = ReceiveSequence(name: name, sequence: sequence, answer: answer);
    saveSequences();
  }

  void removeReceiveSequence(int index) {
    receiveSequences.removeAt(index);
    saveSequences();
  }

  void toggleTerminal() {
    showTerminal.value = !showTerminal.value;
  }

  final List<int> _rxBuffer = [];

  void _handleDataReceived(Uint8List data) {
    _logService.logFrame("RX", data);
    _rxBuffer.addAll(data);
    
    while (_rxBuffer.length >= 6) {
      if (_rxBuffer[0] != 0xAA) {
        _rxBuffer.removeAt(0);
        continue;
      }
      
      final length = _rxBuffer[3];
      final totalFrameSize = 4 + length + 2;
      if (_rxBuffer.length < totalFrameSize) break;
      
      final frameData = Uint8List.fromList(_rxBuffer.sublist(0, totalFrameSize));
      try {
        final frame = BmsFrame.parse(frameData);
        if (frame != null && frame.command == 0x03) {
          bmsData.value = BmsData.fromPayload(frame.payload);
        }
      } catch (e) {
        _logService.error("Parse error: $e");
      }
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

  void selectSequence(int index) {
    selectedSendIndex.value = index;
    final sequence = sendSequences[index].sequence;
    commandInputController.text = sequence;
    onInputChange(sequence);
  }

  Future<void> sendSequence(SendSequence seq) async {
    await sendRaw(seq.bytes, seq.name);
  }

  void _updateInputFromBytes() {
    final bytes = currentBytes.value;
    String newText = "";
    if (bytes.isNotEmpty) {
      switch (selectedFormat.value) {
        case "ASCII":
          newText = String.fromCharCodes(bytes.map((b) => (b >= 32 && b <= 126) ? b : 46));
          break;
        case "Decimal":
          newText = bytes.join(' ');
          break;
        case "Binary":
          newText = bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');
          break;
        case "HEX":
        default:
          newText = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          break;
      }
    }
    customInput.value = newText;
    commandInputController.text = newText;
  }

  void updateFormat(String newFormat) {
    selectedFormat.value = newFormat;
    _updateInputFromBytes();
  }

  void onInputChange(String value) {
    customInput.value = value;
    try {
      currentBytes.value = _parseInput(value, selectedFormat.value);
    } catch (_) {}
  }

  Uint8List sendRawParseHex(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleanHex.isEmpty || cleanHex.length % 2 != 0) return Uint8List(0);
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
        } catch (e) { throw Exception("Invalid decimal format"); }
      case "Binary":
        try {
          return Uint8List.fromList(
            input.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).map((e) => int.parse(e.trim(), radix: 2)).toList(),
          );
        } catch (e) { throw Exception("Invalid binary format"); }
      case "HEX":
      default:
        try { return sendRawParseHex(input); } catch (e) { throw Exception("Invalid hex format"); }
    }
  }

  Future<void> sendCustom() async {
    try {
      if (currentBytes.value.isNotEmpty) {
        // If we have a selected sequence, update it before sending
        if (selectedSendIndex.value != -1) {
          final index = selectedSendIndex.value;
          final currentSeq = sendSequences[index];
          // Only update if the value actually changed
          if (currentSeq.sequence != customInput.value) {
            updateSendSequence(index, currentSeq.name, customInput.value);
          }
        }
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_serialService.isConnected) {
        sendCommand(0x03, Uint8List(0));
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
    commandInputController.dispose();
    super.onClose();
  }
}
