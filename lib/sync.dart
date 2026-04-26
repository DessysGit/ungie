// lib/sync.dart
// The gossip engine — the anti-entropy sync function.
// When two nodes "meet", this is what happens between them.

import 'node.dart';
import 'packet.dart';

class SyncEngine {
  // Returns a log of what happened during the sync
  static List<String> sync(Node a, Node b) {
    final log = <String>[];

    log.add('--- Syncing ${a.id} ↔ ${b.id} ---');

    // What does A have that B lacks?
    final bNeeds = _missing(from: a, against: b);

    // What does B have that A lacks?
    final aNeeds = _missing(from: b, against: a);

    if (bNeeds.isEmpty && aNeeds.isEmpty) {
      log.add('  ✓ Already in sync. Nothing to exchange.');
      return log;
    }

    // Push from A → B
    for (final packet in bNeeds) {
      if (packet.ttl > 0) {
        b.receive(packet.forward());
        log.add('  → ${a.id} pushed "${packet.content}" to ${b.id} (ttl ${packet.ttl} → ${packet.ttl - 1})');
      } else {
        log.add('  ✗ "${packet.content}" TTL=0, not forwarded');
      }
    }

    // Push from B → A
    for (final packet in aNeeds) {
      if (packet.ttl > 0) {
        a.receive(packet.forward());
        log.add('  → ${b.id} pushed "${packet.content}" to ${a.id} (ttl ${packet.ttl} → ${packet.ttl - 1})');
      } else {
        log.add('  ✗ "${packet.content}" TTL=0, not forwarded');
      }
    }

    return log;
  }

  // Find packets that [from] has but [against] lacks
  static List<Packet> _missing({required Node from, required Node against}) {
    final missing = from.packets.values
        .where((p) => !against.has(p.id))
        .toList();

    // Priority queue — short content (text) before long content (images)
    missing.sort((a, b) => a.content.length.compareTo(b.content.length));

    return missing;
  }
}