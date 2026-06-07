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

- **Zero-Knowledge Membership**: The teacher generates a cryptographic class secret. Every enrolled device receives a token derived from that secret. When two phones meet, one can prove its token is valid without revealing the token itself. A stranger's phone with no token fails immediately. The verifying phone never learns which student it is talking to.
- **Packet Obfuscation**: Mesh advertisements are crafted to mimic standard BLE service profiles (AirPods, fitness trackers). To a passive scanner, Ungie traffic looks like background Bluetooth noise.

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
│   └── metrics.dart            # Mesh health tracking
│
├── bin/
│   └── ungie.dart              # CLI simulation runner
│
├── test/
│   └── ttl_test.dart           # Protocol rule tests
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

Tests verify the three core TTL rules:
- A packet with TTL=0 is never forwarded
- A packet with TTL=1 reaches the next node but dies there
- A packet with TTL=3 travels the full A→B→C chain

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

### In Progress

| Milestone | Status |
|---|---|
| Stage 2 radio — two Ungie instances handshake and sync | ⬜ |
| Real gossip over Nearby Connections API | ⬜ |

### Planned

| Milestone | Status |
|---|---|
| ZK membership tokens — cryptographic class identity | ⬜ |
| Packet obfuscation — mesh traffic disguised as BLE noise | ⬜ |
| iOS build via Codemagic cloud CI | ⬜ |
| Peer-to-peer sync screen | ⬜ |

---

## Key Concepts

**Anti-entropy** — A sync strategy where two nodes compare what they have and push the difference. The global state converges to consistency without any coordinator.

**Content addressing** — Naming data by its cryptographic fingerprint. The same content always produces the same name. Different content always produces a different name.

**TTL (Time to Live)** — A hop counter attached to every packet. Prevents data from circling the mesh indefinitely. Each forward decrements the counter; zero means stop.

**Gossip protocol** — An epidemic-style information spreading strategy. Each node infects a random neighbour each cycle. The infection (data) spreads exponentially until everyone has it.

**Duty cycle** — The fraction of time a node spends awake with its radio on. Lower duty cycle means longer battery life but slower convergence. The scheduler finds the minimum duty cycle that still guarantees overlap between nearby nodes.

**Zero-knowledge proof** — A cryptographic method for proving you know a secret without revealing the secret. Used here so devices can prove class membership without revealing their identity.

---

## Dependencies

### Core (`pubspec.yaml`)
- `crypto: ^3.0.3` — SHA-256 hashing for content addressing

### App (`app/pubspec.yaml`)
- `flutter_blue_plus: ^2.2.0` — BLE scanning and advertising
- `nearby_connections: ^4.1.0` — Google Nearby Connections (BLE + Wi-Fi Direct peer handshake)
- `permission_handler: ^11.3.1` — Runtime permissions for Android 12+

---

## Design Principles

**Prove the logic before touching the hardware.** The entire gossip protocol, TTL system, priority queue, sleep/wake scheduler, and 30-node stress test run in pure Dart with zero radio involvement. Only after the logic is proven does it get a radio layer underneath it.

**The transport layer is a plug.** The sync engine (`sync.dart`) takes two `Node` objects and syncs them. It does not care whether those nodes represent simulated objects in memory or real phones connected over Wi-Fi Direct. Swapping the transport does not change the protocol.

**Emergence over orchestration.** No component in Ungie is told to "spread data to all nodes." Each node is only told: "when you meet a neighbour, share what they lack." Full mesh convergence emerges from that single local rule applied repeatedly across random pairings.

---

*Built by GOLDN — IT student, mesh network builder.*
