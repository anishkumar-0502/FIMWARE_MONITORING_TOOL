import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/bms_controller.dart';
import '../../../data/services/logging_service.dart';
import '../../../data/services/serial_service.dart';
import '../../connection/views/connection_view.dart';
import '../../connection/controllers/connection_controller.dart';

class DashboardView extends GetView<BmsController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final logService = Get.find<LoggingService>();
    final serialService = Get.find<SerialService>();
    final connController = Get.find<ConnectionController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
    
              const VerticalDivider(width: 1),
              _buildToolButton(Icons.settings, "Comm. Settings", () {
                Get.dialog(const ConnectionView());
              }),
              Obx(() => _buildToolButton(
                Icons.play_arrow, 
                "Start Polling", 
                serialService.isConnected ? () => controller.startPolling() : null,
                enabled: serialService.isConnected
              )),
              Obx(() => _buildToolButton(
                Icons.stop, 
                "Stop Polling", 
                serialService.isConnected ? () => controller.stopPolling() : null,
                enabled: serialService.isConnected
              )),
              _buildToolButton(Icons.terminal, "Terminal Logs", () => controller.toggleTerminal()),
              const Spacer(),
              Obx(() => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: serialService.isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(serialService.isConnected 
                      ? "Connected to ${connController.selectedPort.value}" 
                      : "Communication port closed",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Sidebar: Send Sequences
                Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E1E1),
                    border: Border(right: BorderSide(color: Colors.grey[400]!)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          onChanged: (val) => controller.searchQuery.value = val,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: "Search Sequences...",
                            prefixIcon: Icon(Icons.search, size: 16),
                            isDense: true,
                            contentPadding: EdgeInsets.all(8),
                            fillColor: Colors.white,
                            filled: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: const Text("Send Sequences", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Obx(() => ListView.builder(
                          itemCount: controller.filteredCommands.length,
                          itemBuilder: (context, index) {
                            final cmd = controller.filteredCommands[index];
                            return ListTile(
                              dense: true,
                              title: Text(cmd.name, style: const TextStyle(fontSize: 12)),
                              leading: const Icon(Icons.send_outlined, size: 16),
                              onTap: () => controller.selectPredefinedCommand(cmd),
                            );
                          },
                        )),
                      ),
                    ],
                  ),
                ),
                // Main Console
                Expanded(
                  child: Column(
                    children: [
                      // Log Format Tabs
                      Container(
                        color: Colors.white,
                        child: Row(
                          children: [
                            _buildFormatTab("ASCII"),
                            _buildFormatTab("HEX"),
                            _buildFormatTab("Decimal"),
                            _buildFormatTab("Binary"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Obx(() => ListView.builder(
                            reverse: true, // Newest at bottom
                            itemCount: logService.logs.length,
                            itemBuilder: (context, index) {
                              final log = logService.logs[index]; // logs[0] is newest
                              return _buildLogEntry(log);
                            },
                          )),
                        ),
                      ),
                      // Command Edit Bar
                      _buildEditBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Terminal Section
          Obx(() => controller.showTerminal.value 
            ? Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border(top: BorderSide(color: Colors.grey[800]!, width: 2)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.grey[900],
                      child: Row(
                        children: [
                          const Icon(Icons.terminal, color: Colors.white, size: 14),
                          const SizedBox(width: 8),
                          const Text("TERMINAL", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 14),
                            onPressed: () => controller.showTerminal.value = false,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Obx(() => ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: logService.logs.length,
                        itemBuilder: (context, index) {
                          final log = logService.logs[index];
                          final timestamp = DateFormat('HH:mm:ss.SSS').format(log.timestamp);
                          final color = log.direction == "TX" ? Colors.greenAccent : (log.direction == "RX" ? Colors.cyanAccent : (log.direction == "ERROR" ? Colors.redAccent : Colors.white70));
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                children: [
                                  TextSpan(text: "[$timestamp] ", style: const TextStyle(color: Colors.grey)),
                                  TextSpan(text: "${log.direction}: ", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                                  TextSpan(text: log.hexData, style: TextStyle(color: color)),
                                  if (log.message.isNotEmpty)
                                    TextSpan(text: " - ${log.message}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildEditBar() {
    final textController = TextEditingController();
    
    // Sync text controller with customInput
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(top: BorderSide(color: Colors.grey[400]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Obx(() => DropdownButton<String>(
              value: controller.formats.contains(controller.selectedFormat.value) ? controller.selectedFormat.value : controller.formats.first,
              isExpanded: true,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              items: controller.formats.toSet().map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) => controller.updateFormat(val ?? "HEX"),
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 35,
              child: Obx(() {
                // We use a key to force rebuild when customInput changes from external (sidebar)
                // but we also need to handle user typing.
                return TextField(
                  key: ValueKey(controller.customInput.value),
                  controller: TextEditingController(text: controller.customInput.value)
                    ..selection = TextSelection.fromPosition(TextPosition(offset: controller.customInput.value.length)),
                  onChanged: (val) => controller.onInputChange(val),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: "Enter command data...",
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final serialService = Get.find<SerialService>();
              if (serialService.isConnected) {
                controller.sendCustom();
              } else {
                Get.dialog(const ConnectionView());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 35),
            ),
            child: const Text("SEND"),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String tooltip, VoidCallback? onTap, {bool enabled = true}) {
    return IconButton(
      icon: Icon(icon, size: 20, color: enabled ? Colors.black : Colors.grey[400]),
      tooltip: enabled ? tooltip : "$tooltip (Disconnected)",
      onPressed: enabled ? onTap : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  Widget _buildFormatTab(String label) {
    return Obx(() => InkWell(
      onTap: () => controller.selectedFormat.value = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: controller.selectedFormat.value == label ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: controller.selectedFormat.value == label ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    ));
  }

  Widget _buildLogEntry(LogEntry log) {
    String displayData = "";
    switch (controller.selectedFormat.value) {
      case "ASCII": displayData = log.asciiData; break;
      case "HEX": displayData = log.hexData; break;
      case "Decimal": displayData = log.decimalData; break;
      case "Binary": displayData = log.binaryData; break;
      default: displayData = log.hexData;
    }

    final isTx = log.direction == "TX";
    final isRx = log.direction == "RX";
    final isInfo = log.direction == "INFO";
    final isError = log.direction == "ERROR";

    final color = isTx ? Colors.blue[800] : (isRx ? Colors.red[800] : (isError ? Colors.orange[900] : Colors.grey[700]));
    
    String label = "";
    if (isTx) label = "Send Commands";
    else if (isRx) label = "Received Commands";
    else if (isInfo) label = "System Info";
    else if (isError) label = "System Error";
    
    final timestamp = DateFormat('HH:mm:ss.SSS').format(log.timestamp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("[$timestamp] ", style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
              Text("$label: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              if (log.message.isNotEmpty)
                Text("(${log.message})", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SelectableText(
              displayData,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
