import 'package:flutter/material.dart';

import 'models/models.dart';
import 'screens/home_page.dart';
import 'services/chat_service.dart';

void main() => runApp(const BluetoothChatApp());

class BluetoothChatApp extends StatefulWidget {
  const BluetoothChatApp({super.key});

  @override
  State<BluetoothChatApp> createState() => _BluetoothChatAppState();
}

class _BluetoothChatAppState extends State<BluetoothChatApp> {
  final _service = ChatService();

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
      home: HomePage(service: _service),
    );
  }
}