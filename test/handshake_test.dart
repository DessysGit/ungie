// test/handshake_test.dart
// Proves the handshake correctly gates gossip behind security.

import 'package:test/test.dart';
import '../lib/handshake.dart';
import '../lib/node.dart';
import '../lib/security.dart';

void main() {
  group('Handshake engine', () {
    late String secret;
    late HandshakeEngine engine;
    late Node nodeA;
    late Node nodeB;

    setUp(() {
      secret = MeshSecurity.generateGroupSecret();
      engine = HandshakeEngine(groupSecret: secret);
      nodeA = Node(id: 'A');
      nodeB = Node(id: 'B');
      nodeA.createPacket('Answer: 42');
      nodeA.createPacket('Note: see page 4');
    });

    test('valid members handshake and sync successfully', () {
      final outcome = engine.attempt(nodeA, nodeB);

      expect(
        outcome.succeeded,
        true,
        reason: 'Two valid members must complete the handshake',
      );
    });

    test('gossip flows after successful handshake', () {
      final outcome = engine.attempt(nodeA, nodeB);

      expect(outcome.succeeded, true);
      expect(
        nodeB.packets.isNotEmpty,
        true,
        reason: 'Node B must receive packets after handshake succeeds',
      );
      expect(
        nodeB.packets.length,
        nodeA.packets.length,
        reason: 'Full sync must occur after handshake',
      );
    });

    test('stranger is rejected — no gossip flows', () {
      final strangerSecret = MeshSecurity.generateGroupSecret();
      final stranger = Node(id: 'Stranger');

      final outcome = engine.attemptWithStranger(
        nodeA,
        stranger,
        strangerSecret,
      );

      expect(
        outcome.succeeded,
        false,
        reason: 'Stranger must be rejected at the handshake gate',
      );
      expect(
        stranger.packets.isEmpty,
        true,
        reason: 'Stranger must receive zero packets',
      );
    });

    test('no data leaks to stranger before rejection', () {
      final strangerSecret = MeshSecurity.generateGroupSecret();
      final stranger = Node(id: 'Stranger');
      final packetsBefore = stranger.packets.length;

      engine.attemptWithStranger(nodeA, stranger, strangerSecret);

      expect(
        stranger.packets.length,
        packetsBefore,
        reason: 'Packet count must not change — handshake blocks all data',
      );
    });

    test('handshake completes in reasonable time', () {
      final outcome = engine.attempt(nodeA, nodeB);

      expect(
        outcome.duration.inMilliseconds,
        lessThan(100),
        reason: 'Handshake must complete within 100ms for BLE window',
      );
    });

    test('multiple sequential handshakes all succeed', () {
      for (int i = 0; i < 10; i++) {
        final a = Node(id: 'A$i')..createPacket('Packet $i');
        final b = Node(id: 'B$i');
        final outcome = engine.attempt(a, b);
        expect(outcome.succeeded, true, reason: 'Handshake $i must succeed');
      }
    });

    test('handshake result describes what happened', () {
      final outcome = engine.attempt(nodeA, nodeB);
      final description = outcome.toString();

      expect(
        description.contains('✓'),
        true,
        reason: 'Success outcome must be clearly described',
      );
    });
  });
}
