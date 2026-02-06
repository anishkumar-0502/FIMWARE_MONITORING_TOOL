import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../dashboard/controllers/bms_controller.dart';
import '../../../data/services/serial_service.dart';

class CommandsView extends GetView<BmsController> {
  const CommandsView({super.key});

  Widget _buildConnectionStatus(SerialService serialService) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black26,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() => Text(
              serialService.isConnected 
                ? "Status: Connected" 
                : "Status: Disconnected - Go to Connection tab",
              style: TextStyle(color: serialService.isConnected ? Colors.green : Colors.red),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSendSection() {
    final TextEditingController textController = TextEditingController();
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  onChanged: (val) => controller.customInput.value = val,
                  decoration: const InputDecoration(
                    hintText: "Enter data to send...",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() => DropdownButton<String>(
                value: controller.selectedFormat.value,
                items: controller.formats.map((f) => 
                  DropdownMenuItem(value: f, child: Text(f))
                ).toList(),
                onChanged: (val) => controller.selectedFormat.value = val ?? "Hex",
              )),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text("SEND CUSTOM DATA"),
              onPressed: controller.sendCustom,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serialService = Get.find<SerialService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Commands"),
      ),
      body: Column(
        children: [
          _buildConnectionStatus(serialService),
          _buildCustomSendSection(),
          const Divider(thickness: 2),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Predefined Commands", style: Get.textTheme.titleMedium),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: controller.predefinedCommands.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final cmd = controller.predefinedCommands[index];
                return ListTile(
                  title: Text(cmd.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    cmd.hexData,
                    style: const TextStyle(fontFamily: 'monospace', color: Colors.blueAccent),
                  ),
                  trailing: ElevatedButton(
                    onPressed: serialService.isConnected 
                      ? () => controller.sendRaw(cmd.bytes, cmd.name)
                      : null,
                    child: const Text("SEND"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
