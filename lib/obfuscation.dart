// lib/obfuscation.dart
// Packet obfuscation for the Ungie mesh.
// Disguises mesh BLE advertisements as Apple Nearby protocol noise.
// A passive scanner sees standard background Bluetooth traffic.
// Only Ungie devices know the real encoding.

import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// ── BLE advertisement limits ───────────────────────────────
// BLE advertising payload: 31 bytes total
// Manufacturer data overhead: 4 bytes (company ID + type + length + subtype)
// Available for mesh payload: 27 bytes
const int _bleMaxPayload = 27;

// Apple company ID (little-endian) — makes packet look like Apple device
const int _appleCompanyIdLow = 0x4C;
const int _appleCompanyIdHigh = 0x00;

// Apple Nearby Action type
const int _appleNearbyType = 0x10;

// Ungie magic byte — hidden inside the status field
// Looks like a valid Apple status flag to passive scanners
const int _ungieMagic = 0xA7;

class ObfuscatedPacket {
  final String meshId;     // which mesh this belongs to
  final String payloadHash; // SHA-256 fingerprint of the data
  final int ttl;           // hop count remaining
  final int priority;      // 0 = high (text), 1 = low (image)
  final DateTime timestamp;

  ObfuscatedPacket({
    required this.meshId,
    required this.payloadHash,
    required this.ttl,
    required this.priority,
    required this.timestamp,
  });
}

class MeshObfuscator {
  final String meshId;
  final String groupSecret;

  MeshObfuscator({required this.meshId, required this.groupSecret});

  // Encode a mesh packet as a fake Apple Nearby advertisement
  // Returns 31 bytes that look like legitimate BLE manufacturer data
  Uint8List encode(ObfuscatedPacket packet) {
    final buffer = Uint8List(31);
    int offset = 0;

    // Apple company ID (little-endian) — 2 bytes
    buffer[offset++] = _appleCompanyIdLow;
    buffer[offset++] = _appleCompanyIdHigh;

    // Apple Nearby type — 1 byte
    buffer[offset++] = _appleNearbyType;

    // Length of remaining data — 1 byte
    buffer[offset++] = 27;

    // Ungie magic byte disguised as Apple status — 1 byte
    buffer[offset++] = _ungieMagic;

    // TTL encoded in high nibble, priority in low nibble — 1 byte
    buffer[offset++] = ((packet.ttl & 0x0F) << 4) | (packet.priority & 0x0F);

    // Mesh ID fingerprint — first 4 bytes of HMAC
    final meshFingerprint = _meshFingerprint(packet.meshId);
    for (int i = 0; i < 4; i++) {
      buffer[offset++] = meshFingerprint[i];
    }

    // Payload hash — first 16 bytes of SHA-256
    final hashBytes = _hexToBytes(packet.payloadHash);
    for (int i = 0; i < 16 && i < hashBytes.length; i++) {
      buffer[offset++] = hashBytes[i];
    }

    // Timestamp low bytes — 4 bytes (seconds since epoch, low 4 bytes)
    final ts = packet.timestamp.millisecondsSinceEpoch ~/ 1000;
    buffer[offset++] = (ts >> 24) & 0xFF;
    buffer[offset++] = (ts >> 16) & 0xFF;
    buffer[offset++] = (ts >> 8) & 0xFF;
    buffer[offset++] = ts & 0xFF;

    // Remaining bytes filled with HMAC-derived noise
    // Looks like valid Apple continuation data to passive scanners
    final noise = _generateNoise(packet, offset);
    while (offset < 31) {
      buffer[offset] = noise[offset % noise.length];
      offset++;
    }

    return buffer;
  }

  // Decode a BLE advertisement back into a mesh packet
  // Returns null if this is not a valid Ungie advertisement
  ObfuscatedPacket? decode(Uint8List advertisement) {
    if (advertisement.length < 31) return null;

    // Check Apple company ID
    if (advertisement[0] != _appleCompanyIdLow) return null;
    if (advertisement[1] != _appleCompanyIdHigh) return null;

    // Check Apple Nearby type
    if (advertisement[2] != _appleNearbyType) return null;

    // Check Ungie magic byte
    if (advertisement[4] != _ungieMagic) return null;

    // Extract TTL and priority
    final ttlAndPriority = advertisement[5];
    final ttl = (ttlAndPriority >> 4) & 0x0F;
    final priority = ttlAndPriority & 0x0F;

    // Extract and verify mesh fingerprint
    final meshFingerprint = _meshFingerprint(meshId);
    for (int i = 0; i < 4; i++) {
      if (advertisement[6 + i] != meshFingerprint[i]) return null;
    }

    // Extract payload hash
    final hashBytes = advertisement.sublist(10, 26);
    final payloadHash = hashBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // Extract timestamp
    final ts = (advertisement[26] << 24) |
        (advertisement[27] << 16) |
        (advertisement[28] << 8) |
        advertisement[29];
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(ts * 1000);

    return ObfuscatedPacket(
      meshId: meshId,
      payloadHash: payloadHash,
      ttl: ttl,
      priority: priority,
      timestamp: timestamp,
    );
  }

  // Generate HMAC-derived noise bytes
  List<int> _generateNoise(ObfuscatedPacket packet, int startOffset) {
    final key = utf8.encode(groupSecret);
    final message = utf8.encode('noise:${packet.payloadHash}:${packet.timestamp}');
    final hmac = Hmac(sha256, key);
    return hmac.convert(message).bytes;
  }

  // First 4 bytes of HMAC of mesh ID — group fingerprint
  List<int> _meshFingerprint(String id) {
    final key = utf8.encode(groupSecret);
    final message = utf8.encode('mesh:$id');
    final hmac = Hmac(sha256, key);
    return hmac.convert(message).bytes.sublist(0, 4);
  }

  // Convert hex string to bytes
  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length - 1; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}