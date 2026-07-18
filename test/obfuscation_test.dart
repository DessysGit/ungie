// test/obfuscation_test.dart
// Proves the obfuscation layer encodes and decodes correctly
// and that strangers cannot decode mesh advertisements.

import 'package:test/test.dart';
import '../lib/obfuscation.dart';
import '../lib/security.dart';

void main() {
  group('Packet obfuscation', () {

    late String secret;
    late MeshObfuscator obfuscator;
    late ObfuscatedPacket packet;

    setUp(() {
      secret = MeshSecurity.generateGroupSecret();
      obfuscator = MeshObfuscator(
        meshId: 'classroom-101',
        groupSecret: secret,
      );
      packet = ObfuscatedPacket(
        meshId: 'classroom-101',
        payloadHash: 'a1b2c3d4e5f6' * 4,
        ttl: 3,
        priority: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('encoded advertisement is exactly 31 bytes', () {
      final encoded = obfuscator.encode(packet);
      expect(encoded.length, 31,
          reason: 'BLE advertising payload is capped at 31 bytes');
    });

    test('looks like Apple manufacturer data to passive scanners', () {
      final encoded = obfuscator.encode(packet);
      // Apple company ID
      expect(encoded[0], 0x4C);
      expect(encoded[1], 0x00);
      // Apple Nearby type
      expect(encoded[2], 0x10);
    });

    test('valid member can decode their own advertisement', () {
      final encoded = obfuscator.encode(packet);
      final decoded = obfuscator.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.ttl, packet.ttl);
      expect(decoded.priority, packet.priority);
    });

    test('TTL and priority survive encode/decode', () {
      final highPriority = ObfuscatedPacket(
        meshId: 'classroom-101',
        payloadHash: 'a1b2c3d4e5f6' * 4,
        ttl: 2,
        priority: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final encoded = obfuscator.encode(highPriority);
      final decoded = obfuscator.decode(encoded);

      expect(decoded!.ttl, 2);
      expect(decoded.priority, 1);
    });

    test('stranger with different secret cannot decode', () {
      final strangerSecret = MeshSecurity.generateGroupSecret();
      final strangerObfuscator = MeshObfuscator(
        meshId: 'classroom-101',
        groupSecret: strangerSecret,
      );
      final encoded = obfuscator.encode(packet);
      final decoded = strangerObfuscator.decode(encoded);

      expect(decoded, isNull,
          reason: 'Wrong group secret means wrong mesh fingerprint — rejected');
    });

    test('different mesh ID cannot decode', () {
      final wrongMeshObfuscator = MeshObfuscator(
        meshId: 'classroom-999',
        groupSecret: secret,
      );
      final encoded = obfuscator.encode(packet);
      final decoded = wrongMeshObfuscator.decode(encoded);

      expect(decoded, isNull,
          reason: 'Wrong mesh ID produces wrong fingerprint — rejected');
    });

    test('timestamp survives encode/decode', () {
      final encoded = obfuscator.encode(packet);
      final decoded = obfuscator.decode(encoded);

      expect(
        decoded!.timestamp.millisecondsSinceEpoch ~/ 1000,
        packet.timestamp.millisecondsSinceEpoch ~/ 1000,
        reason: 'Timestamp must survive the round trip',
      );
    });

  });
}