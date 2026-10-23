import 'package:flutter/material.dart';

import 'models/models.dart';
import 'screens/home_page.dart';
import 'screens/name_page.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChatApp());
}

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  final _service = ChatService();

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    _service.load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kPurple,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
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
