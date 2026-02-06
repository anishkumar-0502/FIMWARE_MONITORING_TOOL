import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/connection_controller.dart';
import '../../../data/services/serial_service.dart';

class ConnectionView extends GetView<ConnectionController> {
  const ConnectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          border: Border.all(color: Colors.grey),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Project Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 8),
            DefaultTabController(
              length: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    tabs: [
                      Tab(text: "Communication"),
                      Tab(text: "Flow Control"),
                      Tab(text: "Comm. Filter"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 350,
                    child: TabBarView(
                      children: [
                        _buildCommunicationTab(),
                        const Center(child: Text("Flow Control Settings")),
                        const Center(child: Text("Filter Settings")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Obx(() {
                  final serialService = Get.find<SerialService>();
                  final isConnected = serialService.isConnected;
                  return ElevatedButton(
                    onPressed: () async {
                      await controller.toggleConnection();
                      if (serialService.isConnected) {
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? Colors.red[700] : Colors.blue[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 40),
                    ),
                    child: Text(isConnected ? "DISCONNECT" : "CONNECT"),
                  );
                }),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(100, 40)),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {}, 
                  style: OutlinedButton.styleFrom(minimumSize: const Size(100, 40)),
                  child: const Text("Help"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCommunicationTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Communication Mode:"),
        Row(
          children: [
            Radio(value: 0, groupValue: 0, onChanged: (v) {}),
            const Text("Send / Receive"),
            const SizedBox(width: 20),
            Radio(value: 1, groupValue: 0, onChanged: (v) {}),
            const Text("Monitoring"),
          ],
        ),
        const SizedBox(height: 16),
        const Text("Send/Receive on Comm. Channel"),
        Obx(() => DropdownButtonFormField<String>(
          value: controller.availablePorts.contains(controller.selectedPort.value) ? controller.selectedPort.value : null,
          decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
          items: controller.availablePorts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (val) => controller.selectedPort.value = val ?? "",
        )),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSettingDropdown<int>(
                label: "Baud Rate",
                value: controller.selectedBaudRate,
                options: controller.baudRates,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingDropdown<int>(
                label: "Data Bits",
                value: controller.selectedDataBits,
                options: controller.dataBitsOptions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSettingDropdown<double>(
                label: "Stop Bits",
                value: controller.selectedStopBits,
                options: controller.stopBitsOptions,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Parity"),
                  Obx(() => DropdownButtonFormField<int>(
                    value: controller.selectedParity.value,
                    decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                    items: controller.parityOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (val) => controller.selectedParity.value = val ?? 0,
                  )),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingDropdown<T>({required String label, required Rx<T> value, required List<T> options}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Obx(() => DropdownButtonFormField<T>(
          value: value.value,
          decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toString()))).toList(),
          onChanged: (val) { if (val != null) value.value = val; },
        )),
      ],
    );
  }
}
