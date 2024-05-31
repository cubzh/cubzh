//
//  device.cpp
//  xptools
//
//  Created by Adrien Duermael on 04/20/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "device.hpp"

// C++
#include <vector>
#include <string>
#include <codecvt>
#include <iostream>

// Win32
#include <atlstr.h>
#include <strsafe.h>
#include <tchar.h>
#include <wtypes.h>
#include <WinUser.h>
#include <comdef.h>
#include <Wbemidl.h>
#include <Windows.h>

// xptools
#include "internal_windows.hpp"

#include "vxlog.h"

#pragma comment(lib, "wbemuuid.lib")

// Returns platform type
vx::device::Platform vx::device::platform() {
    return Platform_Desktop;
}

std::string vx::device::osName() {
    // NOTE: maybe there's something better
    return "Windows";
}

std::string vx::device::osVersion() {
    // TODO: implement
    return "";
}

std::string vx::device::appVersion() {
    std::string appVersion;
    uint16_t buildNumber;
    vx::windows::getProductVersion(appVersion, buildNumber);
    return appVersion;
}

uint16_t vx::device::appBuildNumber() {
    std::string appVersion;
    uint16_t buildNumber;
    vx::windows::getProductVersion(appVersion, buildNumber);
    return buildNumber;
}

std::string get_Win32_ComputerSystem_String(const std::string &name) {
    std::string result = "";

    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    std::wstring nameW = converter.from_bytes(name);

    HRESULT hres;

    // Step 1: Initialize COM library
    hres = CoInitializeEx(0, COINIT_MULTITHREADED);
    if (FAILED(hres)) {
        std::cerr << "Failed to initialize COM library. Error code: " << hres << std::endl;
        return "";
    }

    // Step 2: Set security levels on the COM instance
    hres = CoInitializeSecurity(NULL,
                                -1,
                                NULL,
                                NULL,
                                RPC_C_AUTHN_LEVEL_DEFAULT,
                                RPC_C_IMP_LEVEL_IMPERSONATE,
                                NULL,
                                EOAC_NONE,
                                NULL);
    if (FAILED(hres)) {
        std::cerr << "Failed to initialize security. Error code: " << hres << std::endl;
        CoUninitialize();
        return "";
    }

    // Step 3: Obtain the initial locator to WMI
    IWbemLocator *pLoc = NULL;
    hres = CoCreateInstance(CLSID_WbemLocator,
                            0,
                            CLSCTX_INPROC_SERVER,
                            IID_IWbemLocator,
                            (LPVOID *)&pLoc);
    if (FAILED(hres)) {
        std::cerr << "Failed to create IWbemLocator object. Error code: " << hres << std::endl;
        CoUninitialize();
        return "";
    }

    // Step 4: Connect to WMI through the IWbemLocator::ConnectServer method
    IWbemServices *pSvc = NULL;
    hres = pLoc->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), NULL, NULL, 0, NULL, 0, 0, &pSvc);
    if (FAILED(hres)) {
        std::cerr << "Could not connect to WMI. Error code: " << hres << std::endl;
        pLoc->Release();
        CoUninitialize();
        return "";
    }

    // Step 5: Set security levels on the proxy
    hres = CoSetProxyBlanket(pSvc,
                             RPC_C_AUTHN_WINNT,
                             RPC_C_AUTHZ_NONE,
                             NULL,
                             RPC_C_AUTHN_LEVEL_CALL,
                             RPC_C_IMP_LEVEL_IMPERSONATE,
                             NULL,
                             EOAC_NONE);
    if (FAILED(hres)) {
        std::cerr << "Could not set proxy blanket. Error code: " << hres << std::endl;
        pSvc->Release();
        pLoc->Release();
        CoUninitialize();
        return "";
    }

    // Step 6: Use the IWbemServices pointer to make WMI queries
    IEnumWbemClassObject *pEnumerator = NULL;
    hres = pSvc->ExecQuery(bstr_t("WQL"),
                           bstr_t("SELECT * FROM Win32_ComputerSystem"),
                           WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                           NULL,
                           &pEnumerator);
    if (FAILED(hres)) {
        std::cerr << "Query failed. Error code: " << hres << std::endl;
        pSvc->Release();
        pLoc->Release();
        CoUninitialize();
        return "";
    }

    // Step 7: Retrieve the data from the query result
    IWbemClassObject *pclsObj = NULL;
    ULONG uReturn = 0;
    while (pEnumerator) {
        hres = pEnumerator->Next(WBEM_INFINITE, 1, &pclsObj, &uReturn);
        if (uReturn == 0) {
            break;
        }

        VARIANT vtProp;
        hres = pclsObj->Get(nameW.c_str(), 0, &vtProp, 0, 0);
        if (SUCCEEDED(hres)) {
            result = converter.to_bytes(std::wstring(vtProp.bstrVal));
            VariantClear(&vtProp);
        }

        pclsObj->Release();
    }

    // Step 8: Cleanup
    pSvc->Release();
    pLoc->Release();
    pEnumerator->Release();
    CoUninitialize();

    return result;
}

uint64_t get_Win32_ComputerSystem_Uint64(const std::string &name) {
    uint64_t result = 0;

    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    std::wstring nameW = converter.from_bytes(name);

    HRESULT hres;

    // Step 1: Initialize COM library
    hres = CoInitializeEx(0, COINIT_MULTITHREADED);
    if (FAILED(hres)) {
        std::cerr << "Failed to initialize COM library. Error code: " << hres << std::endl;
        return 0;
    }

    // Step 2: Set security levels on the COM instance
    hres = CoInitializeSecurity(NULL,
                                -1,
                                NULL,
                                NULL,
                                RPC_C_AUTHN_LEVEL_DEFAULT,
                                RPC_C_IMP_LEVEL_IMPERSONATE,
                                NULL,
                                EOAC_NONE,
                                NULL);
    if (FAILED(hres)) {
        std::cerr << "Failed to initialize security. Error code: " << hres << std::endl;
        CoUninitialize();
        return 0;
    }

    // Step 3: Obtain the initial locator to WMI
    IWbemLocator *pLoc = NULL;
    hres = CoCreateInstance(CLSID_WbemLocator,
                            0,
                            CLSCTX_INPROC_SERVER,
                            IID_IWbemLocator,
                            (LPVOID *)&pLoc);
    if (FAILED(hres)) {
        std::cerr << "Failed to create IWbemLocator object. Error code: " << hres << std::endl;
        CoUninitialize();
        return 0;
    }

    // Step 4: Connect to WMI through the IWbemLocator::ConnectServer method
    IWbemServices *pSvc = NULL;
    hres = pLoc->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), NULL, NULL, 0, NULL, 0, 0, &pSvc);
    if (FAILED(hres)) {
        std::cerr << "Could not connect to WMI. Error code: " << hres << std::endl;
        pLoc->Release();
        CoUninitialize();
        return 0;
    }

    // Step 5: Set security levels on the proxy
    hres = CoSetProxyBlanket(pSvc,
                             RPC_C_AUTHN_WINNT,
                             RPC_C_AUTHZ_NONE,
                             NULL,
                             RPC_C_AUTHN_LEVEL_CALL,
                             RPC_C_IMP_LEVEL_IMPERSONATE,
                             NULL,
                             EOAC_NONE);
    if (FAILED(hres)) {
        std::cerr << "Could not set proxy blanket. Error code: " << hres << std::endl;
        pSvc->Release();
        pLoc->Release();
        CoUninitialize();
        return 0;
    }

    // Step 6: Use the IWbemServices pointer to make WMI queries
    IEnumWbemClassObject *pEnumerator = NULL;
    hres = pSvc->ExecQuery(bstr_t("WQL"),
                           bstr_t("SELECT * FROM Win32_ComputerSystem"),
                           WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                           NULL,
                           &pEnumerator);
    if (FAILED(hres)) {
        std::cerr << "Query failed. Error code: " << hres << std::endl;
        pSvc->Release();
        pLoc->Release();
        CoUninitialize();
        return 0;
    }

    // Step 7: Retrieve the data from the query result
    IWbemClassObject *pclsObj = NULL;
    ULONG uReturn = 0;
    while (pEnumerator) {
        hres = pEnumerator->Next(WBEM_INFINITE, 1, &pclsObj, &uReturn);
        if (uReturn == 0) {
            break;
        }

        VARIANT vtProp;
        hres = pclsObj->Get(nameW.c_str(), 0, &vtProp, 0, 0);
        if (SUCCEEDED(hres)) {
            result = vtProp.ullVal;
            VariantClear(&vtProp);
        }

        pclsObj->Release();
    }

    // Step 8: Cleanup
    pSvc->Release();
    pLoc->Release();
    pEnumerator->Release();
    CoUninitialize();

    return result;
}

uint64_t get_Win32_PhysicalMemory_Uint64(const std::string &name) {
    uint64_t result = 0;

    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    std::wstring nameW = converter.from_bytes(name);

    HRESULT hres;

    // Step 1: Initialize COM library
    hres = CoInitializeEx(0, COINIT_MULTITHREADED);
    if (FAILED(hres)) {
        std::cerr << "Failed to initialize COM library. Error code: " << hres << std::endl;
        return 0;
    }

    // Step 2: Set security levels on the COM instance
    hres = CoInitializeSecurity(NULL,
                                -1,
                                NULL,
                                NULL,
                                RPC_C_AUTHN_LEVEL_DEFAULT,
                                RPC_C_IMP_LEVEL_IMPERSONATE,
                                NULL,
                                EOAC_NONE,
                                NULL);
    if (FAILED(hres)) {
        std::cerr << "Failed to initialize security. Error code: " << hres << std::endl;
        CoUninitialize();
        return 0;
    }

    // Step 3: Obtain the initial locator to WMI
    IWbemLocator *pLoc = NULL;
    hres = CoCreateInstance(CLSID_WbemLocator,
                            0,
                            CLSCTX_INPROC_SERVER,
                            IID_IWbemLocator,
                            (LPVOID *)&pLoc);
    if (FAILED(hres)) {
        std::cerr << "Failed to create IWbemLocator object. Error code: " << hres << std::endl;
        CoUninitialize();
        return 0;
    }

    // Step 4: Connect to WMI through the IWbemLocator::ConnectServer method
    IWbemServices *pSvc = NULL;
    hres = pLoc->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), NULL, NULL, 0, NULL, 0, 0, &pSvc);
    if (FAILED(hres)) {
        std::cerr << "Could not connect to WMI. Error code: " << hres << std::endl;
        pLoc->Release();
        CoUninitialize();
        return 0;
    }

    // Step 5: Set security levels on the proxy
    hres = CoSetProxyBlanket(pSvc,
                             RPC_C_AUTHN_WINNT,
                             RPC_C_AUTHZ_NONE,
                             NULL,
                             RPC_C_AUTHN_LEVEL_CALL,
                             RPC_C_IMP_LEVEL_IMPERSONATE,
                             NULL,
                             EOAC_NONE);
    if (FAILED(hres)) {
        std::cerr << "Could not set proxy blanket. Error code: " << hres << std::endl;
        pSvc->Release();
        pLoc->Release();
        CoUninitialize();
        return 0;
    }

    // Step 6: Use the IWbemServices pointer to make WMI queries
    IEnumWbemClassObject *pEnumerator = NULL;
    hres = pSvc->ExecQuery(bstr_t("WQL"),
                           bstr_t("SELECT * FROM Win32_PhysicalMemory"),
                           WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                           NULL,
                           &pEnumerator);
    if (FAILED(hres)) {
        std::cerr << "Query failed. Error code: " << hres << std::endl;
        pSvc->Release();
        pLoc->Release();
        CoUninitialize();
        return 0;
    }

    // Step 7: Retrieve the data from the query result
    IWbemClassObject *pclsObj = NULL;
    ULONG uReturn = 0;
    while (pEnumerator) {
        hres = pEnumerator->Next(WBEM_INFINITE, 1, &pclsObj, &uReturn);
        if (uReturn == 0) {
            break;
        }

        VARIANT vtProp;
        hres = pclsObj->Get(nameW.c_str(), 0, &vtProp, 0, 0);
        if (SUCCEEDED(hres)) {
            result = vtProp.ullVal;
            VariantClear(&vtProp);
        }

        pclsObj->Release();
    }

    // Step 8: Cleanup
    pSvc->Release();
    pLoc->Release();
    pEnumerator->Release();
    CoUninitialize();

    return result;
}

std::string vx::device::hardwareBrand() {
    static std::string value = get_Win32_ComputerSystem_String("Manufacturer");
    return value;
}

std::string vx::device::hardwareModel() {
    static std::string value = get_Win32_ComputerSystem_String("Model");
    return value;
}

std::string vx::device::hardwareProduct() {
    static std::string value = get_Win32_ComputerSystem_String("SystemSKUNumber");
    return value;
}

uint64_t vx::device::hardwareMemory() {
    static uint64_t value = get_Win32_ComputerSystem_Uint64("TotalPhysicalMemory");
    return value;
}

void vx::device::terminate() {
    PostQuitMessage(0);
}

bool vx::device::hasTouchScreen() {
    return false;
}

bool vx::device::hasMouseAndKeyboard() {
    return true;
}

bool vx::device::isMobile() {
    return false;
}

bool vx::device::isPC() {
    return true;
}

bool vx::device::isConsole() {
    return false;
}

void vx::device::setClipboardText(const std::string &text) {

    // convert UTF8 string to standard Windows UTF16 string
    // ----------------------------------------------------

    bool ok = OpenClipboard(nullptr);
    if (ok == false) {
        return;
    }

    ok = EmptyClipboard();
    if (ok == false) {
        return;
    }

    // with CP_UTF8, the second argument must be 0 for the function to succeed.
    const int wchars_count = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, NULL, 0);
    const SIZE_T byteCount = sizeof(TCHAR) * (wchars_count);

    // Allocate a global memory object for the text
    HGLOBAL hglbCopy = GlobalAlloc(GMEM_MOVEABLE, byteCount);
    if (hglbCopy == nullptr) {
        CloseClipboard();
        return;
    }

    // Lock the handle and copy the text to the buffer

    LPVOID lptstrCopy = GlobalLock(hglbCopy);
    if (lptstrCopy == nullptr) {
        CloseClipboard();
        return;
    }
    
    // 
    MultiByteToWideChar(CP_UTF8, 0, 
                        text.c_str(), -1, // -1 means the string is NULL-terminated
                        (LPWSTR)lptstrCopy, // destination pointer for the converted string
                        wchars_count);
    
    GlobalUnlock(hglbCopy);

    // Place the handle on the clipboard
    HANDLE dataHandle = SetClipboardData(CF_UNICODETEXT, hglbCopy);
    if (dataHandle == nullptr) {
        // error
        vxlog_error("Clipboard : SetClipboardData function failed");
        CloseClipboard();
        return;
    }
    
    ok = CloseClipboard();
    if (ok == false) {
        return;
    }
    return;
}

std::string vx::device::getClipboardText() {
    std::string text;

    // Check if clipboard contains data supported by Particubes
    const bool textDataAvailable = IsClipboardFormatAvailable(CF_TEXT);
    const bool unicodeTextDataAvailable = IsClipboardFormatAvailable(CF_UNICODETEXT);
    if (textDataAvailable == false && unicodeTextDataAvailable == false) {
        return text;
    }
    
    if (OpenClipboard(nullptr) == false) {
        return text;
    }

    if (unicodeTextDataAvailable) {

        HGLOBAL hglb = GetClipboardData(CF_UNICODETEXT);
        if (hglb != nullptr) {
            LPTSTR lptstr = (LPTSTR)GlobalLock(hglb);
            if (lptstr != nullptr) {

                const int size = WideCharToMultiByte(CP_UTF8, 0,
                    lptstr, -1, // -1 means lptstr is NULL-terminated
                    nullptr, 0, // means the func does a dry run and return the buffer size needed for the conversion
                    nullptr, nullptr);

                char* buf = (char*)malloc(size);
                if (buf != nullptr) {
                    WideCharToMultiByte(CP_UTF8, 0,
                        lptstr, -1, // -1 means lptstr is NULL-terminated
                        buf, size,
                        nullptr, nullptr);

                    text.assign(buf);
                    free(buf);
                }

                GlobalUnlock(hglb);
            }
        }

    } else if (textDataAvailable) {

        HGLOBAL hglb = GetClipboardData(CF_TEXT);
        if (hglb != nullptr) {
            LPTSTR lptstr = (LPTSTR)GlobalLock(hglb);
            if (lptstr != nullptr) {
                const char* c_str = reinterpret_cast<const char*>(lptstr);
                text.assign(c_str);
                GlobalUnlock(hglb);
            }
        }

    } else {
        vxlog_error("This should not happen (%s:%d)", __FILE_NAME__, __LINE__);
        return text;
    }
    
    CloseClipboard();
    
    return text;
}

/// Haptic feedback
void vx::device::hapticImpactLight() {}

void vx::device::hapticImpactMedium() {}

void vx::device::hapticImpactHeavy() {}

// Notifications

void vx::device::scheduleLocalNotification(const std::string &title,
                                           const std::string &body,
                                           const std::string &identifier,
                                           int days,
                                           int hours,
                                           int minutes,
                                           int seconds) {
    // local notifications not supported (yet?)
}

void vx::device::cancelLocalNotification(const std::string &identifier) {
    // local notifications not supported (yet?)
}

void vx::device::openApplicationSettings() {
    // NOT IMPLEMENTED YET
}

std::vector<std::string> vx::device::preferredLanguages() {

    std::vector<std::string> languages;

    DWORD bufferSize = 0;
    DWORD numLanguages = 0;

    // GetSystemPreferredUILanguages
    // GetUserPreferredUILanguages
    // GetProcessPreferredUILanguages
    /*bool ok =*/ GetUserPreferredUILanguages(MUI_LANGUAGE_NAME,
                                              &numLanguages,
                                              nullptr,
                                              &bufferSize);

    if (bufferSize > 0) {
        wchar_t *buffer = new wchar_t[bufferSize];
        if (GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, &numLanguages, buffer, &bufferSize)) {
            wchar_t *langPtr = buffer;
            for (DWORD i = 0; i < numLanguages; ++i) {
                // Convert wide character string to a regular string
                int length = WideCharToMultiByte(CP_UTF8,
                                                 0,
                                                 langPtr,
                                                 -1,
                                                 nullptr,
                                                 0,
                                                 nullptr,
                                                 nullptr);
                if (length > 0) {
                    std::string language(length, 0);
                    WideCharToMultiByte(CP_UTF8,
                                        0,
                                        langPtr,
                                        -1,
                                        &language[0],
                                        length,
                                        nullptr,
                                        nullptr);
                    languages.push_back(language);
                }
                langPtr += wcslen(langPtr) + 1; // Move to next language in buffer
            }
        }
        delete[] buffer;
    }

    if (languages.empty()) {
        // no preferred language found, let's default to english
        languages.push_back("en-US");
    }

    return languages;
}
