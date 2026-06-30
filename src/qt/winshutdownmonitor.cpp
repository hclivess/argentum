// Copyright (c) 2014-2016 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include "winshutdownmonitor.h"

#if defined(Q_OS_WIN) && QT_VERSION >= 0x050000
#include "init.h"
#include "util.h"

#include <windows.h>

#include <QDebug>

#include <openssl/rand.h>

// If we don't want a message to be processed by Qt, return true and set result to
// the value that the window procedure should return. Otherwise return false.
bool WinShutdownMonitor::nativeEventFilter(const QByteArray &eventType, void *pMessage, long *pnResult)
{
       Q_UNUSED(eventType);

       MSG *pMsg = static_cast<MSG *>(pMessage);

       // Seed OpenSSL PRNG with Windows event data (e.g.  mouse movements and other user interactions)
#if OPENSSL_VERSION_NUMBER < 0x10100000L
       if (RAND_event(pMsg->message, pMsg->wParam, pMsg->lParam) == 0) {
            // Warn only once as this is performance-critical
            static bool warned = false;
            if (!warned) {
                LogPrintf("%s: OpenSSL RAND_event() failed to seed OpenSSL PRNG with enough data.\n", __func__);
                warned = true;
            }
       }
#else
       // RAND_event() was removed in OpenSSL 1.1; feed the event data into the PRNG directly.
       const UINT message = pMsg->message;
       const WPARAM wParam = pMsg->wParam;
       const LPARAM lParam = pMsg->lParam;
       RAND_add(&message, sizeof(message), 0.0);
       RAND_add(&wParam, sizeof(wParam), 0.0);
       RAND_add(&lParam, sizeof(lParam), 0.0);
#endif

       switch(pMsg->message)
       {
           case WM_QUERYENDSESSION:
           {
               // Initiate a client shutdown after receiving a WM_QUERYENDSESSION and block
               // Windows session end until we have finished client shutdown.
               StartShutdown();
               *pnResult = FALSE;
               return true;
           }

           case WM_ENDSESSION:
           {
               *pnResult = FALSE;
               return true;
           }
       }

       return false;
}

void WinShutdownMonitor::registerShutdownBlockReason(const QString& strReason, const HWND& mainWinId)
{
    typedef BOOL (WINAPI *PSHUTDOWNBRCREATE)(HWND, LPCWSTR);
    PSHUTDOWNBRCREATE shutdownBRCreate = (PSHUTDOWNBRCREATE)GetProcAddress(GetModuleHandleA("User32.dll"), "ShutdownBlockReasonCreate");
    if (shutdownBRCreate == NULL) {
        qWarning() << "registerShutdownBlockReason: GetProcAddress for ShutdownBlockReasonCreate failed";
        return;
    }

    if (shutdownBRCreate(mainWinId, strReason.toStdWString().c_str()))
        qWarning() << "registerShutdownBlockReason: Successfully registered: " + strReason;
    else
        qWarning() << "registerShutdownBlockReason: Failed to register: " + strReason;
}
#endif
