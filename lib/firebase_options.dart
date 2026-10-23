// Default Firebase Options configuration for Android, Web and iOS
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDemoKeyForChatApp1234567890",
    appId: "1:123456789012:web:demo1234567890",
    messagingSenderId: "123456789012",
    projectId: "chat-ilova-demo",
    authDomain: "chat-ilova-demo.firebaseapp.com",
    storageBucket: "chat-ilova-demo.appspot.com",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDemoKeyForChatApp1234567890",
    appId: "1:123456789012:android:demo1234567890",
    messagingSenderId: "123456789012",
    projectId: "chat-ilova-demo",
    storageBucket: "chat-ilova-demo.appspot.com",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyDemoKeyForChatApp1234567890",
    appId: "1:123456789012:ios:demo1234567890",
    messagingSenderId: "123456789012",
    projectId: "chat-ilova-demo",
    storageBucket: "chat-ilova-demo.appspot.com",
    iosBundleId: "com.example.chatIlova",
  );
}
