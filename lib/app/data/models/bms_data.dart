class BmsData {
  final double totalVoltage;
  final double current;
  final double remainingCapacity;
  final double designCapacity;
  final int cycleCount;
  final List<double> cellVoltages;
  final List<double> temperatures;
  final int protectionStatus;

  BmsData({
    required this.totalVoltage,
    required this.current,
    required this.remainingCapacity,
    required this.designCapacity,
    required this.cycleCount,
    required this.cellVoltages,
    required this.temperatures,
    required this.protectionStatus,
  });

  factory BmsData.empty() {
    return BmsData(
      totalVoltage: 0.0,
      current: 0.0,
      remainingCapacity: 0.0,
      designCapacity: 0.0,
      cycleCount: 0,
      cellVoltages: [],
      temperatures: [],
      protectionStatus: 0,
    );
  }

  // Example parser for a specific payload format
  factory BmsData.fromPayload(List<int> payload) {
    if (payload.length < 11) return BmsData.empty();
    
    // Helper to read 16-bit signed integer
    int readInt16(int high, int low) {
      int val = (high << 8) | low;
      return val > 32767 ? val - 65536 : val;
    }

    return BmsData(
      totalVoltage: ((payload[0] << 8) | payload[1]) / 100.0,
      current: readInt16(payload[2], payload[3]) / 100.0,
      remainingCapacity: ((payload[4] << 8) | payload[5]) / 100.0,
      designCapacity: ((payload[6] << 8) | payload[7]) / 100.0,
      cycleCount: (payload[8] << 8) | payload[9],
      cellVoltages: [],
      temperatures: [],
      protectionStatus: payload[10],
    );
  }
}
