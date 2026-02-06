import 'dart:typed_data';

class SendSequence {
  String name;
  String sequence;

  SendSequence({
    required this.name,
    required this.sequence,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'sequence': sequence,
  };

  factory SendSequence.fromJson(Map<String, dynamic> json) => SendSequence(
    name: json['name'],
    sequence: json['sequence'],
  );

  Uint8List get bytes {
    final cleanHex = sequence.replaceAll(' ', '');
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleanHex)) {
      final bytes = Uint8List(cleanHex.length ~/ 2);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return bytes;
    }
    return Uint8List.fromList(sequence.codeUnits);
  }
}

class ReceiveSequence {
  bool isActive;
  String name;
  String sequence;
  String answer;

  ReceiveSequence({
    this.isActive = true,
    required this.name,
    required this.sequence,
    this.answer = "",
  });

  Map<String, dynamic> toJson() => {
    'isActive': isActive,
    'name': name,
    'sequence': sequence,
    'answer': answer,
  };

  factory ReceiveSequence.fromJson(Map<String, dynamic> json) => ReceiveSequence(
    isActive: json['isActive'] ?? true,
    name: json['name'],
    sequence: json['sequence'],
    answer: json['answer'] ?? "",
  );
}

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
