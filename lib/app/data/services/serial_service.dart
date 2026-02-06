import 'dart:async';
import 'dart:typed_data';
import 'package:get/get.dart';

abstract class SerialService extends GetxService {
  final _isConnected = false.obs;
  bool get isConnected => _isConnected.value;
  set isConnected(bool value) => _isConnected.value = value;

  final StreamController<Uint8List> _receivedDataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get receivedDataStream => _receivedDataController.stream;

  void onDataReceived(Uint8List data) {
    if (!_receivedDataController.isClosed) {
      _receivedDataController.add(data);
    }
  }

  Future<List<String>> getAvailablePorts();
  
  Future<bool> connect({
    required String portName,
    required int baudRate,
    int dataBits = 8,
    int stopBits = 1,
    int parity = 0,
  });

  Future<void> disconnect();

  Future<void> write(Uint8List data);
  
  @override
  void onClose() {
    _receivedDataController.close();
    super.onClose();
  }
}
