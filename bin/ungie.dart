// bin/ungie.dart
// Ungie mesh simulation v0.2 — self-running scheduler

import 'dart:async';
import '../lib/node.dart';
import '../lib/scheduler.dart';

void main() async {
  print('');
  print('╔══════════════════════════════════╗');
  print('║       UNGIE — Scheduler          ║');
  print('║       Mesh Simulation v0.2       ║');
  print('╚══════════════════════════════════╝');
  print('');

  // Five nodes — a realistic small classroom mesh
  final nodes = [
    Node(id: 'A'),
    Node(id: 'B'),
    Node(id: 'C'),
    Node(id: 'D'),
    Node(id: 'E'),
  ];

  // Only A starts with data
  nodes[0].createPacket('Answer: 42');
  nodes[0].createPacket('Note: see page 4');
  nodes[0].createPacket('img:diagram.png.base64');

  print('INITIAL STATE — only A has data');
  print('');

  // Start the mesh — let it run for 6 cycles then stop
  final scheduler = Scheduler(nodes: nodes);
  scheduler.start();

  // Wait 6 cycles then stop and verify
  await Future.delayed(const Duration(milliseconds: 10400));
  scheduler.stop();

  // Final verification — did all nodes get all packets?
  print('');
  print('FINAL VERIFICATION');
  print('');
  final total = nodes[0].packets.length;
  bool allReached = true;

  for (final node in nodes) {
    final has = node.packets.length;
    final status = has == total ? '✓' : '✗';
    print('  $status Node ${node.id}: $has / $total packets');
    if (has != total) allReached = false;
  }

  print('');
  if (allReached) {
    print('✓ All nodes reached full sync through gossip alone.');
  } else {
    print('  Some nodes not yet synced — mesh needs more cycles.');
  }
  print('');
}