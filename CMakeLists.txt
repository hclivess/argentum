# Argentum (ARG) — modern CMake build.
#
# This is a *build-system addition* alongside the existing autotools build.
# Its main reason to exist is that CMake's find_package(Qt5) detects Qt cleanly
# on Windows/MSYS2, where the autotools Qt5 detection fails ("QtCore headers
# missing"). It builds the headless daemon (argentumd) and the Qt5 GUI
# (argentum-qt) from Argentum's own source layout (see src/Makefile.am and
# src/Makefile.qt.include, which this file mirrors).
#
# Consensus/runtime behavior is unchanged: the same .cpp/.h are compiled with
# the same defines/includes as the autotools build; only the build driver is new.

cmake_minimum_required(VERSION 3.16)

project(Argentum
    VERSION 3.0.0
    DESCRIPTION "Argentum (ARG) cryptocurrency"
    LANGUAGES C CXX)

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
option(WITH_QT_GUI        "Build the Qt5 GUI (argentum-qt)"                 ON)
option(WITH_WALLET        "Build with wallet support (Berkeley DB)"         ON)
option(WITH_DAEMON        "Build the headless daemon (argentumd)"           ON)
option(ENABLE_UPNP        "Build with UPnP support (libminiupnpc)"          OFF)
# The bundled LevelDB builds via its own Unix Makefile (no Windows port), so on
# Windows/mingw use the system package instead (mingw-w64-x86_64-leveldb).
option(USE_SYSTEM_LEVELDB "Link the system LevelDB instead of the bundled copy" ${WIN32})

# ---------------------------------------------------------------------------
# Language / global flags
# ---------------------------------------------------------------------------
# Match the autotools build, which uses the compiler default (GCC 13 => gnu++17).
# The Bitcoin-0.14-era code is C++11 but compiles cleanly under C++17, and the
# modern libstdc++ headers assume >=14 for some transitive includes.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# This is 2014-era Bitcoin-0.14-derived code: it keeps OpenSSL's low-level
# EC/BIGNUM API (deprecated but present in OpenSSL 3) and trips a lot of modern
# -W warnings that are not worth the churn/risk in consensus paths. Silence the
# noise the way the sibling HoboNickels CMake build does.
add_compile_options(
    -Wno-deprecated-declarations
    -Wno-unused-parameter -Wno-unused-variable -Wno-sign-compare
    -Wno-unused-function -Wno-deprecated-copy)

# Bitcoin refuses to compile with assertions disabled (assert() is load-bearing
# in consensus code). CMake's Release/RelWithDebInfo add -DNDEBUG, so undefine
# it globally, exactly as the autotools build (which never sets NDEBUG) does.
add_compile_options(-UNDEBUG)

set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/src)

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
find_package(OpenSSL REQUIRED)

set(Boost_USE_MULTITHREADED ON)
find_package(Boost 1.65 REQUIRED
    COMPONENTS system filesystem program_options thread chrono)

# libevent (http server / RPC). Prefer pkg-config, fall back to plain names.
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(EVENT   libevent)
    pkg_check_modules(EVENT_PTHREADS libevent_pthreads)
endif()
find_library(EVENT_LIB          NAMES event         REQUIRED)
find_library(EVENT_PTHREADS_LIB NAMES event_pthreads)

# Berkeley DB C++ binding (libdb_cxx). No standard CMake find module exists.
if(WITH_WALLET)
    find_path(BDBXX_INCLUDE_DIR db_cxx.h
        PATH_SUFFIXES db5.3 db5 db4.8 db)
    find_library(BDBXX_LIBRARY NAMES db_cxx db_cxx-5.3 db_cxx-5 db_cxx-4.8)
    if(NOT BDBXX_INCLUDE_DIR OR NOT BDBXX_LIBRARY)
        message(FATAL_ERROR "Berkeley DB C++ (libdb++-dev) not found; "
                            "install it or configure with -DWITH_WALLET=OFF")
    endif()
    message(STATUS "Berkeley DB: ${BDBXX_LIBRARY} (include: ${BDBXX_INCLUDE_DIR})")
endif()

# UPnP is governed by the reused autotools config header: net.cpp guards on
# #ifdef USE_UPNP (defined-ness, not value), so if ./configure defined USE_UPNP
# at all (even to 0 = "compiled in, off by default") we must link miniupnpc.
# ENABLE_UPNP can also force it on. The header, not CMake, owns the USE_UPNP
# define, so we never define it here (that would be a redefinition).
set(NEED_MINIUPNPC OFF)
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/src/config/bitcoin-config.h)
    file(READ ${CMAKE_CURRENT_SOURCE_DIR}/src/config/bitcoin-config.h _cfg_h)
    if(_cfg_h MATCHES "#define[ \t]+USE_UPNP")
        set(NEED_MINIUPNPC ON)
    endif()
endif()
if(ENABLE_UPNP)
    set(NEED_MINIUPNPC ON)
endif()
if(NEED_MINIUPNPC)
    find_path(MINIUPNPC_INCLUDE_DIR miniupnpc/miniupnpc.h)
    find_library(MINIUPNPC_LIBRARY NAMES miniupnpc)
    if(NOT MINIUPNPC_INCLUDE_DIR OR NOT MINIUPNPC_LIBRARY)
        message(FATAL_ERROR "UPnP is enabled in src/config/bitcoin-config.h "
            "(or via -DENABLE_UPNP=ON) but libminiupnpc-dev was not found. "
            "Install it, or re-run ./configure --without-miniupnpc and reconfigure cmake.")
    endif()
    message(STATUS "UPnP: miniupnpc ${MINIUPNPC_LIBRARY}")
endif()

# ---------------------------------------------------------------------------
# bitcoin-config.h
# ---------------------------------------------------------------------------
# The autotools ./configure generates src/config/bitcoin-config.h with all the
# HAVE_*/ENABLE_*/USE_* defines the code keys off. Reuse it (simplest, and it
# already reflects this box's toolchain). Run ./autogen.sh && ./configure once
# to produce it. HAVE_CONFIG_H makes the sources include it.
if(NOT EXISTS ${SRC}/config/bitcoin-config.h)
    message(FATAL_ERROR
        "src/config/bitcoin-config.h is missing. Generate it once with:\n"
        "    ./autogen.sh && ./configure --with-gui=qt5\n"
        "then re-run cmake. (CMake reuses the autotools-generated config header.)")
endif()

# ---------------------------------------------------------------------------
# Common include dirs / defines (mirror BITCOIN_INCLUDES in src/Makefile.am)
# ---------------------------------------------------------------------------
set(LEVELDB_INCLUDE_DIRS
    ${SRC}/leveldb/include
    ${SRC}/leveldb/helpers/memenv)

set(COMMON_INCLUDE_DIRS
    ${SRC}
    ${SRC}/config
    ${SRC}/obj
    ${SRC}/secp256k1/include
    ${SRC}/univalue/include
    ${LEVELDB_INCLUDE_DIRS})

# HAVE_CONFIG_H              -> pull in src/config/bitcoin-config.h
# BOOST_BIND_GLOBAL_PLACEHOLDERS -> keep bare _1/_2 boost::bind placeholders
#                                   (Boost 1.76+ removed them from global ns)
set(COMMON_DEFINES HAVE_CONFIG_H BOOST_BIND_GLOBAL_PLACEHOLDERS __STDC_FORMAT_MACROS)

if(WITH_WALLET)
    list(APPEND COMMON_INCLUDE_DIRS ${BDBXX_INCLUDE_DIR})
endif()
if(NEED_MINIUPNPC)
    list(APPEND COMMON_INCLUDE_DIRS ${MINIUPNPC_INCLUDE_DIR})
endif()

# Helper: apply the shared includes/defines to a target.
function(argentum_common_settings tgt)
    target_include_directories(${tgt} PUBLIC ${COMMON_INCLUDE_DIRS})
    target_compile_definitions(${tgt} PUBLIC ${COMMON_DEFINES})
    if(WIN32)
        # mingw-w64 only predefines _WIN32; the code branches on bare WIN32.
        target_compile_definitions(${tgt} PUBLIC
            WIN32 _WIN32_WINNT=0x0600 WIN32_LEAN_AND_MEAN)
    endif()
endfunction()

# ---------------------------------------------------------------------------
# Vendored secp256k1
# ---------------------------------------------------------------------------
# The vendored secp256k1 (with the recovery + ecdh modules Argentum's key.cpp
# and pubkey.cpp use) is built with its own autotools. Reuse a prebuilt static
# archive if configure/make already produced one; otherwise build it through
# ExternalProject. On Windows use the system package.
find_path(SECP256K1_INCLUDE_DIR secp256k1.h)
find_library(SECP256K1_LIBRARY NAMES secp256k1)
if(SECP256K1_LIBRARY AND SECP256K1_INCLUDE_DIR)
    message(STATUS "secp256k1: system ${SECP256K1_LIBRARY}")
    add_library(secp256k1 INTERFACE)
    target_include_directories(secp256k1 INTERFACE ${SECP256K1_INCLUDE_DIR})
    target_link_libraries(secp256k1 INTERFACE ${SECP256K1_LIBRARY})
else()
    # No system libsecp256k1 (e.g. MSYS2): build the vendored copy via its own
    # autotools (works on mingw too), same as the reuse-or-build path below.
    set(SECP_A ${SRC}/secp256k1/.libs/libsecp256k1.a)
    if(EXISTS ${SECP_A})
        message(STATUS "secp256k1: reusing prebuilt ${SECP_A}")
        add_library(secp256k1 STATIC IMPORTED GLOBAL)
        set_target_properties(secp256k1 PROPERTIES IMPORTED_LOCATION ${SECP_A})
        target_include_directories(secp256k1 INTERFACE ${SRC}/secp256k1/include)
    else()
        message(STATUS "secp256k1: building vendored copy via ExternalProject")
        include(ExternalProject)
        ExternalProject_Add(secp256k1_ext
            SOURCE_DIR        ${SRC}/secp256k1
            BUILD_IN_SOURCE   1
            CONFIGURE_COMMAND sh -c "test -f Makefile || (./autogen.sh && ./configure --disable-shared --with-pic --enable-module-recovery --enable-module-ecdh --disable-benchmark --disable-tests --disable-exhaustive-tests)"
            BUILD_COMMAND     $(MAKE) libsecp256k1.la
            INSTALL_COMMAND   ""
            BUILD_BYPRODUCTS  ${SECP_A}
            LOG_BUILD         1)
        add_library(secp256k1 STATIC IMPORTED GLOBAL)
        set_target_properties(secp256k1 PROPERTIES IMPORTED_LOCATION ${SECP_A})
        target_include_directories(secp256k1 INTERFACE ${SRC}/secp256k1/include)
        add_dependencies(secp256k1 secp256k1_ext)
    endif()
endif()

# ---------------------------------------------------------------------------
# Bundled LevelDB
# ---------------------------------------------------------------------------
if(USE_SYSTEM_LEVELDB)
    find_path(LEVELDB_INCLUDE_DIR leveldb/db.h)
    find_library(LEVELDB_SYS_LIB NAMES leveldb)
    find_library(MEMENV_SYS_LIB  NAMES memenv)
    if(NOT LEVELDB_INCLUDE_DIR OR NOT LEVELDB_SYS_LIB)
        message(FATAL_ERROR "USE_SYSTEM_LEVELDB=ON but LevelDB was not found")
    endif()
    add_library(leveldb INTERFACE)
    target_include_directories(leveldb INTERFACE ${LEVELDB_INCLUDE_DIR})
    target_link_libraries(leveldb INTERFACE ${LEVELDB_SYS_LIB})
    if(MEMENV_SYS_LIB)
        target_link_libraries(leveldb INTERFACE ${MEMENV_SYS_LIB})
    endif()
    message(STATUS "LevelDB: system (${LEVELDB_SYS_LIB})")
else()
    include(ExternalProject)
    set(LEVELDB_SRC    ${SRC}/leveldb)
    set(LEVELDB_LIB    ${LEVELDB_SRC}/out-static/libleveldb.a)
    set(LEVELDB_MEMENV ${LEVELDB_SRC}/out-static/libmemenv.a)
    ExternalProject_Add(leveldb_ext
        SOURCE_DIR        ${LEVELDB_SRC}
        BUILD_IN_SOURCE   1
        CONFIGURE_COMMAND ""
        BUILD_COMMAND     $(MAKE) out-static/libleveldb.a out-static/libmemenv.a
        INSTALL_COMMAND   ""
        BUILD_BYPRODUCTS  ${LEVELDB_LIB} ${LEVELDB_MEMENV}
        LOG_BUILD         1)
    add_library(leveldb STATIC IMPORTED GLOBAL)
    set_target_properties(leveldb PROPERTIES IMPORTED_LOCATION ${LEVELDB_LIB})
    add_dependencies(leveldb leveldb_ext)
    add_library(memenv STATIC IMPORTED GLOBAL)
    set_target_properties(memenv PROPERTIES IMPORTED_LOCATION ${LEVELDB_MEMENV})
    add_dependencies(memenv leveldb_ext)
    target_link_libraries(leveldb INTERFACE memenv)
    message(STATUS "LevelDB: bundled (built via ExternalProject)")
endif()

# ---------------------------------------------------------------------------
# univalue (vendored JSON library) — compiled directly
# ---------------------------------------------------------------------------
add_library(univalue STATIC
    ${SRC}/univalue/lib/univalue.cpp
    ${SRC}/univalue/lib/univalue_read.cpp
    ${SRC}/univalue/lib/univalue_write.cpp)
target_include_directories(univalue PUBLIC
    ${SRC}/univalue/include ${SRC}/univalue/lib)

# ===========================================================================
# Static libraries (mirror src/Makefile.am)
# ===========================================================================

# --- crypto ---
add_library(bitcoin_crypto STATIC
    ${SRC}/crypto/aes.cpp
    ${SRC}/crypto/hmac_sha256.cpp
    ${SRC}/crypto/hmac_sha512.cpp
    ${SRC}/crypto/ripemd160.cpp
    ${SRC}/crypto/scrypt.cpp
    ${SRC}/crypto/scrypt-sse2.cpp
    ${SRC}/crypto/sha1.cpp
    ${SRC}/crypto/sha256.cpp
    ${SRC}/crypto/sha512.cpp
    ${SRC}/crypto/aes_helper.c
    ${SRC}/crypto/blake.c
    ${SRC}/crypto/bmw.c
    ${SRC}/crypto/cubehash.c
    ${SRC}/crypto/echo.c
    ${SRC}/crypto/groestl.c
    ${SRC}/crypto/jh.c
    ${SRC}/crypto/keccak.c
    ${SRC}/crypto/luffa.c
    ${SRC}/crypto/shavite.c
    ${SRC}/crypto/simd.c
    ${SRC}/crypto/skein.c
    ${SRC}/crypto/sha256_Y.c
    ${SRC}/crypto/argon2/argon2.c
    ${SRC}/crypto/argon2/best.c
    ${SRC}/crypto/argon2/blake2b.c
    ${SRC}/crypto/argon2/core.c
    ${SRC}/crypto/argon2/encoding.c
    ${SRC}/crypto/argon2/thread.c
    ${SRC}/crypto/argon2/opt.c
    ${SRC}/crypto/lyra2/lyra2.c
    ${SRC}/crypto/lyra2/lyra2RE.c
    ${SRC}/crypto/lyra2/sponge.c
    ${SRC}/crypto/yescrypt-best.c
    ${SRC}/crypto/yescryptcommon.c)
target_include_directories(bitcoin_crypto PUBLIC ${SRC} ${SRC}/config)
target_compile_definitions(bitcoin_crypto PUBLIC HAVE_CONFIG_H)

# --- consensus ---
add_library(bitcoin_consensus STATIC
    ${SRC}/arith_uint256.cpp
    ${SRC}/consensus/merkle.cpp
    ${SRC}/hash.cpp
    ${SRC}/primitives/block.cpp
    ${SRC}/primitives/pureheader.cpp
    ${SRC}/primitives/transaction.cpp
    ${SRC}/pubkey.cpp
    ${SRC}/script/bitcoinconsensus.cpp
    ${SRC}/script/interpreter.cpp
    ${SRC}/script/script.cpp
    ${SRC}/script/script_error.cpp
    ${SRC}/uint256.cpp
    ${SRC}/utilstrencodings.cpp)
argentum_common_settings(bitcoin_consensus)
target_link_libraries(bitcoin_consensus PUBLIC secp256k1 OpenSSL::Crypto)

# --- util ---
add_library(bitcoin_util STATIC
    ${SRC}/support/lockedpool.cpp
    ${SRC}/chainparamsbase.cpp
    ${SRC}/clientversion.cpp
    ${SRC}/compat/glibc_sanity.cpp
    ${SRC}/compat/glibcxx_sanity.cpp
    ${SRC}/compat/strnlen.cpp
    ${SRC}/random.cpp
    ${SRC}/rpc/protocol.cpp
    ${SRC}/support/cleanse.cpp
    ${SRC}/sync.cpp
    ${SRC}/threadinterrupt.cpp
    ${SRC}/util.cpp
    ${SRC}/utilmoneystr.cpp
    ${SRC}/utilstrencodings.cpp
    ${SRC}/utiltime.cpp)
argentum_common_settings(bitcoin_util)
target_link_libraries(bitcoin_util PUBLIC
    univalue OpenSSL::SSL OpenSSL::Crypto
    Boost::system Boost::filesystem Boost::thread Boost::chrono Boost::program_options
    Threads::Threads ${CMAKE_DL_LIBS})

# --- common ---
add_library(bitcoin_common STATIC
    ${SRC}/amount.cpp
    ${SRC}/base58.cpp
    ${SRC}/chainparams.cpp
    ${SRC}/coins.cpp
    ${SRC}/compressor.cpp
    ${SRC}/core_read.cpp
    ${SRC}/core_write.cpp
    ${SRC}/key.cpp
    ${SRC}/keystore.cpp
    ${SRC}/netaddress.cpp
    ${SRC}/netbase.cpp
    ${SRC}/protocol.cpp
    ${SRC}/scheduler.cpp
    ${SRC}/script/sign.cpp
    ${SRC}/script/standard.cpp
    ${SRC}/warnings.cpp)
argentum_common_settings(bitcoin_common)
target_link_libraries(bitcoin_common PUBLIC
    bitcoin_consensus univalue secp256k1 OpenSSL::SSL OpenSSL::Crypto)

# --- server ---
add_library(bitcoin_server STATIC
    ${SRC}/addrman.cpp
    ${SRC}/addrdb.cpp
    ${SRC}/auxpow.cpp
    ${SRC}/bloom.cpp
    ${SRC}/blockencodings.cpp
    ${SRC}/chain.cpp
    ${SRC}/checkpoints.cpp
    ${SRC}/httprpc.cpp
    ${SRC}/httpserver.cpp
    ${SRC}/init.cpp
    ${SRC}/dbwrapper.cpp
    ${SRC}/merkleblock.cpp
    ${SRC}/miner.cpp
    ${SRC}/net.cpp
    ${SRC}/net_processing.cpp
    ${SRC}/noui.cpp
    ${SRC}/policy/fees.cpp
    ${SRC}/policy/policy.cpp
    ${SRC}/pow.cpp
    ${SRC}/rest.cpp
    ${SRC}/rpc/blockchain.cpp
    ${SRC}/rpc/mining.cpp
    ${SRC}/rpc/misc.cpp
    ${SRC}/rpc/net.cpp
    ${SRC}/rpc/rawtransaction.cpp
    ${SRC}/rpc/server.cpp
    ${SRC}/script/sigcache.cpp
    ${SRC}/script/ismine.cpp
    ${SRC}/timedata.cpp
    ${SRC}/torcontrol.cpp
    ${SRC}/txdb.cpp
    ${SRC}/txmempool.cpp
    ${SRC}/ui_interface.cpp
    ${SRC}/validation.cpp
    ${SRC}/validationinterface.cpp
    ${SRC}/versionbits.cpp)
argentum_common_settings(bitcoin_server)
if(EVENT_INCLUDE_DIRS)
    target_include_directories(bitcoin_server PUBLIC ${EVENT_INCLUDE_DIRS})
endif()
target_link_libraries(bitcoin_server PUBLIC
    bitcoin_common bitcoin_consensus leveldb univalue
    ${EVENT_LIB})
if(EVENT_PTHREADS_LIB)
    target_link_libraries(bitcoin_server PUBLIC ${EVENT_PTHREADS_LIB})
endif()
add_dependencies(bitcoin_server leveldb)

# --- cli ---
add_library(bitcoin_cli STATIC ${SRC}/rpc/client.cpp)
argentum_common_settings(bitcoin_cli)
target_link_libraries(bitcoin_cli PUBLIC univalue)

# --- wallet ---
if(WITH_WALLET)
    add_library(bitcoin_wallet STATIC
        ${SRC}/wallet/crypter.cpp
        ${SRC}/wallet/db.cpp
        ${SRC}/wallet/rpcdump.cpp
        ${SRC}/wallet/rpcwallet.cpp
        ${SRC}/wallet/wallet.cpp
        ${SRC}/wallet/walletdb.cpp)
    argentum_common_settings(bitcoin_wallet)
    target_link_libraries(bitcoin_wallet PUBLIC
        bitcoin_common bitcoin_consensus univalue ${BDBXX_LIBRARY})
endif()

# ---------------------------------------------------------------------------
# The full link set shared by argentumd and argentum-qt.
# ---------------------------------------------------------------------------
set(ARGENTUM_LINK_LIBS
    bitcoin_server
    bitcoin_common)
if(WITH_WALLET)
    list(APPEND ARGENTUM_LINK_LIBS bitcoin_wallet)
endif()
list(APPEND ARGENTUM_LINK_LIBS
    bitcoin_cli
    bitcoin_util
    bitcoin_consensus
    bitcoin_crypto
    univalue
    leveldb
    secp256k1
    OpenSSL::SSL OpenSSL::Crypto
    Boost::system Boost::filesystem Boost::program_options Boost::thread Boost::chrono
    ${EVENT_LIB}
    Threads::Threads
    ${CMAKE_DL_LIBS})
if(EVENT_PTHREADS_LIB)
    list(APPEND ARGENTUM_LINK_LIBS ${EVENT_PTHREADS_LIB})
endif()
if(WITH_WALLET)
    list(APPEND ARGENTUM_LINK_LIBS ${BDBXX_LIBRARY})
endif()
if(NEED_MINIUPNPC)
    list(APPEND ARGENTUM_LINK_LIBS ${MINIUPNPC_LIBRARY})
endif()
if(WIN32)
    list(APPEND ARGENTUM_LINK_LIBS ws2_32 mswsock iphlpapi shlwapi shell32 ole32)
endif()

# ---------------------------------------------------------------------------
# Daemon: argentumd
# ---------------------------------------------------------------------------
if(WITH_DAEMON)
    add_executable(argentumd ${SRC}/bitcoind.cpp)
    argentum_common_settings(argentumd)
    target_link_libraries(argentumd PRIVATE ${ARGENTUM_LINK_LIBS})
    install(TARGETS argentumd RUNTIME DESTINATION bin)
endif()

# ---------------------------------------------------------------------------
# Qt5 GUI: argentum-qt
# ---------------------------------------------------------------------------
if(WITH_QT_GUI)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Gui.cmake)
endif()

message(STATUS "")
message(STATUS "Argentum ${PROJECT_VERSION} configured:")
message(STATUS "  Build type      : ${CMAKE_BUILD_TYPE}")
message(STATUS "  Daemon          : ${WITH_DAEMON}")
message(STATUS "  Wallet (BDB)    : ${WITH_WALLET}")
message(STATUS "  Qt5 GUI         : ${WITH_QT_GUI}")
message(STATUS "  UPnP            : ${ENABLE_UPNP}")
message(STATUS "  System LevelDB  : ${USE_SYSTEM_LEVELDB}")
message(STATUS "")
