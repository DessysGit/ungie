// app/lib/main.dart
// Ungie — two screens with working tab navigation

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'mesh_screen.dart';

void main() {
  runApp(const UngieApp());
}

class UngieApp extends StatelessWidget {
  const UngieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ungie Mesh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7F77DD),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ── Home shell ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        elevation: 0,
        title: const Text(
          'Ungie Mesh',
          style: TextStyle(
            color: Color(0xFF7F77DD),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: _tab == 0 ? const DiscoveryBody() : const MeshScreen(),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F13),
            border: Border(top: BorderSide(color: Color(0x30FFFFFF))),
          ),
          child: Row(
            children: [
              _Tab(
                icon: Icons.bluetooth_searching,
                label: 'Discover',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              _Tab(
                icon: Icons.hub_outlined,
                label: 'Mesh',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFF7F77DD) : const Color(0x60FFFFFF);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
            const SizedBox(height: 2),
            Container(
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF7F77DD)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Discovery body (no Scaffold) ───────────────────────────
class DiscoveryBody extends StatefulWidget {
  const DiscoveryBody({super.key});

  @override
  State<DiscoveryBody> createState() => _DiscoveryBodyState();
}

class _DiscoveryBodyState extends State<DiscoveryBody> {
  final Map<String, DiscoveredDevice> _devices = {};
  bool _isScanning = false;
  String _status = 'Tap scan to start';
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : 'Device ${r.device.remoteId.toString().substring(0, 8)}';
        final d = DiscoveredDevice(
          id: r.device.remoteId.toString(),
          name: name,
          rssi: r.rssi,
          seenAt: DateTime.now(),
        );
        if (mounted) setState(() => _devices[d.id] = d);
      }
    });
  }

  Future<bool> _requestPermissions() async {
    final res = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
    return res.values
        .every((s) => s == PermissionStatus.granted || s == PermissionStatus.limited);
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    setState(() => _status = 'Requesting permissions...');
    if (!await _requestPermissions()) {
      setState(() => _status = 'Permissions denied');
      return;
    }
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      setState(() => _status = 'Please turn on Bluetooth');
      return;
    }
    setState(() {
      _devices.clear();
      _isScanning = true;
      _status = 'Scanning... (10s)';
    });
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
      await FlutterBluePlus.isScanning.where((s) => !s).first;
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = _devices.isEmpty
              ? 'No devices found'
              : '${_devices.length} device(s) found nearby';
        });
      }
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
      _status = '${_devices.length} device(s) found';
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(_status,
                  style: const TextStyle(
                      color: Color(0x80FFFFFF), fontSize: 12)),
            ],
          ),
        ),
        // Scan button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.radar),
              label: Text(
                  _isScanning ? 'Stop scanning' : 'Scan for peers'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7F77DD),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Device list
        Expanded(
          child: _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bluetooth_searching,
                          size: 64, color: Color(0x1AFFFFFF)),
                      const SizedBox(height: 16),
                      Text(
                        _isScanning
                            ? 'Listening...'
                            : 'Tap scan to discover peers',
                        style: const TextStyle(
                            color: Color(0x4DFFFFFF), fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _devices.length,
                  itemBuilder: (ctx, i) {
                    final d = _devices.values.toList()[i];
                    return _DeviceTile(device: d);
                  },
                ),
        ),
        // Stats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0x08FFFFFF),
            border:
                Border(top: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                  label: 'Peers found',
                  value: '${_devices.length}'),
              _Stat(
                  label: 'Strong signal',
                  value:
                      '${_devices.values.where((d) => d.rssi >= -60).length}'),
              const _Stat(label: 'Packets held', value: '0'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Supporting classes ─────────────────────────────────────
class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final DateTime seenAt;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.seenAt,
  });

  String get signalLabel {
    if (rssi >= -60) return 'Strong';
    if (rssi >= -80) return 'Medium';
    return 'Weak';
  }

  Color signalColor(BuildContext context) {
    if (rssi >= -60) return Colors.greenAccent;
    if (rssi >= -80) return Colors.amberAccent;
    return Colors.redAccent;
  }
}

class _DeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: device.signalColor(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(device.id,
                    style: const TextStyle(
                        color: Color(0x59FFFFFF),
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(device.signalLabel,
                  style: TextStyle(
                      color: device.signalColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              Text('${device.rssi} dBm',
                  style: const TextStyle(
                      color: Color(0x59FFFFFF), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF7F77DD),
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(
                color: Color(0x66FFFFFF), fontSize: 11)),
      ],
    );
  }
}
