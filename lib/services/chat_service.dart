import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/models.dart';

class ChatService extends ChangeNotifier with WidgetsBindingObserver {
  String myName = '';
  String myUid = '';
  bool loaded = false;
  bool isFirebaseAvailable = false;
  bool get hasName => myName.trim().isNotEmpty;
  String? error;
  String? activeChatId;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache
  List<AppUser> registeredUsers = [];
  Map<String, List<Message>> localChats = {};
  Map<String, int> unread = {};

  StreamSubscription? _usersSub;

  ChatService() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateOnlineStatus(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usersSub?.cancel();
    super.dispose();
  }

  // ---------- Inizializatsiya ----------
  Future<void> load() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseAvailable = true;
    } catch (e) {
      isFirebaseAvailable = false;
    }

    final prefs = await SharedPreferences.getInstance();
    myName = prefs.getString('userName') ?? '';
    myUid = prefs.getString('userUid') ?? '';

    if (myUid.isEmpty) {
      myUid = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('userUid', myUid);
    }

    if (isFirebaseAvailable) {
      try {
        if (_auth.currentUser == null) {
          final userCredential = await _auth.signInAnonymously();
          if (userCredential.user != null) {
            myUid = userCredential.user!.uid;
            await prefs.setString('userUid', myUid);
          }
        } else {
          myUid = _auth.currentUser!.uid;
        }
      } catch (_) {}
    }

    if (hasName) {
      await _syncUserProfile();
      _listenToUsers();
    }

    loaded = true;
    notifyListeners();
  }

  // ---------- Profilni Saqlash / Ism o'zgartirish ----------
  Future<void> setName(String name) async {
    final n = name.replaceAll('\n', ' ').trim();
    if (n.isEmpty) return;

    myName = n.length > 24 ? n.substring(0, 24) : n;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', myName);

    await _syncUserProfile();
    _listenToUsers();
    notifyListeners();
  }

  Future<void> _syncUserProfile() async {
    if (!isFirebaseAvailable || myUid.isEmpty) return;
    try {
      final userRef = _firestore.collection('users').doc(myUid);
      await userRef.set({
        'uid': myUid,
        'name': myName,
        'searchName': myName.toLowerCase(),
        'isOnline': true,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _updateOnlineStatus(bool online) {
    if (!isFirebaseAvailable || myUid.isEmpty) return;
    try {
      _firestore.collection('users').doc(myUid).update({
        'isOnline': online,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ---------- Qidiruv va Ro'yhatdan o'tgan foydalanuvchilar ----------
  void _listenToUsers() {
    if (!isFirebaseAvailable) return;
    _usersSub?.cancel();
    _usersSub = _firestore
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      registeredUsers = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data(), doc.id))
          .where((u) => u.uid != myUid)
          .toList();
      notifyListeners();
    }, onError: (_) {});
  }

  List<AppUser> searchRegisteredUsers(String query) {
    if (query.trim().isEmpty) return registeredUsers;
    final q = query.toLowerCase().trim();
    return registeredUsers
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }

  // ---------- Chat va Real-time Xabarlar ----------
  String getChatId(String peerUid) {
    final ids = [myUid, peerUid]..sort();
    return ids.join('_');
  }

  Stream<List<Message>> getMessagesStream(String peerUid) {
    if (!isFirebaseAvailable) {
      return Stream.value(localChats[peerUid] ?? []);
    }
    final chatId = getChatId(peerUid);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromMap(doc.data(), doc.id, myUid))
          .toList();
    });
  }

  Future<void> send(String peerUid, String text) async {
    final t = text.replaceAll('\n', ' ').trim();
    if (t.isEmpty) return;

    final msg = Message(
      senderId: myUid,
      senderName: myName,
      text: t,
      mine: true,
      type: MsgType.text,
    );

    if (isFirebaseAvailable) {
      try {
        final chatId = getChatId(peerUid);
        final chatRef = _firestore.collection('chats').doc(chatId);
        final msgRef = chatRef.collection('messages').doc();

        await msgRef.set(msg.toMap());

        await chatRef.set({
          'chatId': chatId,
          'participants': [myUid, peerUid],
          'lastMessage': t,
          'lastTime': DateTime.now().millisecondsSinceEpoch,
          'lastSenderId': myUid,
        }, SetOptions(merge: true));
      } catch (e) {
        error = 'Xabar yuborishda xatolik: $e';
        notifyListeners();
      }
    } else {
      localChats.putIfAbsent(peerUid, () => []).add(msg);
      notifyListeners();
    }
  }

  Future<void> sendFile(String peerUid, String srcPath,
      {required bool image}) async {
    try {
      final file = File(srcPath);
      final size = await file.length();
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final name = srcPath.split(RegExp(r'[\\/]')).last;

      final msg = Message(
        senderId: myUid,
        senderName: myName,
        text: name,
        mine: true,
        type: image ? MsgType.image : MsgType.file,
        size: size,
        path: 'data:${image ? "image/jpeg" : "application/octet-stream"};base64,$base64String',
      );

      if (isFirebaseAvailable) {
        final chatId = getChatId(peerUid);
        final chatRef = _firestore.collection('chats').doc(chatId);
        final msgRef = chatRef.collection('messages').doc();

        await msgRef.set(msg.toMap());

        await chatRef.set({
          'chatId': chatId,
          'participants': [myUid, peerUid],
          'lastMessage': image ? '📷 Rasm' : '📎 $name',
          'lastTime': DateTime.now().millisecondsSinceEpoch,
          'lastSenderId': myUid,
        }, SetOptions(merge: true));
      } else {
        localChats.putIfAbsent(peerUid, () => []).add(msg);
        notifyListeners();
      }
    } catch (e) {
      error = 'Fayl yuborishda xatolik: $e';
      notifyListeners();
    }
  }

  Stream<List<ChatConversation>> getConversationsStream() {
    if (!isFirebaseAvailable) {
      return Stream.value([]);
    }
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
      final list = <ChatConversation>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final peerUid = participants.firstWhere(
          (id) => id != myUid,
          orElse: () => '',
        );

        if (peerUid.isEmpty) continue;

        // Peer ismiga moslash
        final peerUser = registeredUsers.firstWhere(
          (u) => u.uid == peerUid,
          orElse: () => AppUser(uid: peerUid, name: 'Foydalanuvchi'),
        );

        list.add(ChatConversation(
          chatId: doc.id,
          peerId: peerUid,
          peerName: peerUser.name,
          lastMessage: data['lastMessage'] ?? '',
          lastTime: DateTime.fromMillisecondsSinceEpoch(
            data['lastTime'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
        ));
      }
      list.sort((a, b) => b.lastTime.compareTo(a.lastTime));
      return list;
    });
  }

  void openChat(String peerUid) {
    activeChatId = peerUid;
    unread[peerUid] = 0;
    notifyListeners();
  }

  void closeChat() => activeChatId = null;
}
