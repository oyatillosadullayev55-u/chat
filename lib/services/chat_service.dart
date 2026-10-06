import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'notification_service.dart';

class _Incoming {
  final Message msg;
  final BytesBuilder bytes = BytesBuilder(copy: false);
  _Incoming(this.msg);
}

/// Faqat Bluetooth Classic (RFCOMM) orqali ishlaydi. Internet / Wi-Fi ishlatilmaydi.
class ChatService extends ChangeNotifier with WidgetsBindingObserver {
  static const _uuid = '8ce255c0-200a-11e0-ac64-0800200c9a66';
  static const _ctl = '\u0001'; // boshqaruv qatorlari belgisi
  static const _maxFile = 8 * 1024 * 1024; // 8 MB
  static const _chunk = 3072; // bir bo'lak (bayt)

  ChatService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _bt = FlutterClassicBluetooth();

  String myName = '';
  bool loaded = false;
  bool get hasName => myName.trim().isNotEmpty;
  bool scanning = false;
  String? error; // UI snackbar uchun
  String? activeChatId;
  bool _foreground = true;

  final Map<String, Peer> peers = {};
  final Map<String, List<Message>> chats = {};
  final Map<String, int> unread = {};

  dynamic _server;
  StreamSubscription? _serverSub;
  final Map<String, BtcConnection> _conns = {};
  final Map<String, StreamSubscription> _subs = {};
  final Map<String, _Incoming> _incoming = {};
  Timer? _saveTimer;

  List<Message> messagesOf(String id) => chats[id] ?? [];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---------- Xotirada saqlash ----------
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      myName = prefs.getString('userName') ?? '';
      final names = jsonDecode(prefs.getString('peers') ?? '{}') as Map;
      final raw = jsonDecode(prefs.getString('chats') ?? '{}') as Map;
      raw.forEach((id, list) {
        chats[id as String] = (list as List)
            .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        peers.putIfAbsent(id, () => Peer(id, (names[id] ?? id) as String));
      });
      final un = jsonDecode(prefs.getString('unread') ?? '{}') as Map;
      un.forEach((id, n) => unread[id as String] = n as int);
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'peers',
          jsonEncode({
            for (final id in chats.keys) id: peers[id]?.name ?? id,
          }),
        );
        await prefs.setString(
          'chats',
          jsonEncode({
            for (final e in chats.entries)
              e.key: e.value
                  .where((m) => m.progress == null)
                  .map((m) => m.toJson())
                  .toList(),
          }),
        );
        await prefs.setString('unread', jsonEncode(unread));
      } catch (_) {}
    });
  }

  Future<Directory> _filesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/files');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // ---------- Qidirish ----------
  Future<void> startScan() async {
    error = null;
    try {
      if (!await _bt.isEnabled()) await _bt.enableBluetooth();
      await _bt.requestPermissions();

      await _startServer(); // boshqa telefon ulana olishi uchun
      scanning = true;
      notifyListeners();

      for (final d in await _bt.getPairedDevices()) {
        _addDevice(d);
      }
      notifyListeners();

      if (await _bt.isLocationServiceRequired() &&
          !await _bt.isLocationServiceEnabled()) {
        error = 'Yangi qurilmalarni topish uchun Joylashuv (GPS) ni yoqing';
      } else {
        for (final d in await _bt.scan(timeout: const Duration(seconds: 8))) {
          _addDevice(d);
        }
      }
    } catch (e) {
      error = 'Bluetooth xatosi: $e';
    }
    notifyListeners();
  }

  void _addDevice(BtcDevice d) {
    final p = peers.putIfAbsent(d.address, () => Peer(d.address, d.displayName));
    if (p.name == d.address && d.displayName.isNotEmpty) p.name = d.displayName;
  }

  Future<void> _startServer() async {
    if (_server != null) return;
    _server = await _bt.startServer(
      serviceName: 'BluetoothChat',
      uuid: _uuid,
      secure: false,
    );
    _serverSub = _server.connections.listen((c) => _attach(c));
  }

  Future<void> stopScan({bool notify = true}) async {
    await _serverSub?.cancel();
    _serverSub = null;
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
    scanning = false;
    if (notify) notifyListeners();
  }

  Future<void> stopAll() async {
    await stopScan(notify: false);
    for (final c in _conns.values) {
      try {
        await c.close();
      } catch (_) {}
    }
  }

  void setName(String name) {
    final n = name.replaceAll('\n', ' ').trim();
    if (n.isEmpty) return;
    myName = n.length > 24 ? n.substring(0, 24) : n;
    SharedPreferences.getInstance()
        .then((p) => p.setString('userName', myName));
    for (final c in _conns.values) {
      _say(c, '${_ctl}name:$myName');
    }
    notifyListeners();
  }

  // ---------- Ulanish ----------
  Future<void> connect(String id) async {
    final p = peers[id];
    if (p == null || p.connected || p.connecting) return;
    p.connecting = true;
    notifyListeners();
    try {
      final c = await _bt.connect(
        address: id,
        uuid: _uuid,
        secure: false,
        timeout: const Duration(seconds: 15),
      );
      _attach(c);
    } catch (e) {
      p.connecting = false;
      error = 'Ulanib bo\'lmadi. Ikkinchi telefonda ilova ochiq va '
          'Bluetooth tugmasi bosilgan bo\'lishi kerak.';
      notifyListeners();
    }
  }

  void _attach(BtcConnection c) {
    final id = c.address;
    final p = peers.putIfAbsent(id, () => Peer(id, id));
    _conns[id] = c;
    p.connected = true;
    p.connecting = false;

    _subs[id]?.cancel();
    _subs[id] = c.input.lines().listen(
          (line) => _onLine(id, line),
      onDone: () => _onClosed(id),
      onError: (_) => _onClosed(id),
    );

    _say(c, '${_ctl}name:$myName');
    notifyListeners();
  }

  void _onClosed(String id) {
    final p = peers[id];
    if (p != null) {
      p.connected = false;
      p.connecting = false;
    }
    _conns.remove(id);
    _subs.remove(id)?.cancel();
    // yarim qolgan fayllarni olib tashlash
    final keys = _incoming.keys.where((k) => k.startsWith('$id/')).toList();
    for (final k in keys) {
      chats[id]?.remove(_incoming.remove(k)!.msg);
    }
    notifyListeners();
  }

  // ---------- Qabul qilish ----------
  Future<void> _say(BtcConnection c, String text) async {
    try {
      await c.output.writeLine(text);
    } catch (_) {}
  }

  void _onLine(String id, String line) {
    if (line.startsWith(_ctl)) {
      _control(id, line.substring(1));
      return;
    }
    if (line.trim().isEmpty) return;
    _add(id, Message(line, mine: false));
    _afterIncoming(id, line);
  }

  void _control(String id, String body) {
    final i = body.indexOf(':');
    if (i < 0) return;
    final cmd = body.substring(0, i);
    final rest = body.substring(i + 1);

    try {
      switch (cmd) {
        case 'name':
          final name = rest.trim();
          if (name.isNotEmpty) peers[id]?.name = name;
          notifyListeners();
          _save();
          break;

        case 'file': // fid:kind:size:base64(name)
          final p = rest.split(':');
          final msg = Message(
            utf8.decode(base64Decode(p[3])),
            mine: false,
            type: p[1] == 'i' ? MsgType.image : MsgType.file,
            size: int.parse(p[2]),
            progress: 0,
          );
          _incoming['$id/${p[0]}'] = _Incoming(msg);
          _add(id, msg);
          notifyListeners();
          break;

        case 'chunk': // fid:base64(data)
          final j = rest.indexOf(':');
          final inc = _incoming['$id/${rest.substring(0, j)}'];
          if (inc == null) return;
          inc.bytes.add(base64Decode(rest.substring(j + 1)));
          final total = inc.msg.size == 0 ? 1 : inc.msg.size;
          final pr = inc.bytes.length / total;
          if (pr - (inc.msg.progress ?? 0) > 0.03) {
            inc.msg.progress = pr > 1 ? 1.0 : pr;
            notifyListeners();
          }
          break;

        case 'end': // fid
          final inc = _incoming.remove('$id/${rest.trim()}');
          if (inc != null) _finishIncoming(id, inc);
          break;
      }
    } catch (_) {}
  }

  Future<void> _finishIncoming(String id, _Incoming inc) async {
    try {
      final dir = await _filesDir();
      final safe = inc.msg.text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final f = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safe');
      await f.writeAsBytes(inc.bytes.takeBytes());
      inc.msg.path = f.path;
    } catch (_) {
      error = 'Faylni saqlab bo\'lmadi';
    }
    inc.msg.progress = null;
    _afterIncoming(id, inc.msg.preview);
  }

  void _afterIncoming(String id, String preview) {
    final chatOpen = activeChatId == id && _foreground;
    if (activeChatId != id) unread[id] = (unread[id] ?? 0) + 1;
    if (!chatOpen) {
      NotificationService.show(peers[id]?.name ?? 'Yangi xabar', preview);
    }
    notifyListeners();
    _save();
  }

  // ---------- Yuborish ----------
  Future<void> send(String id, String text) async {
    final t = text.replaceAll('\n', ' ').trim();
    if (t.isEmpty) return;
    final c = _conns[id];
    if (c == null || !c.isConnected) {
      error = 'Ulanish yo\'q';
      notifyListeners();
      return;
    }
    try {
      await c.output.writeLine(t);
      _add(id, Message(t, mine: true));
    } catch (e) {
      error = 'Yuborib bo\'lmadi';
    }
    notifyListeners();
  }

  Future<void> sendFile(String id, String srcPath, {required bool image}) async {
    final c = _conns[id];
    if (c == null || !c.isConnected) {
      error = 'Ulanish yo\'q';
      notifyListeners();
      return;
    }
    Message? sending;
    try {
      final src = File(srcPath);
      final size = await src.length();
      if (size > _maxFile) {
        error = 'Fayl juda katta (8 MB gacha)';
        notifyListeners();
        return;
      }
      final name = srcPath.split(RegExp(r'[\\/]')).last;
      final dir = await _filesDir();
      final saved =
      await src.copy('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name');
      final bytes = await saved.readAsBytes();

      final m = Message(
        name,
        mine: true,
        type: image ? MsgType.image : MsgType.file,
        size: size,
        path: saved.path,
        progress: 0,
      );
      sending = m;
      _add(id, m);
      notifyListeners();

      final fid = DateTime.now().microsecondsSinceEpoch.toString();
      await c.output.writeLine(
          '${_ctl}file:$fid:${image ? 'i' : 'f'}:$size:${base64Encode(utf8.encode(name))}');

      var sent = 0;
      var n = 0;
      while (sent < bytes.length) {
        final end = sent + _chunk < bytes.length ? sent + _chunk : bytes.length;
        final part = Uint8List.sublistView(bytes, sent, end);
        await c.output.writeLine('${_ctl}chunk:$fid:${base64Encode(part)}');
        sent = end;
        if (++n % 16 == 0) {
          await c.output.allSent;
          m.progress = sent / bytes.length;
          notifyListeners();
        }
      }
      await c.output.writeLine('${_ctl}end:$fid');
      await c.output.allSent;
      m.progress = null;
    } catch (e) {
      error = 'Faylni yuborib bo\'lmadi';
      if (sending != null) chats[id]?.remove(sending);
    }
    notifyListeners();
    _save();
  }

  void _add(String id, Message m) {
    chats.putIfAbsent(id, () => []).add(m);
    _save();
  }

  void openChat(String id) {
    activeChatId = id;
    unread[id] = 0;
    notifyListeners();
    _save();
  }

  void closeChat() => activeChatId = null;
}