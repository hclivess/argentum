# Qt5 GUI (argentum-qt).
#
# Included from the top-level CMakeLists.txt when -DWITH_QT_GUI=ON. Mirrors
# src/Makefile.qt.include: the qt/*.cpp widgets/models, the qt/forms/*.ui forms
# (uic), qt/bitcoin.qrc + qt/bitcoin_locale.qrc resources (rcc), the Q_OBJECT
# classes (moc) and qt/paymentrequest.proto (protoc / BIP70).
#
# CMake's find_package(Qt5) is the whole point of this build: it detects Qt
# cleanly on Windows/MSYS2, where the autotools Qt5 macros fail.

find_package(Qt5 5.9 REQUIRED COMPONENTS Core Gui Widgets Network)
find_package(Qt5 QUIET COMPONENTS DBus LinguistTools)

# Payment protocol (BIP70) uses protobuf; the QR display uses libqrencode.
# src/config/bitcoin-config.h already reflects whether ./configure found them
# (USE_QRCODE). We honor those here so the GUI matches the autotools build.
find_package(Protobuf REQUIRED)
find_library(QRENCODE_LIBRARY NAMES qrencode)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
# AUTOUIC is intentionally OFF: the project ships its own non-uic header
# src/ui_interface.h whose name matches AUTOUIC's "ui_*.h" detection and would
# make it hunt for a bogus "interface.ui". Drive uic explicitly instead.
set(CMAKE_AUTOMOC_MOC_OPTIONS "-DQT_NO_KEYWORDS")

# uic the .ui forms -> ${binary}/ui_<name>.h
set(QT_FORMS_UI
    ${SRC}/qt/forms/addressbookpage.ui
    ${SRC}/qt/forms/askpassphrasedialog.ui
    ${SRC}/qt/forms/coincontroldialog.ui
    ${SRC}/qt/forms/editaddressdialog.ui
    ${SRC}/qt/forms/helpmessagedialog.ui
    ${SRC}/qt/forms/intro.ui
    ${SRC}/qt/forms/modaloverlay.ui
    ${SRC}/qt/forms/openuridialog.ui
    ${SRC}/qt/forms/optionsdialog.ui
    ${SRC}/qt/forms/overviewpage.ui
    ${SRC}/qt/forms/receivecoinsdialog.ui
    ${SRC}/qt/forms/receiverequestdialog.ui
    ${SRC}/qt/forms/debugwindow.ui
    ${SRC}/qt/forms/sendcoinsdialog.ui
    ${SRC}/qt/forms/sendcoinsentry.ui
    ${SRC}/qt/forms/signverifymessagedialog.ui
    ${SRC}/qt/forms/transactiondescdialog.ui)
qt5_wrap_ui(QT_FORMS_H ${QT_FORMS_UI})

# protoc paymentrequest.proto -> paymentrequest.pb.{cc,h} in the binary dir.
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${SRC}/qt/paymentrequest.proto)

# Translations: lrelease each qt/locale/*.ts -> <build>/qt/locale/*.qm, then rcc
# qt/bitcoin_locale.qrc (which references "locale/<name>.qm") into
# qrc_bitcoin_locale.cpp with the resource name "bitcoin_locale" (matches the
# Q_INIT_RESOURCE(bitcoin_locale) call in qt/bitcoin.cpp). This mirrors the
# autotools $(QT_QRC_LOCALE_CPP) rule. AUTORCC can't do this (it never runs
# lrelease), so bitcoin_locale.qrc is handled explicitly here and kept out of
# the AUTORCC source list.
find_program(LRELEASE_EXECUTABLE NAMES lrelease-qt5 lrelease
             HINTS ${_qt5Core_install_prefix}/bin /usr/lib/qt5/bin)
file(GLOB QT_TS_FILES ${SRC}/qt/locale/*.ts)
set(QT_QM_DIR ${CMAKE_CURRENT_BINARY_DIR}/qt/locale)
file(MAKE_DIRECTORY ${QT_QM_DIR})
set(QT_QM_FILES "")
foreach(_ts ${QT_TS_FILES})
    get_filename_component(_name ${_ts} NAME_WE)
    set(_qm ${QT_QM_DIR}/${_name}.qm)
    add_custom_command(OUTPUT ${_qm}
        COMMAND ${LRELEASE_EXECUTABLE} -silent ${_ts} -qm ${_qm}
        DEPENDS ${_ts} VERBATIM)
    list(APPEND QT_QM_FILES ${_qm})
endforeach()

set(QT_LOCALE_QRC ${CMAKE_CURRENT_BINARY_DIR}/qt/bitcoin_locale.qrc)
configure_file(${SRC}/qt/bitcoin_locale.qrc ${QT_LOCALE_QRC} COPYONLY)
set(QT_LOCALE_QRC_CPP ${CMAKE_CURRENT_BINARY_DIR}/qrc_bitcoin_locale.cpp)
add_custom_command(OUTPUT ${QT_LOCALE_QRC_CPP}
    COMMAND ${Qt5Core_RCC_EXECUTABLE} -name bitcoin_locale
            -o ${QT_LOCALE_QRC_CPP} ${QT_LOCALE_QRC}
    DEPENDS ${QT_LOCALE_QRC} ${QT_QM_FILES} VERBATIM)

# GUI base widgets/models (always built).
set(QT_BASE_CPP
    ${SRC}/qt/bantablemodel.cpp
    ${SRC}/qt/bitcoinaddressvalidator.cpp
    ${SRC}/qt/bitcoinamountfield.cpp
    ${SRC}/qt/bitcoingui.cpp
    ${SRC}/qt/bitcoinunits.cpp
    ${SRC}/qt/clientmodel.cpp
    ${SRC}/qt/csvmodelwriter.cpp
    ${SRC}/qt/guiutil.cpp
    ${SRC}/qt/intro.cpp
    ${SRC}/qt/modaloverlay.cpp
    ${SRC}/qt/networkstyle.cpp
    ${SRC}/qt/notificator.cpp
    ${SRC}/qt/optionsdialog.cpp
    ${SRC}/qt/optionsmodel.cpp
    ${SRC}/qt/peertablemodel.cpp
    ${SRC}/qt/platformstyle.cpp
    ${SRC}/qt/qvalidatedlineedit.cpp
    ${SRC}/qt/qvaluecombobox.cpp
    ${SRC}/qt/rpcconsole.cpp
    ${SRC}/qt/splashscreen.cpp
    ${SRC}/qt/trafficgraphwidget.cpp
    ${SRC}/qt/utilitydialog.cpp)

# Wallet-dependent widgets/models.
set(QT_WALLET_CPP
    ${SRC}/qt/addressbookpage.cpp
    ${SRC}/qt/addresstablemodel.cpp
    ${SRC}/qt/askpassphrasedialog.cpp
    ${SRC}/qt/coincontroldialog.cpp
    ${SRC}/qt/coincontroltreewidget.cpp
    ${SRC}/qt/editaddressdialog.cpp
    ${SRC}/qt/openuridialog.cpp
    ${SRC}/qt/overviewpage.cpp
    ${SRC}/qt/paymentrequestplus.cpp
    ${SRC}/qt/paymentserver.cpp
    ${SRC}/qt/receivecoinsdialog.cpp
    ${SRC}/qt/receiverequestdialog.cpp
    ${SRC}/qt/recentrequeststablemodel.cpp
    ${SRC}/qt/sendcoinsdialog.cpp
    ${SRC}/qt/sendcoinsentry.cpp
    ${SRC}/qt/signverifymessagedialog.cpp
    ${SRC}/qt/transactiondesc.cpp
    ${SRC}/qt/transactiondescdialog.cpp
    ${SRC}/qt/transactionfilterproxy.cpp
    ${SRC}/qt/transactionrecord.cpp
    ${SRC}/qt/transactiontablemodel.cpp
    ${SRC}/qt/transactionview.cpp
    ${SRC}/qt/walletframe.cpp
    ${SRC}/qt/walletmodel.cpp
    ${SRC}/qt/walletmodeltransaction.cpp
    ${SRC}/qt/walletview.cpp)

set(QT_GUI_SOURCES
    ${SRC}/qt/bitcoin.cpp
    ${QT_BASE_CPP}
    ${SRC}/qt/bitcoin.qrc            # icons/images: handled by AUTORCC
    ${QT_LOCALE_QRC_CPP}             # translations: rcc'd explicitly (see above)
    ${QT_FORMS_H}
    ${PROTO_SRCS})

if(WITH_WALLET)
    list(APPEND QT_GUI_SOURCES ${QT_WALLET_CPP})
endif()
if(WIN32)
    list(APPEND QT_GUI_SOURCES ${SRC}/qt/winshutdownmonitor.cpp)
    enable_language(RC)
    list(APPEND QT_GUI_SOURCES ${SRC}/qt/res/bitcoin-qt-res.rc)
    # windres can't preprocess the real C++ in clientversion.h; that header
    # guards those bits behind WINDRES_PREPROC, so define it for the .rc compile.
    set_source_files_properties(${SRC}/qt/res/bitcoin-qt-res.rc
        PROPERTIES COMPILE_DEFINITIONS "WINDRES_PREPROC")
endif()

add_executable(argentum-qt WIN32 ${QT_GUI_SOURCES})

# Match the autotools Qt build: BITCOIN_QT_INCLUDES uses -DQT_NO_KEYWORDS and
# adds qt/ + qt/forms/ + the build dir (generated ui_*.h / *.pb.h).
argentum_common_settings(argentum-qt)
target_include_directories(argentum-qt PRIVATE
    ${SRC}/qt
    ${SRC}/qt/forms
    ${CMAKE_CURRENT_BINARY_DIR}          # generated ui_*.h, paymentrequest.pb.h, moc
    ${Protobuf_INCLUDE_DIRS})
target_compile_definitions(argentum-qt PRIVATE QT_NO_KEYWORDS)

target_link_libraries(argentum-qt PRIVATE
    ${ARGENTUM_LINK_LIBS}
    Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Network
    ${Protobuf_LIBRARIES})

if(QRENCODE_LIBRARY)
    target_link_libraries(argentum-qt PRIVATE ${QRENCODE_LIBRARY})
endif()

if(Qt5DBus_FOUND)
    target_compile_definitions(argentum-qt PRIVATE USE_DBUS)
    target_link_libraries(argentum-qt PRIVATE Qt5::DBus)
endif()

if(WIN32)
    # argentum-qt is a GUI-subsystem (WIN32) exe: Qt5::WinMain supplies WinMain().
    target_link_libraries(argentum-qt PRIVATE Qt5::WinMain)
endif()

install(TARGETS argentum-qt RUNTIME DESTINATION bin)
