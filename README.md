# Ungie

A decentralized peer-to-peer mesh network built for smartphones. Ungie enables devices to discover each other, share data, and synchronize without any central server, internet connection, or coordinator. Every phone is both a client and a relay.

---

## The Core Idea

Every network you have ever used depends on a central server. Remove the server and everything stops. Ungie throws that model away.

In the Ungie mesh, phones discover each other over Bluetooth Low Energy (BLE) and Wi-Fi Direct. When two phones meet, they compare what they know and share what the other lacks. Data ripples outward hop by hop until every device in range has it. No server. No router. No coordinator.

This is called a **gossip protocol** — the same mechanism used by distributed databases like Cassandra and content networks like IPFS, now running on commodity smartphones.

---

## Architecture

Ungie is built in four layers, each one sitting on top of the last.

### Layer 1 — Transport
How two phones notice each other before any data is exchanged.

- **BLE Advertising**: Each phone broadcasts a 31-byte packet every ~200ms like a lighthouse pulse. Any nearby phone that is scanning can hear it without forming a connection.
- **Wi-Fi Direct**: Once two phones know each other exists via BLE, they form a direct high-speed connection without a router. BLE is the doorbell; Wi-Fi Direct is the room they meet in.

### Layer 2 — Data
How information is structured, addressed, and compared efficiently.

- **Content Addressing**: Every packet is named after a SHA-256 fingerprint of its content. If the data changes, the name changes. Two phones can compare fingerprints instead of full files.
- **Anti-Entropy Sync**: When two nodes meet, they compare their sets of packet IDs. Each pushes what the other lacks. The Merkle-style ID comparison finds differences in O(log n) steps without transferring full data.
- **Priority Queue**: Small packets (text answers) travel before large ones (images). When bandwidth is scarce and the radio window is brief, critical data gets through first.
- **TTL Hop Count**: Every packet carries a hop counter. Each time it crosses to a new phone the count decrements. When it reaches zero the packet is blocked. This prevents data from circling the mesh forever and draining batteries.

### Layer 3 — Security
How the mesh knows who belongs and keeps traffic private.

- **HMAC Membership Tokens**: The teacher generates a cryptographic group secret. Every enrolled device derives a unique token from that secret using HMAC-SHA256. When two phones meet, they exchange challenge-response proofs. A valid response proves the device holds the group secret without revealing the secret itself. A stranger's phone fails immediately. The verifying phone never learns which member it is talking to.
- **Packet Obfuscation**: Mesh BLE advertisements are crafted to mimic Apple's Nearby protocol format byte-for-byte. To any passive BLE scanner, Ungie traffic is indistinguishable from background iPhone/MacBook Bluetooth noise. Only a device with the correct group secret can decode the hidden mesh payload.
- **Replay Attack Prevention**: Every challenge is a cryptographically random nonce. Recording a valid handshake and replaying it later fails because the challenge will always be different.
- **Constant-Time Verification**: Token comparison uses constant-time equality to prevent timing attacks — attackers cannot guess tokens byte by byte by measuring how long verification takes.
- **Handshake Gating**: The `HandshakeEngine` runs the full challenge-response proof before allowing any gossip to flow. Zero data leaks to a stranger before rejection. The handshake completes within 100ms — fast enough for a BLE radio window.

### Layer 4 — Application
How the gossip protocol coordinates across many devices over time.

- **Scheduler**: A heartbeat timer that wakes nodes, pairs them randomly, runs the anti-entropy sync, and puts them back to sleep. The global behaviour — full convergence — emerges from this one simple local rule.
- **Sleep/Wake Duty Cycle**: Phones are awake for a fraction of each cycle. This reduces battery drain while guaranteeing that any two nearby phones will overlap in their wake windows at least once per cycle.
- **Collision Handling**: When many nodes sync simultaneously, the scheduler detects and skips conflicting pairs to prevent race conditions.

---

## Project Structure

```
ungie/
├── lib/                        # Core mesh logic (pure Dart, no Flutter)
│   ├── packet.dart             # The atom of the mesh
│   ├── node.dart               # A simulated phone
│   ├── sync.dart               # The gossip engine (anti-entropy sync)
│   ├── scheduler.dart          # Sleep/wake heartbeat scheduler
│   ├── stress_scheduler.dart   # High-pressure 30-node scheduler
│   ├── metrics.dart            # Mesh health tracking
│   ├── security.dart           # HMAC membership tokens + challenge-response
│   ├── obfuscation.dart        # BLE packet disguised as Apple Nearby traffic
│   └── handshake.dart          # Security gates gossip — the mesh gatekeeper
│
├── bin/
│   └── ungie.dart              # CLI simulation runner
│
├── test/
│   ├── ttl_test.dart           # Protocol rule tests (4 tests)
│   ├── security_test.dart      # Membership token tests (6 tests)
│   ├── obfuscation_test.dart   # Packet obfuscation tests (7 tests)
│   └── handshake_test.dart     # Handshake gating tests (7 tests)
│
├── simulations/                # Simulation outputs and notes
│
└── app/                        # Flutter mobile app
    ├── lib/
    │   ├── main.dart           # App shell + BLE discovery screen
    │   └── mesh_screen.dart    # Live gossip visualizer
    └── android/                # Android platform code + permissions
```

---

## The Simulation Layer

The core protocol is proven entirely in pure Dart before touching any radio hardware. This is intentional — gossip logic does not depend on the transport layer. When real phones replace simulated nodes, the sync engine does not change at all.

### Running the simulation

```bash
dart run
```

This runs a 30-node stress test. 30 simulated phones start with only Node A holding data. Random sleep/wake cycles activate. The gossip protocol spreads data across all 30 nodes through random pairings alone.

**Typical output:**
```
╔══════════════════════════════════╗
║       UNGIE — Stress Test        ║
║       Mesh Simulation v0.3       ║
╚══════════════════════════════════╝

  [████████████████████] 100% (30/30 nodes synced)

╔══════════════════════════════════════╗
║         MESH HEALTH REPORT           ║
╚══════════════════════════════════════╝

  Nodes:              30
  Packets per origin: 3
  Cycles elapsed:     100

  Convergence
  ✓ Full sync at cycle 19

  Sync activity
  Total syncs:      1032
  Redundant syncs:  981 (95%)
  TTL blocks:       66
  Collision events: 0
```

**What the numbers mean:**

- **Full sync at cycle 19** — The mesh converged in under a fifth of the available time. After cycle 19 it is continuously verifying what it already knows.
- **95% redundant syncs** — After convergence, most meetings are between nodes that already agree. This is healthy — it is the mesh continuously checking, not just assuming.
- **66 TTL blocks** — 66 packets hit zero hops and were stopped. The infinite-loop prevention worked correctly under pressure.
- **0 collision events** — No node was pulled into two simultaneous syncs across the entire run.

### Running the tests

```bash
dart test
```

24 tests across four test files covering every protocol guarantee:

**TTL tests (4)** — packet blocked at zero hops, reaches B but not C at TTL=1, travels full chain at TTL=3, plus the framework test.

**Security tests (6):**
- Valid member passes verification
- Stranger with wrong secret fails
- Token derivation is deterministic
- Different devices get different tokens (anonymity preserved)
- Every challenge is unique (replay attack prevention)
- Token does not expose the group secret

**Obfuscation tests (7):**
- Encoded advertisement is exactly 31 bytes
- Looks like Apple manufacturer data to passive scanners
- Valid member can decode their own advertisement
- TTL and priority survive encode/decode round trip
- Stranger with different secret cannot decode
- Different mesh ID cannot decode
- Timestamp survives encode/decode

**Handshake tests (7):**
- Valid members handshake and sync successfully
- Gossip flows after successful handshake
- Stranger is rejected — no gossip flows
- Zero data leaks to stranger before rejection
- Handshake completes within 100ms
- Multiple sequential handshakes all succeed
- Handshake outcome is clearly described

---

## The Security Layer

### How membership works

```
Teacher                    Student Device
   |                            |
   |-- generates group secret ->|
   |                            |-- derives token from secret
   |                            |
   |        Two devices meet    |
   |                            |
Device A                   Device B
   |-- sends random challenge ->|
   |<-- HMAC response ----------|
   |-- verifies response ------>|
   |   (pass = member,          |
   |    fail = stranger)        |
```

The group secret never travels over the radio. Only challenge-response proofs do. A passive observer who captures every byte of the handshake cannot reconstruct the secret or impersonate a member.

### How the handshake gates gossip

```
Device A meets Device B via BLE
            ↓
A generates a random challenge
            ↓
B responds with HMAC(secret, challenge)
            ↓
A verifies the response
            ↓
PASS → gossip begins     FAIL → connection dropped silently
                                 zero packets transferred
```

### How obfuscation works

A real Apple Nearby BLE advertisement looks like:

```
[0x4C 0x00] [0x10] [length] [status bytes...]
  Apple ID   Type   Len      Payload
```

An Ungie mesh advertisement looks identical to a passive scanner:

```
[0x4C 0x00] [0x10] [0x1B] [0xA7] [ttl|priority] [mesh fingerprint 4B]
  Apple ID   Type   Len   Magic   TTL/Priority    Group fingerprint

[payload hash 16B] [timestamp 4B] [HMAC noise 3B]
  Data fingerprint   When sent     Looks like Apple continuation data
```

The magic byte `0xA7` is hidden inside what looks like an Apple status flag. The mesh fingerprint looks like Apple device state bytes. The payload hash and timestamp are indistinguishable from Apple continuation data. Only a device with the correct group secret can identify and decode the advertisement.

---

## The Flutter App

The mobile app runs on Android and visualises the mesh in real time.

### Screens

**Discover tab** — Scans for nearby Bluetooth devices using BLE. Shows each device's MAC address and signal strength (dBm). Requires Bluetooth and Location permissions on Android, and device-level Location to be enabled (Android mandates this for all BLE scanning).

**Mesh tab** — Runs the live gossip engine on 5 simulated nodes (A–E). Shows:
- Node health bars — packet count and awake/sleep state per node
- Live gossip log — every sync event, push, TTL block, and sleep/wake transition in real time
- Cycle counter, total packets, and awake node count
- Packet injection — tap to create a new packet at a random awake node and watch it spread

The `MeshController` lives in the app shell and persists across tab switches. Starting the mesh on the Mesh tab and switching to Discover does not pause or reset the gossip engine.

### Building for Android

```bash
cd app
flutter pub get
flutter run -d <device_id>
```

Requirements:
- Flutter SDK at `C:\flutter`
- Android NDK 27.0.12077973
- `minSdk = 21` (Android 5.0+)
- Device-level Location enabled for BLE scanning

### Android permissions required

```
BLUETOOTH_SCAN
BLUETOOTH_CONNECT
BLUETOOTH_ADVERTISE
ACCESS_FINE_LOCATION
ACCESS_COARSE_LOCATION
ACCESS_WIFI_STATE
CHANGE_WIFI_STATE
NEARBY_WIFI_DEVICES
```

---

## Development Roadmap

### Completed

| Milestone | Status |
|---|---|
| Hello World mesh — A reaches C through silent bridge B | ✅ |
| TTL expiry — packets blocked at zero hops | ✅ |
| Priority queue — text packets before image packets | ✅ |
| Self-running scheduler — mesh converges autonomously | ✅ |
| Sleep/Wake resilience — mesh survives nodes dropping in and out | ✅ |
| 30-node stress test — full convergence, zero collisions | ✅ |
| BLE discovery — real devices detected on Android | ✅ |
| Live mesh visualizer — gossip visible in real time on device | ✅ |
| Persistent mesh controller — gossip runs across tab switches | ✅ |
| HMAC membership tokens — 6 security guarantees tested | ✅ |
| Packet obfuscation — Apple Nearby mimicry, 7 guarantees tested | ✅ |
| Handshake engine — security gates gossip, 7 guarantees tested | ✅ |

### In Progress

| Milestone | Status |
|---|---|
| Stage 2 radio — two Ungie instances handshake over real BLE | ⬜ |
| Real gossip over Nearby Connections API | ⬜ |

### Planned

| Milestone | Status |
|---|---|
| Wire obfuscation into live BLE advertisement encoding | ⬜ |
| iOS build via Codemagic cloud CI | ⬜ |
| Peer-to-peer sync screen | ⬜ |

---

## Key Concepts

**Anti-entropy** — A sync strategy where two nodes compare what they have and push the difference. The global state converges to consistency without any coordinator.

**Content addressing** — Naming data by its cryptographic fingerprint. The same content always produces the same name. Different content always produces a different name.

**TTL (Time to Live)** — A hop counter attached to every packet. Prevents data from circling the mesh indefinitely. Each forward decrements the counter; zero means stop.

**Gossip protocol** — An epidemic-style information spreading strategy. Each node infects a random neighbour each cycle. The infection (data) spreads exponentially until everyone has it.

**Duty cycle** — The fraction of time a node spends awake with its radio on. Lower duty cycle means longer battery life but slower convergence. The scheduler finds the minimum duty cycle that still guarantees overlap between nearby nodes.

**HMAC (Hash-based Message Authentication Code)** — A cryptographic function that proves knowledge of a secret key without revealing it. Used here for membership tokens and challenge-response proofs.

**Replay attack** — An attack where a valid recorded message is reused later to impersonate the original sender. Prevented in Ungie by using a unique random challenge every handshake.

**Constant-time comparison** — A comparison method that takes the same amount of time regardless of where the first difference occurs. Prevents timing attacks where an attacker guesses a secret byte by byte based on response time.

**Packet obfuscation** — Disguising mesh network traffic as a known harmless protocol. Prevents a passive observer from identifying that a mesh network is operating.

**Handshake gating** — The requirement that a security proof must succeed before any data is exchanged. Ensures strangers receive zero information even from a failed connection attempt.

---

## Dependencies

### Core (`pubspec.yaml`)
- `crypto: ^3.0.3` — SHA-256 hashing and HMAC for content addressing and security

### App (`app/pubspec.yaml`)
- `flutter_blue_plus: ^2.2.0` — BLE scanning and advertising
- `nearby_connections: ^4.1.0` — Google Nearby Connections (BLE + Wi-Fi Direct peer handshake)
- `permission_handler: ^11.3.1` — Runtime permissions for Android 12+

---

## Design Principles

**Prove the logic before touching the hardware.** The entire gossip protocol, TTL system, priority queue, sleep/wake scheduler, 30-node stress test, security layer, obfuscation layer, and handshake engine all run in pure Dart with zero radio involvement. Only after the logic is proven does it get a radio layer underneath it.

**The transport layer is a plug.** The sync engine (`sync.dart`) takes two `Node` objects and syncs them. It does not care whether those nodes represent simulated objects in memory or real phones connected over Wi-Fi Direct. Swapping the transport does not change the protocol.

**Emergence over orchestration.** No component in Ungie is told to "spread data to all nodes." Each node is only told: "when you meet a neighbour, share what they lack." Full mesh convergence emerges from that single local rule applied repeatedly across random pairings.

**Security through obscurity is not enough — but obscurity still helps.** The obfuscation layer is not the primary security mechanism. Membership tokens provide cryptographic guarantees. Obfuscation adds a second layer that prevents passive discovery of the mesh's existence in the first place.

**Gate first, sync second.** No data flows before identity is proven. The handshake engine enforces this at the architectural level — gossip and security are not separate concerns that can be accidentally wired in the wrong order.

---

*Built by GOLDN — IT student, mesh network builder.*
