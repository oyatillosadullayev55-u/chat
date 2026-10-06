import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/chat_service.dart';

/// Birinchi ishga tushirishda ism so'raydi. Ism kiritilmaguncha davom etib bo'lmaydi.
class NamePage extends StatefulWidget {
  final ChatService service;

  const NamePage({super.key, required this.service});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final _ctrl = TextEditingController();

  bool get _valid => _ctrl.text.trim().length >= 2;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_valid) widget.service.setName(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: kPurple, shape: BoxShape.circle),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 24),
                const Text('Xush kelibsiz!',
                    style:
                    TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'Boshqa telefonlarda sizni shu ism bilan ko\'rishadi. '
                      'Ismingizni kiriting.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Ismingizni kiriting',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF1F1F4),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kPurple),
                    onPressed: _valid ? _submit : null,
                    child: const Text('Davom etish',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}