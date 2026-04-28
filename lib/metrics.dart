// lib/metrics.dart
// Tracks mesh health across a simulation run.
// Measures convergence speed, collision pressure,
// and TTL orphan rate.

class Metrics {
  final int totalNodes;
  final int totalPackets;

  int cyclesElapsed = 0;
  int? cyclesUntilFullSync;
  int totalSyncs = 0;
  int redundantSyncs = 0;   // already-in-sync meetings
  int blockedByTTL = 0;     // packets that died before delivery
  int collisionEvents = 0;  // nodes approached twice in one cycle

  Metrics({required this.totalNodes, required this.totalPackets});

  void recordSync({required bool wasRedundant}) {
    totalSyncs++;
    if (wasRedundant) redundantSyncs++;
  }

  void recordTTLBlock() => blockedByTTL++;
  void recordCollision() => collisionEvents++;
  void recordCycle() => cyclesElapsed++;

  void recordFullSync() {
    cyclesUntilFullSync ??= cyclesElapsed;
  }

  double get redundancyRate =>
      totalSyncs == 0 ? 0 : redundantSyncs / totalSyncs;

  void printReport() {
    print('╔══════════════════════════════════════╗');
    print('║         MESH HEALTH REPORT           ║');
    print('╚══════════════════════════════════════╝');
    print('');
    print('  Nodes:              $totalNodes');
    print('  Packets per origin: $totalPackets');
    print('  Cycles elapsed:     $cyclesElapsed');
    print('');
    print('  Convergence');
    if (cyclesUntilFullSync != null) {
      print('  ✓ Full sync at cycle $cyclesUntilFullSync');
    } else {
      print('  ✗ Full sync NOT achieved');
    }
    print('');
    print('  Sync activity');
    print('  Total syncs:      $totalSyncs');
    print('  Redundant syncs:  $redundantSyncs (${(redundancyRate*100).round()}%)');
    print('  TTL blocks:       $blockedByTTL');
    print('  Collision events: $collisionEvents');
    print('');
  }
}