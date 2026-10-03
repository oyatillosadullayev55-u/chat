import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/chat_service.dart';
import 'chat_page.dart';

class HomePage extends StatefulWidget {
  final ChatService service;

  const HomePage({super.key, required this.service});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  ChatService get s => widget.service;

  @override
  void initState() {
    super.initState();
    s.addListener(_showError);
  }

  @override
  void dispose() {
    s.removeListener(_showError);
    super.dispose();
  }

  void _showError() {
    final e = s.error;
    if (e == null || !mounted) return;
    s.error = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: s.myName);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ismingiz'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (name != null) s.setName(name);
  }

  Future<void> _onTap(Peer p) async {
    if (!p.connected) {
      s.connect(p.id);
      return;
    }
    s.openChat(p.id);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(service: s, peerId: p.id)),
    );
    s.closeChat();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = s.peers.values
            .where((p) => _tab == 0 || p.connected)
            .toList()
          ..sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0));

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: kPurple,
            shape: const CircleBorder(),
            onPressed: s.scanning ? s.stopScan : s.startScan,
            child: Icon(
              s.scanning ? Icons.bluetooth_searching : Icons.bluetooth,
              color: Colors.white,
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Salom,',
                              style: TextStyle(color: Colors.grey)),
                          Text(s.myName,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const Spacer(),
                      _circleButton(Icons.more_vert, _editName),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _tabs(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.scanning
                              ? 'Qurilmalar qidirilmoqda...\nIkkala telefonda ham ilova ochiq bo\'lishi kerak.'
                              : 'Qidirishni boshlash uchun pastdagi Bluetooth tugmasini bosing.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                        : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _tile(list[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) => InkResponse(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87),
      ),
      child: Icon(icon, size: 20),
    ),
  );

  Widget _tabs() {
    const labels = ['Atrofda', 'Ulangan'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == i ? kPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: _tab == i ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(Peer p) {
    final msgs = s.messagesOf(p.id);
    final last = msgs.isEmpty ? null : msgs.last;
    final unread = s.unread[p.id] ?? 0;
    final sub = last != null
        ? last.text
        : p.connected
        ? 'Ulangan'
        : p.connecting
        ? 'Ulanmoqda...'
        : 'Ulanish uchun bosing';
    final color =
    Colors.primaries[p.name.hashCode.abs() % Colors.primaries.length];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      onTap: () => _onTap(p),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: color.shade300,
        child: Text(
          p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      title: Text(p.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        sub,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: p.connecting ? kPurple : Colors.grey,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Text(hm(last.time),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(6),
              decoration:
              const BoxDecoration(color: kPurple, shape: BoxShape.circle),
              child: Text('$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}