import 'package:flutter/material.dart';

const kPurple = Color(0xFF5B4BDB);
const kPurpleLight = Color(0xFF7A6CF0);

enum MsgType { text, image, file }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final bool isOnline;
  final DateTime? lastSeen;

  AppUser({
    required this.uid,
    required this.name,
    this.email = '',
    this.isOnline = true,
    this.lastSeen,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'searchName': name.toLowerCase(),
        'email': email,
        'isOnline': isOnline,
        'lastSeen': lastSeen?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
      };

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      uid: id,
      name: map['name'] ?? 'Foydalanuvchi',
      email: map['email'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int)
          : null,
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String text; // matn yoki fayl nomi
  final MsgType type;
  final int size;
  final String? path; // saqlangan fayl yo'li/data
  final String? url;
  final DateTime time;
  final bool mine;
  double? progress;

  Message({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.mine,
    this.type = MsgType.text,
    this.size = 0,
    this.path,
    this.url,
    this.progress,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  String get preview => type == MsgType.image
      ? '📷 Rasm'
      : type == MsgType.file
          ? '📎 $text'
          : text;

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'type': type.index,
        'size': size,
        'path': path,
        'url': url,
        'timestamp': time.millisecondsSinceEpoch,
      };

  factory Message.fromMap(
      Map<String, dynamic> map, String docId, String currentUid) {
    final sId = map['senderId'] ?? '';
    return Message(
      id: docId,
      senderId: sId,
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      mine: sId == currentUid,
      type: MsgType.values[(map['type'] ?? 0) as int],
      size: (map['size'] ?? 0) as int,
      path: map['path'] as String?,
      url: map['url'] as String?,
      time: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class ChatConversation {
  final String chatId;
  final String peerId;
  final String peerName;
  final String lastMessage;
  final DateTime lastTime;
  final int unread;

  ChatConversation({
    required this.chatId,
    required this.peerId,
    required this.peerName,
    required this.lastMessage,
    required this.lastTime,
    this.unread = 0,
  });
}

String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}
