// lib/security.dart
// Lightweight membership proof for the Ungie mesh.
// Proves a device holds the group secret without revealing it.
// Uses HMAC-SHA256 commitment tokens.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class MeshSecurity {
  // Generate a random group secret (teacher runs this once)
  // Returns a hex string — share this securely with enrolled devices
  static String generateGroupSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Derive a membership token from the group secret and device ID
  // The token proves knowledge of the secret without revealing it
  static String deriveToken(String groupSecret, String deviceId) {
    final key = utf8.encode(groupSecret);
    final message = utf8.encode('ungie:member:$deviceId');
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(message);
    return digest.toString();
  }

  // Generate a challenge — a random nonce the verifier sends
  static String generateChallenge() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Respond to a challenge — proves you hold the secret
  // without revealing the secret or your token
  static String respondToChallenge(String groupSecret, String challenge) {
    final key = utf8.encode(groupSecret);
    final message = utf8.encode('ungie:challenge:$challenge');
    final hmac = Hmac(sha256, key);
    return hmac.convert(message).toString();
  }

  // Verify a challenge response
  // Returns true if the responder holds the same group secret
  static bool verifyResponse(
    String groupSecret,
    String challenge,
    String response,
  ) {
    final expected = respondToChallenge(groupSecret, challenge);
    // Constant-time comparison to prevent timing attacks
    return _constantTimeEquals(expected, response);
  }

  // Constant-time string comparison
  // Prevents attackers from guessing the token byte by byte
  // based on how long verification takes
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
