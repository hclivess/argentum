Argentum (ARG)
==============

Argentum is an experimental, open-source digital currency that enables instant
peer-to-peer payments with no central authority. It is a fork of [Bitcoin Core](https://github.com/bitcoin/bitcoin)
and supports six mining algorithms with merged-mining (AuxPoW) on Scrypt and SHA256D.

- Website: http://www.argentum.io
- Releases / tags: https://github.com/argentumproject/argentum/tags

Specifications
--------------

| | |
|---|---|
| Block time | 45 seconds |
| Block reward | 3 ARG |
| Max block size | 10 MB |
| Total supply | 64,000,000 ARG |
| Mining algorithms | Scrypt, SHA256D, Lyra2RE2, Myr-Groestl, Argon2d, Yescrypt |
| Merged mining (AuxPoW) | Scrypt, SHA256D |

License
-------

Argentum is released under the terms of the MIT license. See [COPYING](COPYING)
or https://opensource.org/licenses/MIT.

Building from source
--------------------

Generic build instructions for Windows, macOS and Unix are in the [doc](doc) directory.

This tree builds with a modern toolchain (GCC 13 / Clang, OpenSSL 3, Boost 1.83,
BerkeleyDB 5.x, C++17). Quick start on Linux:

```sh
./autogen.sh
./configure --with-incompatible-bdb --without-gui --enable-tests
make -j"$(nproc)"
```

See [MODERNIZATION.md](doc/MODERNIZATION.md) for the toolchain notes.

Development
-----------

The `master` branch is built and tested but is not guaranteed to be stable;
tagged releases mark official stable versions. The contribution workflow is
described in [CONTRIBUTING.md](CONTRIBUTING.md).

Mining
------

Select the algorithm in `argentum.conf` (or pass `-algo=`):

```
algo=sha256d
algo=scrypt
algo=lyra2re2     # or: lyra2
algo=groestl
algo=argon2d      # or: argon
algo=yescrypt
```

### Mining software

| Algorithm | Software |
|---|---|
| Lyra2RE2 / Myr-Groestl (GPU, AMD) | [sgminer (nicehash)](https://github.com/nicehash/sgminer/releases), [sgminer (tpruvot)](https://github.com/tpruvot/sgminer/releases) |
| Lyra2RE2 / Myr-Groestl (GPU, NVIDIA) | [ccminer (tpruvot)](https://github.com/tpruvot/ccminer/releases) |
| Argon2d (CPU) | [cpuminer-opt](https://github.com/JayDDee/cpuminer-opt/releases), [unitus-cpuminer](https://github.com/unitusdev/unitus-cpuminer) |
| Yescrypt (CPU/GPU) | [cpuminer-yescrypt](https://github.com/koto-dev/cpuminer-yescrypt/releases), [unitus-cpuminer](https://github.com/unitusdev/unitus-cpuminer), [sgminer (nicehash)](https://github.com/nicehash/sgminer/releases) |

Merge-mining with Unitus (UIS) on Argon2d: see the
[EasyMine guide](https://pimovietc.github.io/EasyMineGuides/Argentum/).

P2Pool for Argentum: https://github.com/argentumproject/p2pool-argentum/

Pools
-----

Pools known to support Argentum payouts (verify before use — availability changes):

- [prohashing.com](https://prohashing.com) — Scrypt
- [zpool.ca](http://www.zpool.ca/) — all but Argon2d
- [zergpool.com](http://zergpool.com/) — Scrypt, Lyra2RE2
- [blazepool.com](http://blazepool.com) — Myr-Groestl, Yescrypt, Scrypt, Lyra2RE2
- [evil.ru](http://www.evil.ru/site/mining) — Yescrypt

Scrypt merge-mining pool (no direct ARG payout): [litecoinpool.org](https://litecoinpool.org)

Trading
-------

- [Bisq](http://bitsquare.io) — decentralized exchange
- [SimpleSwap](https://www.simpleswap.io/)

> Exchanges come and go; always confirm a venue is operating before sending funds.

Changelog
---------

### Toolchain modernization
- Builds on modern toolchains (GCC 13 / OpenSSL 3 / Boost 1.83 / C++17). See [MODERNIZATION.md](doc/MODERNIZATION.md).

### 4.14.4.1
- `LOW_S` and `NULLFAIL` are now mandatory.

### 4.14.4
- Faster initial blockchain download.

### 4.14.3
- Adds 4 mining algorithms (activated at block 2,977,000): Lyra2RE2 (GPU),
  Myr-Groestl (GPU/ASIC), Argon2d (CPU), Yescrypt (CPU/GPU).

### 4.14.2
- BIP112 (CheckSequenceVerify) soft fork
- BIP146 hard fork at block 2,977,000 (around March 13, 2018)
- Signature validation via libsecp256k1
- Direct headers announcement (BIP130)
- Automatic Tor hidden services
- ZMQ notifications
- BIP9 soft-fork deployment
- Linux ARM builds
- Compact block support (BIP152)
- Hierarchical Deterministic (HD) wallets
- Faster client load time
