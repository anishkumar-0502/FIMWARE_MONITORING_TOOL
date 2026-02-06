import 'package:get/get.dart';
import '../../../data/services/logging_service.dart';

class LogsController extends GetxController {
  final LoggingService _logService = Get.find<LoggingService>();
  
  RxList<LogEntry> get logs => _logService.logs;

  void clearLogs() {
    logs.clear();
  }

  void exportLogs() {
    _logService.exportLogs();
  }
}
