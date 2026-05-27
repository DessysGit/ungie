// app/lib/mesh_screen.dart
// Live mesh visualization — runs the real gossip engine
// and shows packets flowing between nodes in real time.
// No Scaffold — rendered inside HomeScreen's Scaffold.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ungie/node.dart';
import 'package:ungie/sync.dart';

// ── Log entry ──────────────────────────────────────────────
enum LogType { sync, push, skip, done, sleep, wake }

class LogEntry {
  final String message;
  final LogType type;
  final DateTime time;
  LogEntry(this.message, this.type) : time = DateTime.now();
}

// ── Mesh controller ────────────────────────────────────────
class MeshController extends ChangeNotifier {
  final List<Node> nodes;
  final List<LogEntry> log = [];
  final Random _random = Random();
  Timer? _timer;
  int cycle = 0;
  bool running = false;

  static const int maxLog = 80;
  static const double sleepProb = 0.20;
  static const double wakeProb = 0.60;

  MeshController({required this.nodes});

  void start() {
    running = true;
    _timer = Timer.periodic(
        const Duration(milliseconds: 900), (_) => _cycle());
    notifyListeners();
  }

  void stop() {
    running = false;
    _timer?.cancel();
    notifyListeners();
  }

  void reset() {
    stop();
    cycle = 0;
    log.clear();
    for (final n in nodes) {
      n.packets.clear();
      n.awake = true;
    }
    notifyListeners();
  }

  void injectPacket(String content) {
    final awake = nodes.where((n) => n.awake).toList();
    if (awake.isEmpty) return;
    final origin = awake[_random.nextInt(awake.length)];
    origin.createPacket(content);
    _addLog('💉 Injected "$content" → node ${origin.id}', LogType.push);
    notifyListeners();
  }

  void _cycle() {
    cycle++;
    for (final node in nodes) {
      if (node.awake && _random.nextDouble() < sleepProb) {
        node.awake = false;
        _addLog('💤 Node ${node.id} fell asleep', LogType.sleep);
      } else if (!node.awake && _random.nextDouble() < wakeProb) {
        node.awake = true;
        _addLog('⚡ Node ${node.id} woke up', LogType.wake);
      }
    }

    final awake = nodes.where((n) => n.awake).toList()..shuffle(_random);
    if (awake.length < 2) {
      _addLog('⚠ Cycle $cycle — not enough awake nodes', LogType.skip);
    } else {
      for (int i = 0; i < awake.length - 1; i += 2) {
        final a = awake[i];
        final b = awake[i + 1];
        final lines = SyncEngine.sync(a, b);
        for (final line in lines) {
          if (line.contains('Already in sync')) {
            _addLog(line.trim(), LogType.skip);
          } else if (line.contains('pushed')) {
            _addLog(line.trim(), LogType.push);
          } else if (line.contains('TTL=0')) {
            _addLog(line.trim(), LogType.skip);
          } else if (line.contains('Syncing')) {
            _addLog(line.trim(), LogType.sync);
          }
        }
      }
    }

    final maxPackets =
        nodes.map((n) => n.packets.length).reduce(max);
    final allSynced = nodes.every(
        (n) => n.packets.length == maxPackets && maxPackets > 0);
    if (allSynced && maxPackets > 0) {
      _addLog(
          '✓ All nodes in sync — $maxPackets packet(s)', LogType.done);
    }

    notifyListeners();
  }

  void _addLog(String message, LogType type) {
    log.add(LogEntry(message, type));
    if (log.length > maxLog) log.removeAt(0);
  }

  int get totalPackets =>
      nodes.fold(0, (sum, n) => sum + n.packets.length);
  int get awakeCount => nodes.where((n) => n.awake).length;
}

// ── Screen (no Scaffold) ───────────────────────────────────
class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  late MeshController _ctrl;
  final ScrollController _logScroll = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  static const _nodeIds = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    final nodes = _nodeIds.map((id) => Node(id: id)).toList();
    nodes[0].createPacket('Answer: 42');
    nodes[0].createPacket('Note: see page 4');
    _ctrl = MeshController(nodes: nodes);
    _ctrl.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScroll.hasClients) {
          _logScroll.animateTo(
            _logScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onUpdate);
    _ctrl.stop();
    _logScroll.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _showInjectDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inject packet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Creates a packet at a random awake node',
                style:
                    TextStyle(color: Color(0x80FFFFFF), fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: _inputCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. "Answer: photosynthesis"',
                hintStyle:
                    const TextStyle(color: Color(0x40FFFFFF)),
                filled: true,
                fillColor: const Color(0x14FFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _ctrl.injectPacket(val.trim());
                  _inputCtrl.clear();
                  Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_inputCtrl.text.trim().isNotEmpty) {
                    _ctrl.injectPacket(_inputCtrl.text.trim());
                    _inputCtrl.clear();
                    Navigator.pop(ctx);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7F77DD),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Inject into mesh'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Controls row ────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _ctrl.running
                      ? 'Cycle ${_ctrl.cycle} · ${_ctrl.awakeCount}/${_ctrl.nodes.length} awake'
                      : 'Mesh paused — tap ▶ to start',
                  style: const TextStyle(
                      color: Color(0x80FFFFFF), fontSize: 12),
                ),
              ),
              // Reset
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: Color(0x60FFFFFF), size: 20),
                onPressed: _ctrl.reset,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
              // Play/pause
              GestureDetector(
                onTap:
                    _ctrl.running ? _ctrl.stop : _ctrl.start,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F77DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _ctrl.running
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _ctrl.running ? 'Pause' : 'Start',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Node health bars ────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Row(
            children: _ctrl.nodes.map((node) {
              final count = node.packets.length;
              final maxPkts = _ctrl.nodes
                  .map((n) => n.packets.length)
                  .fold(0, max);
              final fill = maxPkts == 0
                  ? 0.0
                  : count / maxPkts.toDouble();
              return Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  child: _NodeCard(
                    id: node.id,
                    awake: node.awake,
                    packets: count,
                    fill: fill,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Stats row ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 8),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                  label: 'Cycle',
                  value: '${_ctrl.cycle}',
                  color: const Color(0xFF7F77DD)),
              _Stat(
                  label: 'Packets',
                  value: '${_ctrl.totalPackets}',
                  color: const Color(0xFF1D9E75)),
              _Stat(
                  label: 'Awake',
                  value:
                      '${_ctrl.awakeCount}/${_ctrl.nodes.length}',
                  color: const Color(0xFFBA7517)),
            ],
          ),
        ),

        // ── Live gossip log ─────────────────────────────────
        Expanded(
          child: _ctrl.log.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hub_outlined,
                          size: 56, color: Color(0x1AFFFFFF)),
                      const SizedBox(height: 16),
                      const Text('Mesh is ready',
                          style: TextStyle(
                              color: Color(0x80FFFFFF),
                              fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text(
                          'Watch packets gossip between nodes',
                          style: TextStyle(
                              color: Color(0x40FFFFFF),
                              fontSize: 12)),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _ctrl.start,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F77DD),
                            borderRadius:
                                BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow,
                                  color: Colors.white),
                              SizedBox(width: 8),
                              Text('Start mesh',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _logScroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: _ctrl.log.length,
                  itemBuilder: (ctx, i) {
                    return _LogLine(entry: _ctrl.log[i]);
                  },
                ),
        ),

        // ── Inject button ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border:
                Border(top: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showInjectDialog,
              icon: const Icon(Icons.add_circle_outline,
                  size: 18, color: Color(0xFF7F77DD)),
              label: const Text('Inject packet into mesh',
                  style: TextStyle(color: Color(0xFF7F77DD))),
              style: OutlinedButton.styleFrom(
                side:
                    const BorderSide(color: Color(0x337F77DD)),
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Node card widget ───────────────────────────────────────
class _NodeCard extends StatelessWidget {
  final String id;
  final bool awake;
  final int packets;
  final double fill;

  const _NodeCard({
    required this.id,
    required this.awake,
    required this.packets,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        awake ? const Color(0xFF7F77DD) : const Color(0x40888780);
    return Column(
      children: [
        Text(awake ? '⚡' : '💤',
            style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                heightFactor: fill,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Center(
                child: Text(id,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('$packets',
            style: TextStyle(
                color: awake
                    ? const Color(0xFF7F77DD)
                    : const Color(0x40FFFFFF),
                fontSize: 11)),
      ],
    );
  }
}

// ── Log line widget ────────────────────────────────────────
class _LogLine extends StatelessWidget {
  final LogEntry entry;
  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.type) {
      LogType.push => const Color(0xFF1D9E75),
      LogType.sync => const Color(0xFF7F77DD),
      LogType.done => const Color(0xFFBA7517),
      LogType.sleep => const Color(0x60FFFFFF),
      LogType.wake => const Color(0xFFBA7517),
      LogType.skip => const Color(0x40FFFFFF),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        entry.message,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
}

// ── Stat widget ────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(
      {required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(
                color: Color(0x66FFFFFF), fontSize: 10)),
      ],
    );
  }
}
