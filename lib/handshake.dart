// lib/handshake.dart
// The gatekeeper of the Ungie mesh.
// Runs a challenge-response proof between two devices.
// Only after a successful handshake does gossip begin.
// Combines the security layer with the sync engine.

import 'security.dart';
import 'node.dart';
import 'sync.dart';

// Result of a handshake attempt
enum HandshakeResult { success, failedChallenge, failedVerification }

class HandshakeOutcome {
  final HandshakeResult result;
  final List<String> syncLog;
  final Duration duration;

  HandshakeOutcome({
    required this.result,
    required this.syncLog,
    required this.duration,
  });

  bool get succeeded => result == HandshakeResult.success;

  @override
  String toString() {
    final status = switch (result) {
      HandshakeResult.success => '✓ Handshake succeeded',
      HandshakeResult.failedChallenge => '✗ Challenge generation failed',
      HandshakeResult.failedVerification =>
        '✗ Verification failed — stranger rejected',
    };
    final lines = [status];
    if (syncLog.isNotEmpty) lines.addAll(syncLog);
    lines.add('  Duration: ${duration.inMilliseconds}ms');
    return lines.join('\n');
  }
}

class HandshakeEngine {
  final String groupSecret;

  HandshakeEngine({required this.groupSecret});

  // Simulate a full handshake + sync between two nodes.
  // In production this runs over BLE/Wi-Fi Direct.
  // In simulation, both nodes are local — we run both sides ourselves.
  HandshakeOutcome attempt(Node initiator, Node responder) {
    final stopwatch = Stopwatch()..start();

    // Step 1 — Initiator generates a challenge
    final challenge = MeshSecurity.generateChallenge();

    // Step 2 — Responder produces an HMAC response
    // (in real radio: initiator sends challenge over BLE,
    //  responder sends back the HMAC response)
    final response = MeshSecurity.respondToChallenge(groupSecret, challenge);

    // Step 3 — Initiator verifies the response
    final verified = MeshSecurity.verifyResponse(
      groupSecret,
      challenge,
      response,
    );

    if (!verified) {
      stopwatch.stop();
      return HandshakeOutcome(
        result: HandshakeResult.failedVerification,
        syncLog: [],
        duration: stopwatch.elapsed,
      );
    }

    // Step 4 — Handshake passed — gossip begins
    final syncLog = SyncEngine.sync(initiator, responder);
    stopwatch.stop();

    return HandshakeOutcome(
      result: HandshakeResult.success,
      syncLog: syncLog,
      duration: stopwatch.elapsed,
    );
  }

  // Simulate a handshake with a stranger (wrong secret)
  HandshakeOutcome attemptWithStranger(
    Node initiator,
    Node stranger,
    String strangerSecret,
  ) {
    final stopwatch = Stopwatch()..start();

    final challenge = MeshSecurity.generateChallenge();

    // Stranger responds with their own (wrong) secret
    final strangerResponse = MeshSecurity.respondToChallenge(
      strangerSecret,
      challenge,
    );

    // Initiator verifies — should fail
    final verified = MeshSecurity.verifyResponse(
      groupSecret,
      challenge,
      strangerResponse,
    );

    stopwatch.stop();

    return HandshakeOutcome(
      result: verified
          ? HandshakeResult.success
          : HandshakeResult.failedVerification,
      syncLog: [],
      duration: stopwatch.elapsed,
    );
  }
}
