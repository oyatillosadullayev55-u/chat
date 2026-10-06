import 'package:flutter/material.dart';

import 'models/models.dart';
import 'screens/home_page.dart';
import 'screens/name_page.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';

void main() => runApp(const BluetoothChatApp());

class BluetoothChatApp extends StatefulWidget {
  const BluetoothChatApp({super.key});

  @override
  State<BluetoothChatApp> createState() => _BluetoothChatAppState();
}

class _BluetoothChatAppState extends State<BluetoothChatApp> {
  final _service = ChatService();

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    _service.load(); // saqlangan chatlarni yuklaydi
  }

  @override
  void dispose() {
    _service.stopAll();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          if (!_service.loaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: kPurple)),
            );
          }
          // Ism kiritilmaguncha ilovaga kirib bo'lmaydi
          if (!_service.hasName) return NamePage(service: _service);
          return HomePage(service: _service);
        },
      ),
    );
  }
}