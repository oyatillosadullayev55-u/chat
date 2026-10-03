import 'package:flutter/material.dart';

const kPurple = Color(0xFF5B4BDB);
const kPurpleLight = Color(0xFF7A6CF0);

class Message {
  final String text;
  final bool mine;
  final DateTime time;

  Message(this.text, {required this.mine}) : time = DateTime.now();
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