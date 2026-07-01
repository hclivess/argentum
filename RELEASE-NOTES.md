# Argentum 4.14.5.1

A modernization release: Argentum now **builds and runs on current toolchains** and
ships **multi-platform binaries** (Linux and Windows), including the **Qt5 wallet GUI**.
No consensus rules were changed.

## What's new in 4.14.5.1

### Build & toolchain modernization
The tree previously required a ~2017 stack (OpenSSL 1.0.x, Boost ~1.58, GCC 5, C++11)
and would not compile on a modern system. It now builds cleanly on **GCC 13 / Clang,
OpenSSL 3.0, Boost 1.83+, BerkeleyDB 5.x, C++14**. Notable fixes:
- Rewrote `CBigNum` (`bignum.h`) to wrap a heap `BIGNUM*` — OpenSSL 1.1+ made `BIGNUM`
  opaque and removed `BN_init()`. Arithmetic is byte-for-byte unchanged (it feeds the
  multi-algo geometric-mean chainwork calc).
- Boost 1.74+: `const`-qualified `multi_index` comparators; `boost::placeholders` for
  `_1/_2`; `boost::signals2` disconnect via saved `connection` objects; modern
  `boost::filesystem` (`is_absolute`, `copy_options`, `path().filename()`).
- Added missing `<list>/<functional>/<array>/<deque>/<stdexcept>` includes (libc++/mingw).
- Replaced C++17-removed `std::random_shuffle`; version-guarded the pre-1.1 OpenSSL
  threading callbacks; UPnP `UPNP_GetValidIGD` for miniupnpc API ≥ 18.

### Qt5 wallet GUI
- Ported the GUI from Qt4 to **Qt5** (`argentum-qt`).
- Added a **CMake build** for the GUI so it builds on MSYS2/Windows.

### Multi-platform releases (CI)
- A GitHub Actions pipeline builds and publishes **Linux** and **Windows** `argentumd`,
  `argentum-cli`, `argentum-tx`, and the **Qt5 GUI** (self-contained, DLLs/plugins
  bundled). macOS is best-effort (subject to GitHub Intel-runner availability).

### Networking
- Baked in three new fixed seed nodes: `51.83.11.113`, `85.15.179.171`, `91.206.16.214`.

### Localization
- **Czech (cs)** fully re-localized from Bitcoin to Argentum, with correct Latin
  neuter (`-um`) declension and apposition.

### Security / hardening (non-consensus)
- Added `LOCK(cs_main)` to the `chaindynamics` and `getblockspacing` RPCs (they walked
  the block index unlocked — a data race / potential use-after-free vs a reorg).
- Removed leftover developer debug-logging.

### Tests
- Restored the regtest genesis block (its creation was commented out upstream) and
  refreshed stale test vectors — **54 / 56** unit suites pass.

### Credits
- Modernized build and multi-platform packaging by **hclivess**.

## Downloads
| File | Contents |
|---|---|
| `argentum-linux-x86_64.tar.gz` | Linux `argentumd` + `argentum-cli` + `argentum-tx` + `argentum-qt` (GUI) |
| `argentum-windows-x86_64.zip` | Windows `argentumd` + `argentum-cli` + `argentum-tx` |
| `argentum-qt-windows-x86_64.zip` | Windows Qt5 wallet GUI (self-contained) |
| `SHA256SUMS.txt` | checksums |

## Known issues
- macOS binaries are best-effort (GitHub Intel-runner availability).
- Two unit suites (`auxpow_tests`, `miner_tests`) require a consensus change and are
  intentionally left failing (no hardfork).

---

# Previous releases

## 4.14.4.1
- `LOW_S` and `NULLFAIL` are now mandatory.

## 4.14.4
- Speed up Initial Blockchain Download.

## 4.14.3
- Adds 4 new mining algorithms (activates at block 2,977,000): Lyra2RE2 (GPU),
  Myr-Groestl (GPU/ASIC), Argon2d (CPU), Yescrypt (CPU/GPU).

## 4.14.2
- BIP112 (CheckSequenceVerify) soft fork
- BIP146 hard fork at block 2,977,000 (≈ March 13, 2018)
- Signature validation via libsecp256k1
- Direct headers announcement (BIP130)
- Automatic Tor hidden services
- ZMQ notifications
- BIP9 soft-fork deployment
- Linux ARM builds
- Compact block support (BIP152)
- Hierarchical Deterministic (HD) wallets
- Substantially faster client load time
