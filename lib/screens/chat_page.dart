import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

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
    s.send(widget.peerId, text);
  }

  // ---------- Rasm / fayl tanlash ----------
  void _attach() {
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Rasm'),
              onTap: () {
                Navigator.pop(sheet);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Fayl'),
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
      maxWidth: 1280, // rasm kichraytiriladi, tezroq yuboriladi
      imageQuality: 70,
    );
    if (x != null) s.sendFile(widget.peerId, x.path, image: true);
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles();
    final path = r?.files.single.path;
    if (path != null) s.sendFile(widget.peerId, path, image: false);
  }

  void _showImage(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(child: Image.file(File(path))),
            ),
            Positioned(
              top: 32,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI ----------
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
            if (m.progress != null) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: m.progress,
                color: m.mine ? kPurple : Colors.white,
                backgroundColor: Colors.black12,
              ),
            ],
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
    if (path == null) {
      return SizedBox(
        width: maxW * 0.6,
        height: 120,
        child: Center(child: CircularProgressIndicator(color: fg)),
      );
    }
    return GestureDetector(
      onTap: () => _showImage(path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          width: maxW,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
            width: maxW * 0.6,
            height: 80,
            child: Center(child: Icon(Icons.broken_image, color: fg)),
          ),
        ),
      ),
    );
  }

  Widget _fileContent(Message m, Color fg) {
    return InkWell(
      onTap: m.path == null ? null : () => OpenFilex.open(m.path!),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, color: fg, size: 30),
          const SizedBox(width: 10),
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
                  style: TextStyle(color: fg.withOpacity(0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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
              padding: const EdgeInsets.only(left: 4, right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: kPurple),
                    onPressed: online ? _attach : null,
                  ),
                  Expanded(
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
                ],
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