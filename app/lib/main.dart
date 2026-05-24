// app/lib/main.dart
// Ungie — Radio Layer Stage 1
// BLE discovery — listen before scan, show all results

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
      home: const DiscoveryScreen(),
    );
  }
}

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

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final Map<String, DiscoveredDevice> _devices = {};
  bool _isScanning = false;
  String _status = 'Tap scan to start';
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to scan results immediately on init — before any scan starts
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          final name = result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'Device ${result.device.remoteId.toString().substring(0, 8)}';
          final device = DiscoveredDevice(
            id: result.device.remoteId.toString(),
            name: name,
            rssi: result.rssi,
            seenAt: DateTime.now(),
          );
          if (mounted) {
            setState(() {
              _devices[device.id] = device;
            });
          }
        }
      },
      onError: (e) {
        if (mounted) setState(() => _status = 'Scan error: $e');
      },
    );
  }

  Future<bool> _requestPermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    final denied = results.entries
        .where((e) => e.value.isDenied || e.value.isPermanentlyDenied)
        .map((e) => e.key.toString())
        .toList();

    if (denied.isNotEmpty) {
      if (mounted) {
        setState(() => _status = 'Permission denied — tap scan to retry');
      }
      return false;
    }
    return true;
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() => _status = 'Requesting permissions...');

    final granted = await _requestPermissions();
    if (!granted) return;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
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

      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Scan error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = _devices.isEmpty
              ? 'No devices found — try again'
              : '${_devices.length} device(s) found nearby';
        });
      }
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
      _status = _devices.isEmpty
          ? 'Scan stopped'
          : '${_devices.length} device(s) found';
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ungie Mesh',
              style: TextStyle(
                color: Color(0xFF7F77DD),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              _status,
<<<<<<< Updated upstream
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
=======
              style: const TextStyle(
                color: Color(0x80FFFFFF),
>>>>>>> Stashed changes
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isScanning ? _stopScan : _startScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.radar),
                label: Text(_isScanning ? 'Stop scanning' : 'Scan for peers'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7F77DD),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Color(0x1AFFFFFF),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Listening for nearby devices...'
                              : 'Tap scan to discover peers',
                          style: const TextStyle(
                            color: Color(0x4DFFFFFF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices.values.toList()[index];
                      return _DeviceTile(device: device);
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0x08FFFFFF),
              border: Border(
<<<<<<< Updated upstream
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
=======
                top: BorderSide(color: Color(0x14FFFFFF)),
>>>>>>> Stashed changes
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Peers found', value: '${_devices.length}'),
                _Stat(
                  label: 'Strong signal',
                  value:
                      '${_devices.values.where((d) => d.rssi >= -60).length}',
<<<<<<< Updated upstream
                ),
                _Stat(
                  label: 'Packets held',
                  value: '0', // will wire to Node in Stage 2
=======
>>>>>>> Stashed changes
                ),
                const _Stat(label: 'Packets held', value: '0'),
              ],
            ),
          ),
        ],
      ),
    );
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
<<<<<<< Updated upstream
        border: Border.all(color: Colors.white.withOpacity(0.08)),
=======
        border: Border.all(color: const Color(0x14FFFFFF)),
>>>>>>> Stashed changes
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.signalColor(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  device.id,
                  style: const TextStyle(
                    color: Color(0x59FFFFFF),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                device.signalLabel,
                style: TextStyle(
                  color: device.signalColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${device.rssi} dBm',
                style: const TextStyle(
                  color: Color(0x59FFFFFF),
                  fontSize: 11,
                ),
              ),
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
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF7F77DD),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
<<<<<<< Updated upstream
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
=======
          style: const TextStyle(
            color: Color(0x66FFFFFF),
            fontSize: 11,
          ),
>>>>>>> Stashed changes
        ),
      ],
    );
  }
}
