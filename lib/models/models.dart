import 'package:flutter/material.dart';

const kPurple = Color(0xFF5B4BDB);
const kPurpleLight = Color(0xFF7A6CF0);

enum MsgType { text, image, file }

class Message {
  final String text; // matn yoki fayl nomi
  final bool mine;
  final DateTime time;
  final MsgType type;
  final int size;
  String? path; // saqlangan fayl yo'li
  double? progress; // yuborilmoqda / qabul qilinmoqda (0..1), tugagach null

  Message(
      this.text, {
        required this.mine,
        this.type = MsgType.text,
        this.size = 0,
        this.path,
        this.progress,
        DateTime? time,
      }) : time = time ?? DateTime.now();

  String get preview => type == MsgType.image
      ? '📷 Rasm'
      : type == MsgType.file
      ? '📎 $text'
      : text;

  Map<String, dynamic> toJson() => {
    't': text,
    'm': mine,
    'ts': time.millisecondsSinceEpoch,
    'k': type.index,
    's': size,
    'p': path,
  };

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    j['t'] as String,
    mine: j['m'] as bool,
    time: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
    type: MsgType.values[j['k'] as int],
    size: j['s'] as int,
    path: j['p'] as String?,
  );
}

class Peer {
  final String id;
  String name;
  bool connected = false;
  bool connecting = false;

  Peer(this.id, this.name);
}

String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}