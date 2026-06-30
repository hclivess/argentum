# Argentum 4.14.5 — Toolchain Modernization

Makes the tree (a Bitcoin Core ~0.14 fork) **compile and run on a modern toolchain**
without changing consensus rules.

## Builds against

GCC 13 / C++17 · OpenSSL 3.0 · Boost 1.83 · BerkeleyDB 5.3 (`--with-incompatible-bdb`)
· libevent 2.1 · autoconf 2.71 / automake 1.16.

```
./autogen.sh
./configure --with-incompatible-bdb --without-gui --enable-tests --disable-bench
make -j$(nproc)
```
Produces `argentumd`, `argentum-cli`, `argentum-tx`, `test_argentum` with 0 errors.

## Changes (none alter consensus rules)

- **`src/bignum.h`** — OpenSSL 1.1+ made `BIGNUM` opaque and removed `BN_init()`, so the
  old `class CBigNum : public BIGNUM` could not compile. Rewrote `CBigNum` to wrap a heap
  `BIGNUM*`; every `BN_*` call is preserved, so results are byte-for-byte identical (this
  participates in `chain.cpp`'s geometric-mean chain-work calc — validated unchanged).
- **Missing std includes** — `<array>` (net_processing), `<deque>` (httpserver,
  cuckoocache_tests), `<stdexcept>` (lockedpool); modern libstdc++ no longer pulls these in.
- **Boost 1.74+ multi_index** — comparators are invoked through a `const` object, so
  `operator()` (and `UseDescendantScore`) gained `const` in `txmempool.h` / `miner.h`.
- **Boost `bind` placeholders** — `_1/_2` moved to `boost::placeholders`; added the using
  directive in `validation.cpp` / `validationinterface.cpp`.
- **Boost.Signals2** — can no longer `disconnect()` by function pointer; `init.cpp` now
  keeps the `connection` objects and disconnects through them.
- **`util.cpp`** — version-guarded the pre-1.1 OpenSSL thread-locking callbacks
  (`#if OPENSSL_VERSION_NUMBER < 0x10100000L`); OpenSSL ≥1.1 is internally thread-safe.

## Hardening (non-consensus)

- Added `LOCK(cs_main)` to the `chaindynamics` (`rpc/misc.cpp`) and `getblockspacing`
  (`rpc/blockchain.cpp`) RPCs, which walked `chainActive` / the block index unlocked
  (data-race / use-after-free vs a concurrent reorg).

## Seed nodes

Added three fixed seeds to `chainparamsseeds.h` (`pnSeed6_main`) and
`contrib/seeds/nodes_main.txt`: `51.83.11.113`, `85.15.179.171`, `91.206.16.214` (:13580).

## Tests

`test_argentum`: **48 / 56 suites pass**. Regenerated `base58_keys_valid.json` and the
hardcoded WIF/address constants in `key_tests` / `bloom_tests` / `rpc_tests` to match the
current chainparams prefixes (PUBKEY=23, SCRIPT=5, SECRET=151). Remaining failures are
pre-existing and unrelated to this work (consensus PoW-path behavior, BIP9 deployment
params, a `listbanned` test, and a wallet-crypto vector) — tracked separately with the
maintainer.

> A separate security review was delivered privately to the maintainer; items requiring a
> coordinated network upgrade are intentionally **not** changed here.
