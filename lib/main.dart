import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/data/services/serial_service.dart';
import 'app/data/services/desktop_serial_service.dart';
import 'app/data/services/android_serial_service.dart';
import 'app/data/services/logging_service.dart';
import 'app/modules/connection/controllers/connection_controller.dart';
import 'app/modules/dashboard/controllers/bms_controller.dart';
import 'app/modules/logs/controllers/logs_controller.dart';
import 'app/modules/connection/views/connection_view.dart';
import 'app/modules/dashboard/views/dashboard_view.dart';
import 'app/modules/logs/views/logs_view.dart';
import 'app/modules/configuration/views/configuration_view.dart';
import 'app/modules/commands/views/commands_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initServices();
  runApp(const MyApp());
}

void initServices() {
  Get.put(LoggingService());
  
  if (Platform.isAndroid) {
    Get.put<SerialService>(AndroidSerialService());
  } else {
    Get.put<SerialService>(DesktopSerialService());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'OutLight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: false, // Using classic material for Docklight feel
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
      ),
      initialRoute: '/',
      getPages: [
        GetPage(
          name: '/',
          page: () => const DashboardView(),
          binding: BindingsBuilder(() {
            Get.put(ConnectionController());
            Get.put(BmsController());
            Get.put(LogsController());
          }),
        ),
        GetPage(
          name: '/logs',
          page: () => const LogsView(),
        ),
      ],
    );
  }
}
