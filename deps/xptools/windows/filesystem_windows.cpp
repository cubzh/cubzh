//
//  filesystem_windows.cpp
//  xptools
//
//  Created by Gaetan de Villele on 04/03/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "filesystem.hpp"

// C++
#include <codecvt>
#include <sstream>
#include <thread>
#include <vector>
#include <stack>
#include <sstream>

// xptools
#include "vxlog.h"
#include "strings.hpp"

// windows
#include <windows.h>
#include <direct.h>
#include <fileapi.h>
#include <fstream>
#include <tchar.h>
#include <strsafe.h>
#include <ShObjIdl.h>
#include <atlbase.h>
#include <winnt.h>

#include "zlib.h"
#include "bundle_tar_gz.hpp" // variable in which the zipped file for the bundle is stored
// variables containing raw RGBA bytes for the icon
#include "icon_16.hpp"
#include "icon_32.hpp"
#include "icon_48.hpp"

#define TAR_FILE_TYPE_REGULAR '0'
#define TAR_FILE_TYPE_DIRECTORY '5'

#define LOG_COMPONENT "FILE_SYSTEM_WINDOWS"


// ------------------------------------ WINDOWS DIALOG ---------------------------------------

const COMDLG_FILTERSPEC c_rgSaveTypesPNG[] =
{
    {L"PNG Image (*.png)",  L"*.png"}
};

const COMDLG_FILTERSPEC c_rgSaveTypesPCUBES[] = 
{
    {L"pcubes file (*.pcubes)", L"*.pcubes"}
};

const COMDLG_FILTERSPEC c_rgSaveTypesCUBZH[] =
{
    {L"cubzh file (*.3zh)", L"*.3zh"}
};

const COMDLG_FILTERSPEC c_rgSaveTypesVOX[] = 
{
    {L"vox file (*.vox)", L"*.vox"}
};

const COMDLG_FILTERSPEC c_rgSaveTypesOBJ[] = 
{
    {L"obj file (*.obj)", L"*.obj"}
};

// Indices of file types (array starts at index 1)
#define INDEX_PNGFILETYPE 1

/* File Dialog Event Handler *****************************************************************************************************/

class CDialogEventHandler : public IFileDialogEvents,
    public IFileDialogControlEvents
{
public:
    // IUnknown methods
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv)
    {
        static const QITAB qit[] = {
            QITABENT(CDialogEventHandler, IFileDialogEvents),
            QITABENT(CDialogEventHandler, IFileDialogControlEvents),
            { 0 },
#pragma warning(suppress:4838)
        };
        return QISearch(this, qit, riid, ppv);
    }

    IFACEMETHODIMP_(ULONG) AddRef()
    {
        return InterlockedIncrement(&_cRef);
    }

    IFACEMETHODIMP_(ULONG) Release()
    {
        long cRef = InterlockedDecrement(&_cRef);
        if (!cRef)
            delete this;
        return cRef;
    }

    // IFileDialogEvents methods
    IFACEMETHODIMP OnFileOk(IFileDialog*) { return S_OK; };
    IFACEMETHODIMP OnFolderChange(IFileDialog*) { return S_OK; };
    IFACEMETHODIMP OnFolderChanging(IFileDialog*, IShellItem*) { return S_OK; };
    IFACEMETHODIMP OnHelp(IFileDialog*) { return S_OK; };
    IFACEMETHODIMP OnSelectionChange(IFileDialog*) { return S_OK; };
    IFACEMETHODIMP OnShareViolation(IFileDialog*, IShellItem*, FDE_SHAREVIOLATION_RESPONSE*) { return S_OK; };
    IFACEMETHODIMP OnTypeChange(IFileDialog* pfd);
    IFACEMETHODIMP OnOverwrite(IFileDialog*, IShellItem*, FDE_OVERWRITE_RESPONSE*) { return S_OK; };

    // IFileDialogControlEvents methods
    IFACEMETHODIMP OnItemSelected(IFileDialogCustomize* pfdc, DWORD dwIDCtl, DWORD dwIDItem);
    IFACEMETHODIMP OnButtonClicked(IFileDialogCustomize*, DWORD) { return S_OK; };
    IFACEMETHODIMP OnCheckButtonToggled(IFileDialogCustomize*, DWORD, BOOL) { return S_OK; };
    IFACEMETHODIMP OnControlActivating(IFileDialogCustomize*, DWORD) { return S_OK; };

    CDialogEventHandler() : _cRef(1) { };
private:
    ~CDialogEventHandler() { };
    long _cRef;
};

// IFileDialogEvents methods
// This method gets called when the file-type is changed (combo-box selection changes).
// For sample sake, let's react to this event by changing the properties show.
HRESULT CDialogEventHandler::OnTypeChange(IFileDialog* pfd)
{
    IFileSaveDialog* pfsd;
    HRESULT hr = pfd->QueryInterface(&pfsd);
    // ...
    return hr;
}

// IFileDialogControlEvents
// This method gets called when an dialog control item selection happens (radio-button selection. etc).
// For sample sake, let's react to this event by changing the dialog title.
HRESULT CDialogEventHandler::OnItemSelected(IFileDialogCustomize* pfdc, DWORD dwIDCtl, DWORD dwIDItem) {
    IFileDialog* pfd = NULL;
    HRESULT hr = pfdc->QueryInterface(&pfd);
    return hr;
}

// Instance creation helper
HRESULT CDialogEventHandler_CreateInstance(REFIID riid, void** ppv)
{
    *ppv = NULL;
    CDialogEventHandler* pDialogEventHandler = new (std::nothrow) CDialogEventHandler();
    HRESULT hr = pDialogEventHandler ? S_OK : E_OUTOFMEMORY;
    if (SUCCEEDED(hr))
    {
        hr = pDialogEventHandler->QueryInterface(riid, ppv);
        // ...
        pDialogEventHandler->Release();
    }
    return hr;
}

// -------------------------------------------------------------------------------------------

// --------------------------------------------------
// MARK: - Path separator -
// --------------------------------------------------

char vx::fs::getPathSeparator() {
    return '/';
}

std::string vx::fs::getPathSeparatorStr() {
    return "/";
}

// C symbols definition
extern "C" {

char c_getPathSeparator(void) {
    return '/';
}

const char *c_getPathSeparatorCStr(void) {
    return "/";
}

}

using namespace vx::fs;

// local functions' prototypes
static void _createDirectoryWithParentsW(const std::wstring &path);
static bool _createDirectoryWithParents(const std::string &path);
static std::vector<std::string> _splitString(const std::string &str, char delimiter);
static std::string _getAbsParticubesPath();
static std::string _getAbsStoragePath();
static std::string _getAbsBundlePath();
static void _copyFiles(const std::string &srcAbsPath,
                       const std::string &dstAbsPath);
// utility functions
static bool _fileExists(const std::string& absFilePath, bool& isDir);
static std::vector<std::string> _listDirectoryChildren(const std::string& absDirPath);
static bool _deleteRecursively(const std::string& absFilePath);

std::string vx::fs::getBundleFilePath(const std::string& relFilePath) {
    return _getAbsBundlePath() + "\\" + relFilePath;
}

/// Opens a file located in the bundle "assets" directory.
/// @param relFilePath relative path of a file in the bundle assets. It shouldn't start with a '/'.
FILE *vx::fs::openBundleFile(std::string relFilePath, std::string mode) {
    
    // construct the absolute path of the file
    const std::string absPath = vx::fs::getBundleFilePath(relFilePath);
    
    // normalize the path, to remove any . or .. element it may contain
    const std::string absPathNormalized = vx::fs::normalizePath(absPath);

    // make sure the normalized path targets a file *inside* the bundle directory
    if (vx::str::hasPrefix(absPathNormalized, _getAbsBundlePath()) == false) {
        // don't open files outside of the bundle directory
        return nullptr;
    }

    FILE *fd = nullptr;
    errno_t err = fopen_s(&fd, absPath.c_str(), mode.c_str());
    if (err != 0) {
        // try within storage (where we put dynamically loaded "bundle" files).
        return openStorageFile(std::string("bundle/") + relFilePath, mode);
    }
    return err == 0 ? fd : nullptr;
}

FILE *vx::fs::openFile(const std::string& filepath, const std::string& mode) {
    // Convert UTF-8 strings to "wide strings" so that `_wfopen` can use them.
    const std::wstring filepathW = std::wstring_convert<std::codecvt_utf8<wchar_t>>().from_bytes(filepath);
    const std::wstring modeW = std::wstring_convert<std::codecvt_utf8<wchar_t>>().from_bytes(mode);

    FILE *fd = nullptr;
    const errno_t err = _wfopen_s(&fd, filepathW.c_str(), modeW.c_str());
    return err == 0 ? fd : nullptr;
}

/// Use binary mode for non text files
FILE *vx::fs::openStorageFile(std::string relFilePath, std::string mode, size_t writeSize) {

    // construct the absolute path of the file
    const std::string storagePath = _getAbsStoragePath();
    const std::string absPath = storagePath + "\\" + relFilePath;

    // normalize the path, to remove any . or .. element it may contain
    const std::string absPathNormalized = vx::fs::normalizePath(absPath);

    // make sure the normalized path targets a file *inside* the storage directory
    if (vx::str::hasPrefix(absPathNormalized, storagePath) == false) {
        // don't open files outside of the storage directory
        return nullptr;
    }

    FILE *fd = nullptr;

    // create parent directories if missing when opening for writing
    const bool writing = (mode.size() > 0 && (mode.at(0) == 'w' || mode.at(0) == 'a'));
    if (writing) {
        std::vector<std::string> elements = _splitString(relFilePath, '/');
        if (elements.size() > 1) {
            // Create intermediate directories between storage dir and file to open. 
            // Remove last element which represent the file.
            elements.pop_back();
            std::string currentRelPath;
            std::string currentAbsPath;
            bool isDir = false;
            for (std::string const &element : elements) {
                // create the directory if it doesn't exist
                currentRelPath += "\\" + element;
                const bool exists = storageFileExists(currentRelPath, isDir);
                if (exists == false) {
                    currentAbsPath = storagePath + "\\" + currentRelPath;
                    // create directory
                    if (_mkdir(currentAbsPath.c_str()) != 0) {
                        // failure
                        vxlog_error("mkdir failed in storage (%s) (%s)", absPath.c_str(), currentRelPath.c_str());
                        return nullptr;
                    }
                } else if (isDir == false) {
                    vxlog_error("mkdir failed in storage: a parent directory exists but is a regular file. (%s) (%s)", absPath.c_str(), currentRelPath.c_str());
                    return nullptr;
                }
            }
        }
    }
    errno_t err = fopen_s(&fd, absPath.c_str(), mode.c_str());
    return err == 0 ? fd : nullptr;
}

std::vector<std::string> vx::fs::listStorageDirectory(const std::string& relStoragePath) {
    std::string absPath(_getAbsStoragePath() + "\\" + relStoragePath);
    std::vector<std::string> files;

    std::string strFilePath(absPath);
    std::string strPattern = absPath + "\\*.*";
    WIN32_FIND_DATAA FileInformation;

    HANDLE hFile = ::FindFirstFileA(strPattern.c_str(), &FileInformation);
    if (hFile != INVALID_HANDLE_VALUE) {
        do {
            // filter out "." and ".."
            if (strcmp(FileInformation.cFileName, ".") == 0 ||
                strcmp(FileInformation.cFileName, "..") == 0) {
                continue;
            }

            strFilePath = relStoragePath + "\\" + FileInformation.cFileName;
            files.push_back(strFilePath);
        } while (::FindNextFileA(hFile, &FileInformation) == TRUE);

        // Close handle
        ::FindClose(hFile);

        DWORD dwError = ::GetLastError();
        if (dwError != ERROR_NO_MORE_FILES) {
            vxlog_error("Error in listStorageDirectory");
            return files;
        }
    }

    return files;
}

void vx::fs::importFile(ImportFileCallback callback) {
    std::thread importThread([callback]() {
        void *fileBytes = nullptr;
        size_t len = 0;
        std::string path("");
        
        IFileDialog* pfd = NULL;
        HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        if (SUCCEEDED(hr) == false) {
            callback(nullptr, 0, ImportFileCallbackStatus::ERROR_IMPORT);
            return;
        }
        
        // CoCreate the File Open Dialog object.
        hr = CoCreateInstance(CLSID_FileOpenDialog,
                              nullptr,
                              CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&pfd));
        if (SUCCEEDED(hr) == false) {
            pfd->Release();
            callback(nullptr, 0, ImportFileCallbackStatus::ERROR_IMPORT);
            return;
        }
        
        // Create an event handling object, and hook it up to the dialog.
        IFileDialogEvents* pfde = NULL;
        hr = CDialogEventHandler_CreateInstance(IID_PPV_ARGS(&pfde));
        if (SUCCEEDED(hr) == false) {
            pfd->Release();
            callback(nullptr, 0, ImportFileCallbackStatus::ERROR_IMPORT);
            return;
        }

        // Show the dialog
        hr = pfd->Show(NULL);
        if (SUCCEEDED(hr) == false) {
            // the user cancelled in the system window
            pfde->Release();
            pfd->Release();
            callback(nullptr, 0, ImportFileCallbackStatus::CANCELLED);
            return;
        }

        // Obtain the result once the user clicks
        // the 'Open' button.
        // The result is an IShellItem object.
        IShellItem *psiResult;
        hr = pfd->GetResult(&psiResult);
        if (SUCCEEDED(hr) == false) {
            pfde->Release();
            pfd->Release();
            callback(nullptr, 0, ImportFileCallbackStatus::ERROR_IMPORT);
            return;
        }

        // get the result
        LPTSTR pszFilePath;
        hr = psiResult->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);
        if (SUCCEEDED(hr) == false) {
            psiResult->Release();
            pfde->Release();
            pfd->Release();
            callback(nullptr, 0, ImportFileCallbackStatus::ERROR_IMPORT);
            return;
        }

        const int pathSize = WideCharToMultiByte(CP_UTF8, 0,
                                                 pszFilePath, -1,
                                                 nullptr, 0,
                                                 nullptr, nullptr);
        
        char *buf = static_cast<char *>(malloc(pathSize));
        if (buf == nullptr) {
            CoTaskMemFree(pszFilePath);
            psiResult->Release();
            pfde->Release();
            pfd->Release();
            callback(nullptr, 0, ImportFileCallbackStatus::ERROR_IMPORT);
            return;
        }

        WideCharToMultiByte(CP_UTF8, 0,
                            pszFilePath, -1,
                            buf, pathSize,
                            nullptr, nullptr);
        
        path.assign(buf);
        free(buf);
        FILE *selectedFile = openFile(path);
        if (selectedFile == nullptr) {
            CoTaskMemFree(pszFilePath);
            psiResult->Release();
            pfde->Release();
            pfd->Release();
            callback(nullptr, 0, ImportFileCallbackStatus::ERROR_IMPORT);
            return;
        }
        
        // get the file's length
        fseek(selectedFile, 0, SEEK_END);
        len = static_cast<size_t>(ftell(selectedFile));
        
        // go back to the beginning of file
        fseek(selectedFile, 0, SEEK_SET);
        // alloc memory buffer and fill it with content of file
        fileBytes = static_cast<void *>(malloc(len * sizeof(uint8_t)));
        fread(fileBytes, sizeof(uint8_t), len, selectedFile);
        // close file
        fclose(selectedFile);
        
        CoTaskMemFree(pszFilePath);
        psiResult->Release();
        pfde->Release();
        pfd->Release();
        
        callback(fileBytes, len, ImportFileCallbackStatus::OK);
        return;
    });

    importThread.detach();
}

///
bool vx::fs::removeStorageFileOrDirectory(std::string relFilePath) {
    std::string absPath = _getAbsStoragePath() + "\\" + relFilePath;
    bool isDir = false;

    const bool exists = _fileExists(absPath, isDir);
    if (exists == false) {
        return false;
    }

    if (isDir) {
        return RemoveDirectoryA(absPath.c_str());
    }
    return remove(absPath.c_str()) == 0;
}

///
bool vx::fs::bundleFileExists(const std::string &relFilePath, bool &isDir) {
    // construct file absolute path
    const std::string absFilePath = _getAbsBundlePath() + "\\" + relFilePath;
    // check if file exists
    struct stat buffer;
    const int status = stat(absFilePath.c_str(), &buffer); // success if 0
    if (status == 0) {
        // file exists
        isDir = (((buffer.st_mode) & S_IFMT) == S_IFDIR);
        return true;
    }
    return false;
}

///
bool vx::fs::storageFileExists(const std::string &relFilePath, bool &isDir) {
    // construct file absolute path
    const std::string absFilePath = _getAbsStoragePath() + "\\" + relFilePath;
    // check if file exists
    struct stat buffer;
    const int status = stat(absFilePath.c_str(), &buffer); // success if 0
    if (status == 0) {
        // file exists
        isDir = (((buffer.st_mode)& S_IFMT) == S_IFDIR);
        return true;
    }
    return false;
}

/// Merges content of bundle directory into cache directory.
/// Overriding existing cache files if found.
bool vx::fs::mergeBundleDirInStorage(const std::string &bundleDir, const std::string &storageDir) {
    const std::string absBundleDir = _getAbsBundlePath() + "\\" + bundleDir;
    const std::string absStorageDir = _getAbsStoragePath() + "\\" + storageDir;

    bool isDirectory = false;
    bool fileExists = false;
        
    fileExists = bundleFileExists(bundleDir, isDirectory);
    if (isDirectory == false || fileExists == false) {
        return false;
    }

    fileExists = storageFileExists(storageDir, isDirectory);
    if (fileExists == false) {
        const bool ok = _createDirectoryWithParents(absStorageDir);
        if (ok == false) {
            return false;
        }
    } else if (isDirectory == false) {
        return false;
    }

    bool ok = _createDirectoryWithParents(absBundleDir);
    if (ok == false) {
        return false;
    }

    // Loop over files in absBundleDir and copy them into absStorageDir
    // We ignore directories, and only copy top level regular files.
    WIN32_FIND_DATAA FindFileData;
    HANDLE hFind;

    const std::string searchedPath = absBundleDir + "/*";
    hFind = FindFirstFileA(searchedPath.c_str(), &FindFileData);
    if (hFind == INVALID_HANDLE_VALUE) {
        vxlog_error("FindFirstFile failed (%d)", GetLastError());
        return false;
    }

    ok = false;
    while (true) {
        if (strcmp(FindFileData.cFileName, ".") != 0 &&
            strcmp(FindFileData.cFileName, "..") != 0) {
            const std::string relFilename = std::string(FindFileData.cFileName);
            const std::string sourcePath = absBundleDir + "\\" + relFilename;
            const std::string destPath = absStorageDir + "\\" + relFilename;
            vxlog_error(">>> COPY FILE : %s %s", sourcePath.c_str(), destPath.c_str());
            _copyFiles(sourcePath, destPath);
        }

        ok = FindNextFileA(hFind, &FindFileData);
        if (ok == false) {
            break;
        }
    }    
    FindClose(hFind);

    return true;
}

/// show a file picker for uploading a thumbnail
void vx::fs::pickThumbnail(std::function<void(FILE* thumbnail)> callback) {
    // TODO: implement
    callback(nullptr);
}

void vx::fs::shareFile(const std::string& filepath,
                       const std::string& title,
                       const std::string& filename,
                       const FileType type) {

    // CoCreate the File Open Dialog object.
    IFileDialog* pfd = NULL;
    HRESULT hr = CoCreateInstance(CLSID_FileSaveDialog,
        NULL,
        CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&pfd));

    if (SUCCEEDED(hr)) {
        // Create an event handling object, and hook it up to the dialog.
        IFileDialogEvents* pfde = NULL;
        hr = CDialogEventHandler_CreateInstance(IID_PPV_ARGS(&pfde));
        if (SUCCEEDED(hr)) {
            // Hook up the event handler.
            DWORD dwCookie;
            hr = pfd->Advise(pfde, &dwCookie);
            if (SUCCEEDED(hr)) {
                // Set the options on the dialog.
                DWORD dwFlags;

                // Before setting, always get the options first in order 
                // not to override existing options.
                hr = pfd->GetOptions(&dwFlags);
                if (SUCCEEDED(hr)) {
                    // In this case, get shell items only for file system items.
                    hr = pfd->SetOptions(dwFlags | FOS_FORCEFILESYSTEM);
                    if (SUCCEEDED(hr)) {
                        // Set the types of files that will be saved
                        switch (type) {
                        case FileType::PNG:
                            hr = pfd->SetFileTypes(ARRAYSIZE(c_rgSaveTypesPNG), c_rgSaveTypesPNG);
                            break;
                        case FileType::PCUBES:
                            hr = pfd->SetFileTypes(ARRAYSIZE(c_rgSaveTypesPCUBES), c_rgSaveTypesPCUBES);
                            break;
                        case FileType::CUBZH:
                            hr = pfd->SetFileTypes(ARRAYSIZE(c_rgSaveTypesCUBZH), c_rgSaveTypesCUBZH);
                            break;
                        case FileType::VOX:
                            hr = pfd->SetFileTypes(ARRAYSIZE(c_rgSaveTypesVOX), c_rgSaveTypesVOX);
                            break;
                        case FileType::OBJ:
                            hr = pfd->SetFileTypes(ARRAYSIZE(c_rgSaveTypesOBJ), c_rgSaveTypesOBJ);
                            break;
                        }
                        if (SUCCEEDED(hr)) {
                            // the selected index is always the first one
                            hr = pfd->SetFileTypeIndex(1);
                            if (SUCCEEDED(hr)) {

                                hr = pfd->SetFileName(std::wstring(filename.begin(), filename.end()).c_str());
                                if (FAILED(hr)) {
                                    return;
                                }

                                // Set the default extension.
                                switch (type) {
                                case FileType::PNG:
                                    hr = pfd->SetDefaultExtension(L"png");
                                    break;
                                case FileType::PCUBES:
                                    hr = pfd->SetDefaultExtension(L"pcubes");
                                    break;
                                case FileType::CUBZH:
                                    hr = pfd->SetDefaultExtension(L"3zh");
                                    break;
                                case FileType::VOX:
                                    hr = pfd->SetDefaultExtension(L"vox");
                                    break;
                                case FileType::OBJ:
                                    hr = pfd->SetDefaultExtension(L"obj");
                                    break;
                                }

                                if (SUCCEEDED(hr)) {
                                    // Show the dialog
                                    hr = pfd->Show(NULL);
                                    if (SUCCEEDED(hr)) {
                                        // Obtain the result once the user clicks 
                                        // the 'Open' button.
                                        // The result is an IShellItem object.
                                        IShellItem* psiResult;
                                        hr = pfd->GetResult(&psiResult);
                                        if (SUCCEEDED(hr)) {
                                            // We are just going to print out the 
                                            // name of the file for sample sake.
                                            wchar_t* pszFilePath = NULL;
                                            hr = psiResult->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);
                                            if (SUCCEEDED(hr)) {                                                
                                                const std::string srcFullpath = _getAbsStoragePath() + "\\" + filepath; 
                                                // copy
                                                std::ifstream src(srcFullpath, std::ios::binary);
                                                std::ofstream dst(std::wstring(pszFilePath), std::ios::binary);
                                                dst << src.rdbuf();

                                                CoTaskMemFree(pszFilePath);
                                            }
                                            psiResult->Release();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // Unhook the event handler.
                pfd->Unadvise(dwCookie);
            }
            pfde->Release();
        }
        pfd->Release();
    }
}

#define CHUNK 16384 // 32768 is possible also apparently
#define ENABLE_ZLIB_GZIP 16

/// 
bool vx::fs::unzipBundle() {

    vxlog_info(">>> Unzipping bundle...");

    // Making sure the bundle directory is ready for receiving the bundle files
    // --------------------------------------------------
    
    // Delete the existing installed bundle if there is any
    // (and its children files/directories)
    bool ok = _deleteRecursively(_getAbsBundlePath());
    vxlog_debug(">>> deleting existing bundle... %s", ok ? "SUCCESS" : "FAILED");
    if (ok == false) {
        return false;
    }

    ok = _createDirectoryWithParents(_getAbsBundlePath());
    vxlog_debug(">>> re-creating bundle directory... %s", ok ? "SUCCESS" : "FAILED");
    if (ok == false) {
        return false;
    }
    
    // TAR    : 6 279 680 bytes
    // TAR.GZ : 2 574 005 bytes
    
    // IN DATA
    const uLong inDataSize = sizeof(bundle_tar_gz);
    Bytef *inData = (Bytef *)bundle_tar_gz;
    const uint32_t inDataSizeUncompressed = *((uint32_t*)(inData + inDataSize - 4));

    // OUT DATA
    Bytef *outData = (Bytef *)malloc(inDataSizeUncompressed * sizeof(Bytef));
    if (outData == nullptr) {
        vxlog_error("[ERROR] failed to allocate buffer to uncompress bundle");
        return false;
    }
    // fill outData with zeros
    for (uint32_t i = 0; i < inDataSizeUncompressed; ++i) {
        outData[i] = 0;
    }
    uint32_t outDataBytesWritten = 0;
    
    // counting the bytes that have been read in the inData buffer 
    uint32_t inDataBytesRead = 0;
    
    z_stream strm = {0};
    unsigned char in[CHUNK];
    unsigned char out[CHUNK];

    // allocate inflate state
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.next_in = in;
    strm.avail_in = 0;
    const int status = inflateInit2(&strm, MAX_WBITS + ENABLE_ZLIB_GZIP);
    if (status != Z_OK) {
        vxlog_error(">>> [ERROR] failed to init zlib decompression");
        free(outData);
        return false;
    }
    
    while (true) {
        int zlib_status;
        
        const int bytesToRead = min((inDataSize - inDataBytesRead), CHUNK);
        memcpy(in, inData + inDataBytesRead, bytesToRead); // TODO: check for error
        inDataBytesRead += bytesToRead;

        strm.avail_in = bytesToRead;
        strm.next_in = in;
        do {
            unsigned have;
            strm.avail_out = CHUNK;
            strm.next_out = out;
            zlib_status = inflate(&strm, Z_NO_FLUSH);
            switch (zlib_status) {
            case Z_OK:
            case Z_STREAM_END:
            case Z_BUF_ERROR:
                break;

            default:
                inflateEnd(&strm);
                vxlog_error("    -> Gzip error %d in '%s'.\n", zlib_status, "bundle_tar_gz");
                free(outData);
                return false;
            }
            have = CHUNK - strm.avail_out;
            // <have> in the number of bytes having been writter in the <out> buffer
            memcpy(outData + outDataBytesWritten, out, have); // TODO: check for error
            outDataBytesWritten += have;
        } while (strm.avail_out == 0);

        if (inDataBytesRead == inDataSize) {
            inflateEnd(&strm);
            break;
        }
    }
    // Now we have the tar bytes in <outData>.
    
    // Extract files from TAR archive
    uint32_t cursor = 0; // cursor for parsing the tar bytes
    while (true) {
        // char* nextChar = (char*)(outData + cursor);
        if (cursor >= outDataBytesWritten ||
            *((const char*)outData + cursor) == 0) { // if first char of next file's name is 0, then it's the end of the tar (no more files)
            break;
        }
        
        // vxlog(LOG_SEVERITY_TRACE, LOG_COMPONENT, ">>> extracting file...");

        const std::string filename((const char*)(outData + cursor), 100);
        // vxlog_trace(">>> file name %s", filename.c_str());
        const std::string filesizeOctalStr((const char *)(outData + cursor + 124), 12);
        // vxlog_trace(">>> file size (octal string) %s", filesizeOctalStr.c_str());
        const int filesize = std::stoul(filesizeOctalStr, nullptr, 8);
        // vxlog_trace(">>> file size (decimal int) %d", filesize);
        char filetype = *((const char*)(outData + cursor + 156));
        // vxlog_trace(">>> file type %c", filetype);
        cursor += 512;

        if (filetype == TAR_FILE_TYPE_REGULAR) {
            int remainingFileBytes = filesize;
            const std::string absPath = _getAbsBundlePath() + "\\" + filename;
            // vxlog(LOG_SEVERITY_TRACE, LOG_COMPONENT, ">>> destination file abs path: %s", absPath.c_str());
            FILE *fd = nullptr;
            errno_t err = fopen_s(&fd, absPath.c_str(), "wb"); // TODO: check error
            if (fd != nullptr) {
                while (remainingFileBytes > 0) {
                    // read a block of 512 bytes
                    const int bytesToCopy = min(512, remainingFileBytes);
                    fwrite((outData + cursor), 1, bytesToCopy, fd);
                    cursor += 512;
                    remainingFileBytes -= 512;
                }
                fclose(fd);
            } else {
                vxlog_error("[ERROR] failed to open file %s", absPath.c_str());
            }

        } else if (filetype == TAR_FILE_TYPE_DIRECTORY) {
            // TODO: maybe remove trailing '/' from filename
            const std::string absPath = _getAbsBundlePath() + "\\" + filename;
            const bool ok = _createDirectoryWithParents(absPath);
        }        
    }

    free(outData);

    return true;
}

///
bool vx::fs::removeStorageFilesWithPrefix(const std::string& directory, const std::string& prefix) {
    if (prefix.empty()) {
        return false;
    }
    bool success = true;

    // storage directory path
    const std::string storagePath = _getAbsStoragePath();
    const std::string absStorageDir = storagePath + "\\" + directory;
    
    // enumerate files located in directory
    std::vector<std::string> children = _listDirectoryChildren(absStorageDir);
    for (std::string childName : children) {
        const std::string childAbsPath = absStorageDir + "\\" + childName;
        bool isDirectory = false;
        const bool fileExists = _fileExists(childAbsPath, isDirectory);
        if (fileExists == false || isDirectory == true) {
            continue;
        }
        if (childName.find(prefix) == 0) {
            if (DeleteFileA(childAbsPath.c_str()) == false) {
                success = false;
            }
        }
    }
    return success;
}

/// returns the raw bytes of the 16x16 icon's pixels
unsigned char *vx::fs::getIcon16Pixels() {
    return (unsigned char *)icon_16;
}

/// returns the raw bytes of the 32x32 icon's pixels
unsigned char *vx::fs::getIcon32Pixels() {
    return (unsigned char *)icon_32;
}

/// returns the raw bytes of the 48x48 icon's pixels
unsigned char *vx::fs::getIcon48Pixels() {
    return (unsigned char *)icon_48;
}

std::string vx::fs::normalizePath(const std::string &path) {
    std::stack<std::string> dirStack;
    std::vector<std::string> parts;
    std::stringstream ss(path);
    std::string item;
    bool isAbsolutePath = false;

    // Determine if the path is absolute
    if (path.length() > 2 && path[1] == ':' && path[2] == '\\') {
        isAbsolutePath = true;
        dirStack.push(path.substr(0, 3)); // Push the drive letter and root
        ss.seekg(3);                      // Start parsing after the drive letter
    } else if (path.length() > 0 && path[0] == '\\') {
        isAbsolutePath = true;
        dirStack.push("\\");
        ss.seekg(1); // Start parsing after the leading backslash
    }

    // Split the path by '\'
    while (std::getline(ss, item, '\\')) {
        if (item == "" || item == ".") {
            // Skip empty and current directory elements
            continue;
        }
        if (item == "..") {
            if (!dirStack.empty() && dirStack.top() != "\\" &&
                !(dirStack.size() == 1 && dirStack.top().length() == 3)) {
                dirStack.pop();
            }
        } else {
            dirStack.push(item);
        }
    }

    // Reconstruct the normalized path
    std::vector<std::string> result;
    while (!dirStack.empty()) {
        result.push_back(dirStack.top());
        dirStack.pop();
    }
    std::reverse(result.begin(), result.end());

    std::string normalizedPath;
    for (const auto &part : result) {
        normalizedPath += part;
        if (&part != &result.back() && part != "\\" && !(part.length() == 3 && part[1] == ':')) {
            normalizedPath += "\\";
        }
    }

    return normalizedPath;
}

// ------------------------------
// Helper
// ------------------------------

bool vx::fs::Helper::setInMemoryStorage(bool b) {
    // in memory storage not allowed on Windows for now
    return false;
}



// --------------------------------------------------
//
// MARK: - Local functions -
//
// --------------------------------------------------

// function done by danzek: https://gist.github.com/danzek
static void _createDirectoryWithParentsW(const std::wstring &path) {
    static const std::wstring separators(L"\\/");

    // If the specified directory name doesn't exist, do our thing
    DWORD fileAttributes = ::GetFileAttributesW(path.c_str());
    if (fileAttributes == INVALID_FILE_ATTRIBUTES) {

        // Recursively do it all again for the parent directory, if any
        std::size_t slashIndex = path.find_last_of(separators);
        if (slashIndex != std::wstring::npos) {
            _createDirectoryWithParentsW(path.substr(0, slashIndex));
        }

        // Create the last directory on the path (the recursive calls will have
        // taken care of the parent directories by now)
        BOOL result = ::CreateDirectoryW(path.c_str(), nullptr);
        if (result == FALSE) {
            throw std::runtime_error("Could not create directory");
        }

    }
    else { // Specified directory name already exists as a file or directory

        bool isDirectoryOrJunction =
            ((fileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) ||
            ((fileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0);

        if (!isDirectoryOrJunction) {
            throw std::runtime_error("Could not create directory because a "
                "file with the same name exists");
        }
    }
}

///
static bool _createDirectoryWithParents(const std::string &path) {
    static const std::string separators("\\/");

    // If the specified directory name doesn't exist, do our thing
    DWORD fileAttributes = ::GetFileAttributesA(path.c_str());
    if (fileAttributes == INVALID_FILE_ATTRIBUTES) {

        // Recursively do it all again for the parent directory, if any
        std::size_t slashIndex = path.find_last_of(separators);
        if (slashIndex != std::wstring::npos) {
            const bool ok = _createDirectoryWithParents(path.substr(0, slashIndex));
            if (ok == false) {
                vxlog_debug("failed to create directory %s", path.substr(0, slashIndex).c_str());
            }
        }

        // Create the last directory on the path (the recursive calls will have
        // taken care of the parent directories by now)
        const bool result = ::CreateDirectoryA(path.c_str(), nullptr);
        if (result == FALSE) {
            // failed to create directory
            return false;
        }

    } else { // Specified directory name already exists as a file or directory

        bool isDirectoryOrJunction =
            ((fileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) ||
            ((fileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0);

        if (isDirectoryOrJunction == false) {
            // failed to create directory
            return false;
        }
    }
    return true;
}

/// Splits string inside a vector buffer
std::vector<std::string> _splitString(const std::string &str, char delimiter) {
    std::vector<std::string> tokens;
    std::string token;
    std::istringstream tokenStream(str);
    while (std::getline(tokenStream, token, delimiter)) {
        tokens.push_back(token);
    }
    return tokens;
}

static std::string _getAbsParticubesPath() {
    static const CHAR appDataPath[] = "appdata";
    // static const CHAR appDataPath[] = "LOCALAPPDATA";
    CHAR path[MAX_PATH];
    std::string fullPath = "";

    if (GetEnvironmentVariableA(appDataPath, path, MAX_PATH)) {
        fullPath = path;
        fullPath = fullPath + "\\Voxowl\\Particubes";
        return fullPath;
    }
    else {
        vxlog_error("Failed to find the user's Roaming folder");
    }
    return "";
}

static std::string _getAbsStoragePath() {
    return _getAbsParticubesPath() + "\\storage";
}

static std::string _getAbsBundlePath() {
    return _getAbsParticubesPath() + "\\bundle";
}

static void _copyFiles(const std::string &srcAbsPath,
                       const std::string &dstAbsPath) {

    // detects if src is a directory
    DWORD fileAttributes = ::GetFileAttributesA(srcAbsPath.c_str());
    const bool isDir = (fileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;

    if (isDir == true) {

        _createDirectoryWithParents(dstAbsPath);

        // lists content of directory
        // for each item , calls _copyFiles(item, dest)
        WIN32_FIND_DATAA FindFileData;
        HANDLE hFind;

        const std::string searchedPath = srcAbsPath + "/*";
        hFind = FindFirstFileA(searchedPath.c_str(), &FindFileData);
        if (hFind == INVALID_HANDLE_VALUE) {
            vxlog_error("FindFirstFile failed (%d)", GetLastError());
            return;
        }

        bool ok = false;
        while (true) {
            if (strcmp(FindFileData.cFileName, ".") != 0 &&
                strcmp(FindFileData.cFileName, "..") != 0) {
                const std::string relFilename = std::string(FindFileData.cFileName);
                _copyFiles(srcAbsPath + "\\" + relFilename,
                           dstAbsPath + "\\" + relFilename);
            }

            ok = FindNextFileA(hFind, &FindFileData);
            if (ok == false) {
                break;
            }
        }
        FindClose(hFind);

    } else {
        // regular file
        if (CopyFileA((LPCSTR)srcAbsPath.c_str(), (LPCSTR)dstAbsPath.c_str(), true) == false) {
            vxlog_error("%d", GetLastError());
        }
    }
}

// --------------------------------------------------
//
// Utility functions
//
// --------------------------------------------------


///
bool _fileExists(const std::string &absFilePath, bool &isDir) {
    // check if file exists
    struct stat buffer;
    const int status = stat(absFilePath.c_str(), &buffer); // success if 0
    if (status == 0) {
        // file exists
        isDir = (((buffer.st_mode) & S_IFMT) == S_IFDIR);
        return true;
    }
    return false;
}

/// returns the names of the children, not their full absolute paths
std::vector<std::string> _listDirectoryChildren(const std::string &absDirPath) {
    std::vector<std::string> result;

    // lists content of directory
        // for each item , calls _copyFiles(item, dest)
    WIN32_FIND_DATAA FindFileData;
    HANDLE hFind;

    const std::string searchedPath = absDirPath + "/*";
    hFind = FindFirstFileA(searchedPath.c_str(), &FindFileData);
    if (hFind == INVALID_HANDLE_VALUE) {
        vxlog_error("FindFirstFile failed (%d)", GetLastError());
        return result;
    }

    bool ok = false;
    while (true) {
        if (strcmp(FindFileData.cFileName, ".") != 0 &&
            strcmp(FindFileData.cFileName, "..") != 0) {
            result.push_back(std::string(FindFileData.cFileName));
        }

        ok = FindNextFileA(hFind, &FindFileData);
        if (ok == false) {
            break;
        }
    }
    FindClose(hFind);
    return result;
}

/// 
static bool _deleteRecursively(const std::string &absFilePath) {
    bool isDir = false;
    const bool exists = _fileExists(absFilePath, isDir);
    if (exists == false) {
        return true; // success
    }
    // file exists
    if (isDir == true) {
        // directory
        // deleting all its children first
        std::vector<std::string> children = _listDirectoryChildren(absFilePath);
        for (std::string childName : children) {
            const std::string childAbsPath = absFilePath + "\\" + childName;
            const bool ok = _deleteRecursively(childAbsPath);
            if (ok == false) {
                vxlog_error("[ERROR] failed to delete %s", childAbsPath.c_str());
                break;
            }
        }
        // them delete the directory itself
        return RemoveDirectoryA(absFilePath.c_str());

    } else {
        // regular file
        return DeleteFileA(absFilePath.c_str());
    }
}
