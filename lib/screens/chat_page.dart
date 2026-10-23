import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../models/models.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final ChatService service;
  final String peerUid;
  final String peerName;

  const ChatPage({
    super.key,
    required this.service,
    required this.peerUid,
    required this.peerName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  ChatService get s => widget.service;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text;
    _ctrl.clear();
    s.send(widget.peerUid, text);
  }

  void _attach() {
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined, color: kPurple),
              title: const Text('Rasm yuborish'),
              onTap: () {
                Navigator.pop(sheet);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined, color: kPurple),
              title: const Text('Fayl yuborish'),
              onTap: () {
                Navigator.pop(sheet);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 65,
    );
    if (x != null) s.sendFile(widget.peerUid, x.path, image: true);
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles();
    final path = r?.files.single.path;
    if (path != null) s.sendFile(widget.peerUid, path, image: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPurple,
      body: SafeArea(
        child: Column(
          children: [
            _header(widget.peerName),
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: s.getMessagesStream(widget.peerUid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final msgs = snapshot.data ?? [];
                  if (msgs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Hozircha xabarlar yo\'q.\nXabar yozib chatni boshlang!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _bubble(msgs[i]),
                  );
                },
              ),
            ),
            _input(),
          ],
        ),
      ),
    );
  }

  Widget _header(String name) {
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
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                  SizedBox(width: 4),
                  Text('Online Chat',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
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
    final fg = m.mine ? const Color(0xFF3B3470) : Colors.white;

    Widget content;
    switch (m.type) {
      case MsgType.image:
        content = _imageContent(m, maxW, fg);
        break;
      case MsgType.file:
        content = _fileContent(m, fg);
        break;
      case MsgType.text:
        content = Text(m.text, style: TextStyle(color: fg, fontSize: 15));
        break;
    }

    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: m.mine ? Colors.white : kPurpleLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
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

  Widget _imageContent(Message m, double maxW, Color fg) {
    final path = m.path;
    if (path != null && path.startsWith('data:image')) {
      try {
        final base64Data = path.split(',').last;
        final bytes = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: maxW,
            height: 200,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    if (path != null && !kIsWeb && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          width: maxW,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image, color: fg),
        const SizedBox(width: 8),
        Text('📷 Rasm (${fmtSize(m.size)})', style: TextStyle(color: fg)),
      ],
    );
  }

  Widget _fileContent(Message m, Color fg) {
    return InkWell(
      onTap: () {
        if (m.path != null && !kIsWeb && File(m.path!).existsSync()) {
          OpenFilex.open(m.path!);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, color: fg, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  fmtSize(m.size),
                  style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _input() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 4, right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: kPurple),
                    onPressed: _attach,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Xabar yozing...',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkResponse(
            onTap: _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: kPurple),
            ),
          ),
        ],
      ),
    );
  }
}
