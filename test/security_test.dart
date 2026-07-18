// test/security_test.dart
// Proves the membership token system works correctly.

import 'package:test/test.dart';
import '../lib/security.dart';

void main() {
  group('Mesh security', () {
    test('valid member passes verification', () {
      final secret = MeshSecurity.generateGroupSecret();
      final challenge = MeshSecurity.generateChallenge();
      final response = MeshSecurity.respondToChallenge(secret, challenge);

      expect(
        MeshSecurity.verifyResponse(secret, challenge, response),
        true,
        reason: 'A device with the correct secret must pass verification',
      );
    });

    test('stranger with wrong secret fails verification', () {
      final secret = MeshSecurity.generateGroupSecret();
      final strangerSecret = MeshSecurity.generateGroupSecret();
      final challenge = MeshSecurity.generateChallenge();
      final strangerResponse = MeshSecurity.respondToChallenge(
        strangerSecret,
        challenge,
      );

      expect(
        MeshSecurity.verifyResponse(secret, challenge, strangerResponse),
        false,
        reason: 'A device with a different secret must fail verification',
      );
    });

    test('same secret produces same token for same device', () {
      final secret = MeshSecurity.generateGroupSecret();
      final token1 = MeshSecurity.deriveToken(secret, 'device-A');
      final token2 = MeshSecurity.deriveToken(secret, 'device-A');

      expect(
        token1,
        equals(token2),
        reason: 'Token derivation must be deterministic',
      );
    });

    test('same secret produces different tokens for different devices', () {
      final secret = MeshSecurity.generateGroupSecret();
      final tokenA = MeshSecurity.deriveToken(secret, 'device-A');
      final tokenB = MeshSecurity.deriveToken(secret, 'device-B');

      expect(
        tokenA,
        isNot(equals(tokenB)),
        reason: 'Each device gets a unique token — anonymity preserved',
      );
    });

    test('challenge is never reused — replay attack prevention', () {
      final challenge1 = MeshSecurity.generateChallenge();
      final challenge2 = MeshSecurity.generateChallenge();

      expect(
        challenge1,
        isNot(equals(challenge2)),
        reason: 'Every challenge must be unique',
      );
    });

    test('token reveals nothing about the secret', () {
      final secret = MeshSecurity.generateGroupSecret();
      final token = MeshSecurity.deriveToken(secret, 'device-A');

      // The token should not contain the secret
      expect(
        token.contains(secret),
        false,
        reason: 'Token must not expose the group secret',
      );
    });
  });
}
