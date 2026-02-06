import 'dart:typed_data';

class PredefinedCommand {
  final String name;
  final String hexData;
  final String? description;

  PredefinedCommand({
    required this.name,
    required this.hexData,
    this.description,
  });

  Uint8List get bytes {
    final cleanHex = hexData.replaceAll(' ', '');
    final bytes = Uint8List(cleanHex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
