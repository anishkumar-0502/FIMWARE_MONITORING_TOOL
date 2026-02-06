import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../dashboard/controllers/bms_controller.dart';
import '../../../data/models/predefined_command.dart';
import 'dart:typed_data';

class ConfigurationView extends GetView<BmsController> {
  const ConfigurationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BMS Configuration")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Set Thresholds", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildConfigItem("Overvoltage Threshold (V)", "4.20"),
          _buildConfigItem("Undervoltage Threshold (V)", "2.80"),
          _buildConfigItem("Overcurrent Threshold (A)", "50.0"),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              controller.sendCommand(0x04, Uint8List.fromList([0x01, 0x02, 0x03]));
            },
            child: const Text("Write to BMS"),
          ),
          const Divider(height: 48),
          const Text("Serial Command Tester", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Obx(() => DropdownButtonFormField<String>(
                  value: controller.selectedFormat.value,
                  decoration: const InputDecoration(labelText: "Format"),
                  items: controller.formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (val) => controller.selectedFormat.value = val ?? "Hex",
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: "Custom Command",
                    hintText: "e.g. 01 01 or 1, 1",
                  ),
                  onChanged: (val) => controller.customInput.value = val,
                ),
              ),
              IconButton(
                onPressed: controller.sendCustom,
                icon: const Icon(Icons.send, color: Colors.blue),
                tooltip: "Send Custom",
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Predefined Commands", style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.sendSequences.map((seq) => ActionChip(
              label: Text(seq.name),
              onPressed: () => controller.sendSequence(seq),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String label, String initialValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(text: initialValue),
      ),
    );
  }
}
