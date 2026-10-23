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
  int _tab = 0; // 0: Chatlar, 1: Barcha foydalanuvchilar (Qidiruv)
  final _searchCtrl = TextEditingController();
  ChatService get s => widget.service;

  @override
  void initState() {
    super.initState();
    s.addListener(_showError);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
        title: const Text('Ismingizni o\'zgartirish'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Yangi ism kiriting'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) s.setName(name);
  }

  void _openChatWithUser(String peerUid, String peerName) async {
    s.openChat(peerUid);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          service: s,
          peerUid: peerUid,
          peerName: peerName,
        ),
      ),
    );
    s.closeChat();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final query = _searchCtrl.text.trim();
        final searchResults = s.searchRegisteredUsers(query);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // App Header
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Salom 👋',
                              style: TextStyle(color: Colors.grey, fontSize: 14)),
                          Text(
                            s.myName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _circleButton(Icons.edit_outlined, _editName),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Qidiruv maydoni
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Foydalanuvchilarni qidirish...',
                      prefixIcon: const Icon(Icons.search, color: kPurple),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F1F4),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _tabs(),
                  const SizedBox(height: 12),

                  // Tab tarkibi
                  Expanded(
                    child: _tab == 0
                        ? _buildConversationsList()
                        : _buildUsersList(searchResults),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationsList() {
    return StreamBuilder<List<ChatConversation>>(
      stream: s.getConversationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPurple),
          );
        }

        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'Hozircha suhbatlar yo\'q',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '"Foydalanuvchilar" bo\'limidan ro\'yhatdan o\'tgan odamlarni topib chat boshlang.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPurple,
                      foregroundColor: Colors.white,
                      shape: StadiumBorder(),
                    ),
                    onPressed: () => setState(() => _tab = 1),
                    icon: const Icon(Icons.person_search),
                    label: const Text('Odamlarni Qidirish'),
                  )
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (_, i) {
            final chat = chats[i];
            final color = Colors.primaries[
                chat.peerName.hashCode.abs() % Colors.primaries.length];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              onTap: () => _openChatWithUser(chat.peerId, chat.peerName),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: color.shade300,
                child: Text(
                  chat.peerName.isEmpty ? '?' : chat.peerName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              title: Text(
                chat.peerName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              trailing: Text(
                hm(chat.lastTime),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersList(List<AppUser> users) {
    if (users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Foydalanuvchilar topilmadi.\nUshbu ilovani yuklab ro\'yhatdan o\'tgan foydalanuvchilar shu yerda ko\'rinadi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final color =
            Colors.primaries[u.name.hashCode.abs() % Colors.primaries.length];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          onTap: () => _openChatWithUser(u.uid, u.name),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.shade300,
                child: Text(
                  u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              if (u.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            u.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            u.isOnline ? 'Online' : 'Ro\'yxatdan o\'tgan',
            style: TextStyle(
              fontSize: 12,
              color: u.isOnline ? Colors.green : Colors.grey,
            ),
          ),
          trailing: const Icon(Icons.chat_bubble_outline, color: kPurple),
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
            border: Border.all(color: Colors.black26),
          ),
          child: Icon(icon, size: 20),
        ),
      );

  Widget _tabs() {
    const labels = ['Chatlar', 'Foydalanuvchilar'];
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
}
