// lib/scheduler.dart
// The heartbeat of the Ungie mesh — now with Sleep/Wake cycle.
// Nodes randomly sleep and wake each cycle, simulating
// real phone behavior. The mesh converges regardless.

import 'dart:async';
import 'dart:math';
import 'node.dart';
import 'sync.dart';

class Scheduler {
  final List<Node> nodes;
  final Duration interval;
  final double sleepProbability;   // chance a node falls asleep each cycle
  final double wakeProbability;    // chance a sleeping node wakes up
  final Random _random = Random();
  int _tick = 0;
  Timer? _timer;

  Scheduler({
    required this.nodes,
    this.interval = const Duration(milliseconds: 800),
    this.sleepProbability = 0.25,  // 25% chance to sleep each cycle
    this.wakeProbability  = 0.60,  // 60% chance to wake each cycle
  });

  void start() {
    print('  Mesh heartbeat started — ${nodes.length} nodes active');
    print('  Sleep probability: ${(sleepProbability*100).round()}% per cycle');
    print('  Wake probability:  ${(wakeProbability*100).round()}% per cycle');
    print('');
    _timer = Timer.periodic(interval, (_) => _cycle());
  }

  void stop() {
    _timer?.cancel();
    print('');
    print('  Mesh heartbeat stopped after $_tick cycles');
  }

  void _cycle() {
    _tick++;
    print('── Cycle $_tick ──────────────────────────');

    // Update sleep/wake states
    for (final node in nodes) {
      if (node.awake && _random.nextDouble() < sleepProbability) {
        node.awake = false;
        print('  💤 Node ${node.id} fell asleep');
      } else if (!node.awake && _random.nextDouble() < wakeProbability) {
        node.awake = true;
        print('  ⚡ Node ${node.id} woke up');
      }
    }

    // Only pair awake nodes
    final awakeNodes = nodes.where((n) => n.awake).toList()..shuffle(_random);

    if (awakeNodes.length < 2) {
      print('  ⚠ Not enough awake nodes to sync');
    } else {
      for (int i = 0; i < awakeNodes.length - 1; i += 2) {
        final a = awakeNodes[i];
        final b = awakeNodes[i + 1];
        final log = SyncEngine.sync(a, b);
        log.forEach(print);
      }
    }

    // State bar for all nodes — awake or asleep
    print('');
    print('  State:');
    for (final node in nodes) {
      final count = node.packets.length;
      final bar = '█' * count + '░' * (5 - count.clamp(0, 5));
      final status = node.awake ? '⚡' : '💤';
      print('  $status ${node.id}: $bar $count packet(s)');
    }
    print('');
  }
}