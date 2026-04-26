// test/ttl_test.dart
// Proves that a packet with TTL=0 is blocked at the border
// and never forwarded to the next node.

import 'package:test/test.dart';
import '../lib/node.dart';
import '../lib/sync.dart';

void main() {
  group('TTL expiry', () {

    test('packet with TTL=0 is not forwarded', () {
      final nodeA = Node(id: 'A');
      final nodeB = Node(id: 'B');

      // Create a packet that has already used all its hops
      nodeA.createPacket('dying message', ttl: 0);

      // A and B meet — but the packet should not cross
      SyncEngine.sync(nodeA, nodeB);

      // B should still be empty
      expect(nodeB.packets.isEmpty, true,
          reason: 'A packet with TTL=0 must never be forwarded');
    });

    test('packet with TTL=1 reaches B but not C', () {
      final nodeA = Node(id: 'A');
      final nodeB = Node(id: 'B');
      final nodeC = Node(id: 'C');

      // One hop remaining
      nodeA.createPacket('one hop left', ttl: 1);

      // A meets B — packet crosses, TTL drops to 0
      SyncEngine.sync(nodeA, nodeB);
      expect(nodeB.packets.isNotEmpty, true,
          reason: 'Packet should reach B — it still had 1 hop');

      // B meets C — packet is now TTL=0, must be blocked
      SyncEngine.sync(nodeB, nodeC);
      expect(nodeC.packets.isEmpty, true,
          reason: 'Packet must not reach C — TTL exhausted at B');
    });

    test('packet with TTL=3 travels full A→B→C chain', () {
      final nodeA = Node(id: 'A');
      final nodeB = Node(id: 'B');
      final nodeC = Node(id: 'C');

      nodeA.createPacket('full journey', ttl: 3);

      SyncEngine.sync(nodeA, nodeB);
      SyncEngine.sync(nodeB, nodeC);

      expect(nodeC.packets.isNotEmpty, true,
          reason: 'Packet with TTL=3 should survive the full chain');
    });

  });
}