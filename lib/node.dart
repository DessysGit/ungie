// lib/node.dart
// A Node is a simulated phone in the Ungie mesh.
// It holds a collection of packets and knows how to
// generate new ones.

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'packet.dart';

class Node {
  final String id;                   // e.g. "A", "B", "C"
  final Map<String, Packet> packets; // keyed by packet ID for fast lookup
  bool awake = true;                 // sleep/wake state

  Node({required this.id}) : packets = {};

  // Create a brand new packet originating from this node
  Packet createPacket(String content, {int ttl = 3}) {
    final fingerprint = _hash(content + id + DateTime.now().toIso8601String());
    final packet = Packet(
      id: fingerprint,
      content: content,
      origin: id,
      ttl: ttl,
    );
    packets[packet.id] = packet;
    return packet;
  }

  // Accept an incoming packet from a peer (already forwarded)
  void receive(Packet packet) {
    packets[packet.id] = packet;
  }

  // Does this node already have a packet with this ID?
  bool has(String id) => packets.containsKey(id);

  // SHA-256 fingerprint — content addressing
  String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 12);
  }

  @override
  String toString() {
    final contents = packets.values.map((p) => '"${p.content}"').join(', ');
    return 'Node $id [$contents]';
  }
}
