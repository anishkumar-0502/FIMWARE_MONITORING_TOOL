import 'dart:async';
import 'package:get/get.dart';
import '../../../data/services/serial_service.dart';
import '../../../data/services/logging_service.dart';

class ConnectionController extends GetxController {
  final SerialService _serialService = Get.find<SerialService>();
  final LoggingService _logService = Get.find<LoggingService>();

  final RxList<String> availablePorts = <String>[].obs;
  final RxString selectedPort = "".obs;
  final RxInt selectedBaudRate = 115200.obs;
  final RxInt selectedDataBits = 8.obs;
  final RxDouble selectedStopBits = 1.0.obs;
  final RxInt selectedParity = 0.obs; // 0: None, 1: Odd, 2: Even
  final RxBool isConnecting = false.obs;

  final List<int> baudRates = [2400, 4800, 9600, 19200, 38400, 57600, 115200];
  final List<int> dataBitsOptions = [5, 6, 7, 8];
  final List<double> stopBitsOptions = [1, 1.5, 2];
  final Map<int, String> parityOptions = {0: "None", 1: "Odd", 2: "Even"};

  Timer? _portRefreshTimer;

  @override
  void onInit() {
    super.onInit();
    refreshPorts();
    // Lively port detection: Refresh every 2 seconds
    _portRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => refreshPorts());
  }

  @override
  void onClose() {
    _portRefreshTimer?.cancel();
    super.onClose();
  }

  Future<void> refreshPorts() async {
    try {
      final ports = await _serialService.getAvailablePorts();
      // Remove duplicates, filter empty, and sort
      final distinctPorts = ports
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList()
          ..sort();
      
      availablePorts.assignAll(distinctPorts);
      
      if (distinctPorts.isEmpty) {
        selectedPort.value = "";
      } else if (selectedPort.isEmpty || !distinctPorts.contains(selectedPort.value)) {
        selectedPort.value = distinctPorts.first;
      }
    } catch (e) {
      _logService.error("Refresh Ports Error: $e");
    }
  }

  Future<void> toggleConnection() async {
    if (_serialService.isConnected) {
      await _serialService.disconnect();
      _logService.info("Disconnected from ${selectedPort.value}");
    } else {
      if (selectedPort.isEmpty) {
        _logService.error("No port selected");
        return;
      }

      isConnecting.value = true;
      _logService.clear(); // Reset logs for new session
      final success = await _serialService.connect(
        portName: selectedPort.value,
        baudRate: selectedBaudRate.value,
        dataBits: selectedDataBits.value,
        stopBits: selectedStopBits.value == 1.5 ? 1 : selectedStopBits.value.toInt(), // Mapping simplified for now
        parity: selectedParity.value,
      );
      isConnecting.value = false;

      if (success) {
        _logService.info("Connected to ${selectedPort.value}");
      } else {
        _logService.error("Failed to connect to ${selectedPort.value}");
      }
    }
  }
}
