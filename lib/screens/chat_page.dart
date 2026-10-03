import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final ChatService service;
  final String peerId;

  const ChatPage({super.key, required this.service, required this.peerId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  ChatService get s => widget.service;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text;
    _ctrl.clear();
    s.send(widget.peerId, text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final peer = s.peers[widget.peerId];
        final online = peer?.connected ?? false;
        final msgs = s.messagesOf(widget.peerId).reversed.toList();

        return Scaffold(
          backgroundColor: kPurple,
          body: SafeArea(
            child: Column(
              children: [
                _header(peer?.name ?? '?', online),
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _bubble(msgs[i]),
                  ),
                ),
                _input(online),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(String name, bool online) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          CircleAvatar(
            backgroundColor: kPurpleLight,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              Row(
                children: [
                  Icon(Icons.circle,
                      size: 8,
                      color: online ? Colors.greenAccent : Colors.white38),
                  const SizedBox(width: 4),
                  Text(online ? 'Online' : 'Oflayn',
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(Message m) {
    final maxW = MediaQuery.of(context).size.width * 0.72;
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        decoration: BoxDecoration(
          color: m.mine ? Colors.white : kPurpleLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m.text,
              style: TextStyle(
                color: m.mine ? const Color(0xFF3B3470) : Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hm(m.time),
              style: TextStyle(
                fontSize: 10,
                color: m.mine ? Colors.black38 : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(bool online) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _ctrl,
                enabled: online,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: online ? 'Xabar yozing...' : 'Ulanish uzilgan',
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkResponse(
            onTap: online ? _send : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: kPurple),
            ),
          ),
        ],
      ),
    );
  }
}