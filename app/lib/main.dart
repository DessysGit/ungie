// app/lib/main.dart
// Ungie — Radio Layer Stage 1
// BLE discovery screen: scans for nearby mesh devices

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
  final int rssi; // signal strength — closer = stronger = higher number
  final DateTime seenAt;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.seenAt,
  });

  // Signal strength as a readable label
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
  String _status = 'Ready to scan';
  StreamSubscription? _scanSubscription;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _checkBluetooth();
  }

  Future<void> _checkBluetooth() async {
    _stateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _status = state == BluetoothAdapterState.on
            ? 'Bluetooth ready'
            : 'Bluetooth is ${state.name} — please enable it';
      });
    });
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _devices.clear();
      _isScanning = true;
      _status = 'Scanning for nearby mesh devices...';
    });

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final device = DiscoveredDevice(
          id: result.device.remoteId.toString(),
          name: result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'Unknown device',
          rssi: result.rssi,
          seenAt: DateTime.now(),
        );
        setState(() {
          _devices[device.id] = device;
        });
      }
    });

    // Scan for 10 seconds
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    await Future.delayed(const Duration(seconds: 10));
    _stopScan();
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
      _status = _devices.isEmpty
          ? 'No devices found. Try again.'
          : '${_devices.length} device(s) found nearby';
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
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
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Scan button
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

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Listening for nearby devices...'
                              : 'Tap scan to discover peers',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
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

          // Mesh stats footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
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
                ),
                _Stat(
                  label: 'Packets held',
                  value: '0', // will wire to Node in Stage 2
                ),
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
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Signal indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.signalColor(context),
            ),
          ),
          const SizedBox(width: 12),

          // Device info
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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Signal strength
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
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
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
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ],
    );
  }
}
