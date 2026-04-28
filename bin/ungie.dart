// bin/ungie.dart
// Ungie mesh simulation v0.3 — 30-node stress test

import 'dart:async';
import 'package:ungie/node.dart';
import 'package:ungie/stress_scheduler.dart';

void main() async {
  print('');
  print('╔══════════════════════════════════╗');
  print('║       UNGIE — Stress Test        ║');
  print('║       Mesh Simulation v0.3       ║');
  print('╚══════════════════════════════════╝');
  print('');
  print('  Initializing 30 nodes...');

  final nodes = List.generate(
    30,
    (i) => Node(id: String.fromCharCode(65 + (i % 26)) + (i ~/ 26 > 0 ? '${i ~/ 26}' : '')),
  );

  const targetPackets = 3;
  nodes[0].createPacket('Answer: 42');
  nodes[0].createPacket('Note: see page 4');
  nodes[0].createPacket('img:diagram.png.base64');

  print('  Node A seeded with $targetPackets packets');
  print('  Starting stress test — 30 nodes, random sleep/wake');
  print('');

  final scheduler = StressScheduler(
    nodes: nodes,
    targetPackets: targetPackets,
    interval: const Duration(milliseconds: 200),
    onFullSync: () {},
  );

  scheduler.start();

  final reporter = Timer.periodic(const Duration(seconds: 2), (_) {
    final synced = nodes.where((n) => n.packets.length == targetPackets).length;
    final pct = (synced / nodes.length * 100).round();
    final bar = '█' * (pct ~/ 5) + '░' * (20 - pct ~/ 5);
    print('  [$bar] $pct% ($synced/30 nodes synced)');
  });

  await Future.delayed(const Duration(seconds: 20));
  reporter.cancel();
  scheduler.stop();

  print('');
  scheduler.metrics.printReport();

  print('  Node breakdown:');
  for (final node in nodes) {
    final status = node.packets.length == targetPackets ? '✓' : '✗';
    final bar = '█' * node.packets.length + '░' * (targetPackets - node.packets.length);
    print('  $status ${node.id.padRight(3)} $bar');
  }
  print('');
}
