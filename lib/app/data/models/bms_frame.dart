import 'dart:typed_data';
import '../../core/utils/crc16.dart';

class BmsFrame {
  final int header;
  final int deviceId;
  final int command;
  final Uint8List payload;
  final int crc;

  BmsFrame({
    required this.header,
    required this.deviceId,
    required this.command,
    required this.payload,
    required this.crc,
  });

  static Uint8List build({
    required int header,
    required int deviceId,
    required int command,
    required Uint8List payload,
    CrcStrategy? crcStrategy,
  }) {
    final strategy = crcStrategy ?? Crc16Modbus();
    
    // Header (1) + ID (1) + CMD (1) + Len (1) + Payload + CRC (2)
    final frameLength = 4 + payload.length;
    final data = Uint8List(frameLength);
    data[0] = header;
    data[1] = deviceId;
    data[2] = command;
    data[3] = payload.length;
    data.setRange(4, 4 + payload.length, payload);

    final calculatedCrc = strategy.calculate(data);
    
    final finalFrame = Uint8List(frameLength + 2);
    finalFrame.setRange(0, frameLength, data);
    finalFrame[frameLength] = calculatedCrc & 0xFF; // Low byte
    finalFrame[frameLength + 1] = (calculatedCrc >> 8) & 0xFF; // High byte
    
    return finalFrame;
  }

  static BmsFrame? parse(Uint8List data, {CrcStrategy? crcStrategy}) {
    if (data.length < 6) return null; // Min: Header(1), ID(1), CMD(1), Len(1), CRC(2)
    
    final strategy = crcStrategy ?? Crc16Modbus();
    final header = data[0];
    final deviceId = data[1];
    final command = data[2];
    final length = data[3];
    
    if (data.length < 4 + length + 2) return null;
    
    final payload = data.sublist(4, 4 + length);
    final receivedCrc = data[4 + length] | (data[4 + length + 1] << 8);
    
    final dataForCrc = data.sublist(0, 4 + length);
    final calculatedCrc = strategy.calculate(dataForCrc);
    
    if (receivedCrc != calculatedCrc) {
      throw Exception("CRC mismatch: received $receivedCrc, calculated $calculatedCrc");
    }
    
    return BmsFrame(
      header: header,
      deviceId: deviceId,
      command: command,
      payload: payload,
      crc: receivedCrc,
    );
  }
}
