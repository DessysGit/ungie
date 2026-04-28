// lib/stress_scheduler.dart
// High-pressure scheduler for 30-node stress testing.
// Tracks metrics, detects collisions, measures convergence.

import 'dart:async';
import 'dart:math';
import 'node.dart';
import 'sync.dart';
import 'metrics.dart';

class StressScheduler {
  final List<Node> nodes;
  final int targetPackets;
  final Duration interval;
  final double sleepProbability;
  final double wakeProbability;
  final Metrics metrics;
  final Random _random = Random();
  Timer? _timer;
  final void Function()? onFullSync;

  StressScheduler({
    required this.nodes,
    required this.targetPackets,
    this.interval = const Duration(milliseconds: 200),
    this.sleepProbability = 0.20,
    this.wakeProbability  = 0.50,
    this.onFullSync,
  }) : metrics = Metrics(
          totalNodes: nodes.length,
          totalPackets: targetPackets,
        );

  void start() {
    _timer = Timer.periodic(interval, (_) => _cycle());
  }

  void stop() {
    _timer?.cancel();
  }

  void _cycle() {
    metrics.recordCycle();

    // Sleep/wake transitions
    for (final node in nodes) {
      if (node.awake && _random.nextDouble() < sleepProbability) {
        node.awake = false;
      } else if (!node.awake && _random.nextDouble() < wakeProbability) {
        node.awake = true;
      }
    }

    // Get awake nodes and shuffle
    final awake = nodes.where((n) => n.awake).toList()..shuffle(_random);

    // Track which nodes are syncing this cycle — detect collisions
    final syncingThisCycle = <String>{};

    for (int i = 0; i < awake.length - 1; i += 2) {
      final a = awake[i];
      final b = awake[i + 1];

      // Collision: node already syncing with someone else this cycle
      if (syncingThisCycle.contains(a.id) ||
          syncingThisCycle.contains(b.id)) {
        metrics.recordCollision();
        continue;
      }

      syncingThisCycle.add(a.id);
      syncingThisCycle.add(b.id);

      // Run sync and analyze log
      final log = SyncEngine.sync(a, b);
      final wasRedundant = log.any((l) => l.contains('Already in sync'));
      final ttlBlocks = log.where((l) => l.contains('TTL=0')).length;

      metrics.recordSync(wasRedundant: wasRedundant);
      for (int t = 0; t < ttlBlocks; t++) {
        metrics.recordTTLBlock();
      }
    }

    // Check if full sync achieved
    final synced = nodes
        .where((n) => n.packets.length == targetPackets)
        .length;
    if (synced == nodes.length) {
      metrics.recordFullSync();
      onFullSync?.call();
    }
  }
}