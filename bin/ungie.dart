// bin/ungie.dart
// The Ungie mesh simulation runner.
// Proves a message travels from Node A to Node C
// through silent bridge Node B.

import '../lib/node.dart';
import '../lib/sync.dart';

void main() {
  print('');
  print('╔══════════════════════════════════╗');
  print('║       UNGIE — Hello World        ║');
  print('║       Mesh Simulation v0.1       ║');
  print('╚══════════════════════════════════╝');
  print('');

  // --- SETUP ---
  // Three simulated phones.
  // A knows B. B knows C. A and C have never met.
  final nodeA = Node(id: 'A');
  final nodeB = Node(id: 'B');
  final nodeC = Node(id: 'C');

  // Node A creates two packets
  nodeA.createPacket('Hello from A');
  nodeA.createPacket('Answer: 42');

  print('INITIAL STATE');
  print('  $nodeA');
  print('  $nodeB');
  print('  $nodeC');
  print('');

  // --- PHASE 1: A meets B ---
  print('PHASE 1 — A and B meet');
  final log1 = SyncEngine.sync(nodeA, nodeB);
  log1.forEach(print);
  print('');

  // --- PHASE 2: B meets C ---
  print('PHASE 2 — B and C meet (A is not here)');
  final log2 = SyncEngine.sync(nodeB, nodeC);
  log2.forEach(print);
  print('');

  // --- VERIFY ---
  print('FINAL STATE');
  print('  $nodeA');
  print('  $nodeB');
  print('  $nodeC');
  print('');

  // Did all of A's packets reach C?
  final aPackets = nodeA.packets.values.where((p) => p.origin == 'A');
  final allReached = aPackets.every((p) => nodeC.has(p.id));

  if (allReached) {
    print('✓ SUCCESS — A\'s packets reached C through silent bridge B.');
    print('  A and C never met directly. This is your Hello World mesh.');
  } else {
    print('✗ FAILED — some packets did not reach C. Check TTL values.');
  }
  print('');
}