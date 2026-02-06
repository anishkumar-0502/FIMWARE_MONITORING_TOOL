import 'dart:typed_data';

abstract class CrcStrategy {
  int calculate(Uint8List data);
}

class Crc16Modbus extends CrcStrategy {
  @override
  int calculate(Uint8List data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x0001) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc;
  }
}
