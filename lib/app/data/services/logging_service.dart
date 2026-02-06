import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class LogEntry {
  final DateTime timestamp;
  final String direction; // "TX" or "RX"
  final Uint8List rawData;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.direction,
    required this.rawData,
    required this.message,
  });

  String get hexData => rawData.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  
  String get asciiData {
    StringBuffer buffer = StringBuffer();
    for (var b in rawData) {
      if (b == 13) {
        buffer.write("<CR>");
      } else if (b == 10) {
        buffer.write("<LF>\n");
      } else if (b >= 32 && b <= 126) {
        buffer.write(String.fromCharCode(b));
      } else {
        buffer.write(".");
      }
    }
    return buffer.toString();
  }

  String get decimalData => rawData.join(' ');
  
  String get binaryData => rawData.map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');

  @override
  String toString() => "[${DateFormat('HH:mm:ss.SSS').format(timestamp)}] $direction: $hexData ($message)";
}

class LoggingService extends GetxService {
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final RxList<LogEntry> logs = <LogEntry>[].obs;
  
  void logFrame(String direction, Uint8List data, {String message = ""}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      direction: direction,
      rawData: Uint8List.fromList(data),
      message: message,
    );
    
    Future.microtask(() {
      if (logs.length > 5000) logs.removeLast();
      logs.insert(0, entry);
      _logger.i("${entry.direction}: ${entry.hexData} ${entry.message}");
    });
  }

  void info(String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      direction: "INFO",
      rawData: Uint8List(0),
      message: message,
    );
    Future.microtask(() {
      _logger.i(message);
      logs.insert(0, entry);
    });
  }

  void error(String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      direction: "ERROR",
      rawData: Uint8List(0),
      message: message,
    );
    Future.microtask(() {
      _logger.e(message);
      logs.insert(0, entry);
    });
  }

  void clear() {
    logs.clear();
    _logger.i("Logs cleared");
  }

  Future<void> exportLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/bms_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
      final content = logs.map((e) => e.toString()).join('\n');
      await file.writeAsString(content);
      info("Logs exported to ${file.path}");
    } catch (e) {
      error("Failed to export logs: $e");
    }
  }
}
