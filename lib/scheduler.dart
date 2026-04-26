// lib/scheduler.dart
// The heartbeat of the Ungie mesh.
// Simulates phones waking up, finding neighbors,
// syncing, and sleeping again — automatically.

import 'dart:async';
import 'dart:math';
import 'node.dart';
import 'sync.dart';

class Scheduler {
  final List<Node> nodes;
  final Duration interval;
  final Random _random = Random();
  int _tick = 0;
  Timer? _timer;

  Scheduler({
    required this.nodes,
    this.interval = const Duration(milliseconds: 800),
  });

  // Start the mesh heartbeat
  void start() {
    print('  Mesh heartbeat started — ${nodes.length} nodes active');
    print('  Interval: ${interval.inMilliseconds}ms per cycle');
    print('');
    _timer = Timer.periodic(interval, (_) => _cycle());
  }

  // Stop the heartbeat
  void stop() {
    _timer?.cancel();
    print('');
    print('  Mesh heartbeat stopped after $_tick cycles');
  }

  // One wake cycle — pair random neighbors and sync
  void _cycle() {
    _tick++;
    print('── Cycle $_tick ──────────────────────────');

    // Shuffle nodes to simulate random proximity
    final shuffled = [...nodes]..shuffle(_random);

    // Pair them up — each phone meets one neighbor per cycle
    for (int i = 0; i < shuffled.length - 1; i += 2) {
      final a = shuffled[i];
      final b = shuffled[i + 1];

      final log = SyncEngine.sync(a, b);
      log.forEach(print);
    }

    // Print current state of all nodes
    print('');
    print('  State:');
    for (final node in nodes) {
      final count = node.packets.length;
      final bar = '█' * count + '░' * (5 - count.clamp(0, 5));
      print('  ${node.id}: $bar $count packet(s)');
    }
    print('');
  }
}