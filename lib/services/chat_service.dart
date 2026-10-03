import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';

/// Bluetooth (Nearby Connections) orqali qurilmalarni topish, ulanish va xabar almashish.
class ChatService extends ChangeNotifier {
  static const _serviceId = 'uz.bluetooth_chat';
  static const _strategy = Strategy.P2P_CLUSTER;

  final _nearby = Nearby();

  String myName = 'Men';
  bool scanning = false;
  String? error; // UI snackbar uchun
  String? activeChatId;

  final Map<String, Peer> peers = {};
  final Map<String, List<Message>> chats = {};
  final Map<String, int> unread = {};

  List<Message> messagesOf(String id) => chats[id] ?? [];

  // ---------- Qidirish ----------
  Future<void> startScan() async {
    error = null;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    if (!await Permission.location.serviceStatus.isEnabled) {
      error = 'Telefonda Joylashuv (GPS) ni yoqing';
      notifyListeners();
      return;
    }

    try {
      await stopScan(notify: false);
      await _nearby.startAdvertising(
        myName,
        _strategy,
        onConnectionInitiated: _onInit,
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      await _nearby.startDiscovery(
        myName,
        _strategy,
        onEndpointFound: (id, name, _) {
          final p = peers.putIfAbsent(id, () => Peer(id, name));
          p.name = name;
          notifyListeners();
        },
        onEndpointLost: (id) {
          final p = peers[id];
          if (p != null && !p.connected) peers.remove(id);
          notifyListeners();
        },
        serviceId: _serviceId,
      );
      scanning = true;
    } catch (e) {
      scanning = false;
      error = 'Bluetooth xatosi: $e';
    }
    notifyListeners();
  }

  Future<void> stopScan({bool notify = true}) async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
    } catch (_) {}
    scanning = false;
    if (notify) notifyListeners();
  }

  Future<void> stopAll() async {
    await stopScan(notify: false);
    try {
      await _nearby.stopAllEndpoints();
    } catch (_) {}
  }

  void setName(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    myName = n;
    notifyListeners();
    if (scanning) startScan(); // yangi nom bilan qayta ishga tushadi
  }

  // ---------- Ulanish ----------
  Future<void> connect(String id) async {
    final p = peers[id];
    if (p == null || p.connected || p.connecting) return;
    p.connecting = true;
    notifyListeners();
    try {
      await _nearby.requestConnection(
        myName,
        id,
        onConnectionInitiated: _onInit,
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      p.connecting = false;
      error = 'Ulanib bo\'lmadi: $e';
      notifyListeners();
    }
  }

  void _onInit(String id, ConnectionInfo info) {
    peers.putIfAbsent(id, () => Peer(id, info.endpointName)).connecting = true;
    _nearby.acceptConnection(
      id,
      onPayLoadRecieved: _onPayload,
      onPayloadTransferUpdate: (_, __) {},
    );
    notifyListeners();
  }

  void _onResult(String id, Status status) {
    final p = peers[id];
    if (p == null) return;
    p.connecting = false;
    p.connected = status == Status.CONNECTED;
    if (status != Status.CONNECTED) error = 'Ulanish rad etildi';
    notifyListeners();
  }

  void _onDisconnected(String id) {
    final p = peers[id];
    if (p == null) return;
    p.connected = false;
    p.connecting = false;
    notifyListeners();
  }

  // ---------- Xabarlar ----------
  void _onPayload(String id, Payload payload) {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    _add(id, Message(utf8.decode(payload.bytes!), mine: false));
    if (activeChatId != id) unread[id] = (unread[id] ?? 0) + 1;
    notifyListeners();
  }

  Future<void> send(String id, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    try {
      await _nearby.sendBytesPayload(id, Uint8List.fromList(utf8.encode(t)));
      _add(id, Message(t, mine: true));
    } catch (e) {
      error = 'Yuborib bo\'lmadi: $e';
    }
    notifyListeners();
  }

  void _add(String id, Message m) => chats.putIfAbsent(id, () => []).add(m);

  void openChat(String id) {
    activeChatId = id;
    unread[id] = 0;
    notifyListeners();
  }

  void closeChat() => activeChatId = null;
}