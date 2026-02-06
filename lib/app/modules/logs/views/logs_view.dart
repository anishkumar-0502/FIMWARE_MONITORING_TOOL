import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/logs_controller.dart';

class LogsView extends GetView<LogsController> {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Communication Logs"),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: controller.clearLogs),
          IconButton(icon: const Icon(Icons.download), onPressed: controller.exportLogs),
        ],
      ),
      body: Obx(() => ListView.separated(
        itemCount: controller.logs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = controller.logs[index];
          return ListTile(
            dense: true,
            title: Text(
              "${log.direction}: ${log.hexData}",
              style: TextStyle(
                fontFamily: 'monospace',
                color: log.direction == "TX" ? Colors.blue : (log.direction == "RX" ? Colors.red : Colors.black),
              ),
            ),
            subtitle: Text(log.message.isEmpty ? log.timestamp.toString() : "${log.timestamp}: ${log.message}"),
          );
        },
      )),
    );
  }
}
