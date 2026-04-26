// lib/packet.dart
// The atom of the Ungie mesh.
// Every piece of information that travels the mesh is a Packet.

class Packet {
  final String id;       // SHA-256 fingerprint of the content
  final String content;  // the actual data (text answer, etc.)
  final String origin;   // which node created this packet
  int ttl;               // hops remaining before this packet dies

  Packet({
    required this.id,
    required this.content,
    required this.origin,
    required this.ttl,
  });

  // Create a copy with a decremented TTL (used when forwarding)
  Packet forward() {
    return Packet(
      id: id,
      content: content,
      origin: origin,
      ttl: ttl - 1,
    );
  }

  @override
  String toString() {
    return 'Packet(id: $id, content: "$content", origin: $origin, ttl: $ttl)';
  }
}