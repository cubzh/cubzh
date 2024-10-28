
//
// filesystem_web.cpp
// xptools
//

#include "filesystem.hpp"

// C
#include <sys/stat.h>
#include <dirent.h>

// C++
#include <cassert>
#include <cerrno>
#include <list>
#include <vector>
#include <sstream>

// xptools
#include "xptools.h"

// emscripten
#include <emscripten.h>

using namespace vx::fs;

// Constants
static const std::string BundleDirectoryName = "/bundle";
static const std::string StorageDirectoryName = "/storage";
static const int FileCopyBufferSize = 255;

// Variables
static ImportFileCallback currentCallback;

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

// --------------------------------------------------
// MARK: - Emscripten bindings -
// --------------------------------------------------

extern "C" {
    EMSCRIPTEN_KEEPALIVE
    extern int importCCallback(uint8_t *bytes, size_t len, int status) {
        // call currentCallback with corresponding status
        switch (status) {
            case 0: // OK
                currentCallback((void*)bytes, len, ImportFileCallbackStatus::OK);
                break;
            case 2: // CANCELLED
                currentCallback((void*)bytes, len, ImportFileCallbackStatus::CANCELLED);
                break;
            case 1:
            default:
                currentCallback((void*)bytes, len, ImportFileCallbackStatus::ERROR_IMPORT);
                break;
        }
        return 0;
    }
}

EM_JS(void, js_fs_import_file, (), {
    // create a file input
    let input = document.createElement('input');
    input.type = 'file';
    let fileSelected = false;
    
    // function triggered when going back to the main page
    document.body.onfocus = function() {
        document.body.onfocus = null;

        // delay so that it is called after input.onchange
        setTimeout (function(){
            if (fileSelected == false) {
                const statusCANCELLED = 2;
                Module.ccall('importCCallback', 'number', ['array', 'number', 'number'], [[], 0, statusCANCELLED]);
            }
        }, 500);
    };

    // function triggered when a file is selected
    input.onchange = function() {
        fileSelected = true;

        const statusOK = 0;
        const statusERROR = 1;
        const statusCANCELLED = 2;
        let file = input.files[0];
        let reader = new FileReader();

        // read the file
        reader.readAsArrayBuffer(file);

        // function called once the reader has read the whole file
        reader.onloadend = function(evt) {
            if (evt.target.readyState != FileReader.DONE) {
                // the file has not been read completely
                Module.ccall('importCCallback', 'number', ['array', 'number', 'number'], [[], 0, statusERROR]);
                return;
            }

            // get the result in an uint8 array
            let bytes = new Uint8Array(evt.target.result);

            // call the function with the acquired data
            Module.ccall('importCCallback',                 // name of C function
                         'number',                          // return type
                         ['array', 'number', 'number'],     // arguments' types
                         [bytes, bytes.length, statusOK]);  // arguments' values
        };
    };

    // activate it
    input.click();
});

EM_JS(void, js_fs_share_file, (const char *filePath, const char *fileName, const char *mimeType), {
    let jsFilePath = UTF8ToString(filePath);
    let jsFileName = UTF8ToString(fileName);
    let jsMimeType = UTF8ToString(mimeType);

    // add storage to the path
    jsFilePath = '/storage/' + jsFilePath;
    
    // read the file and store it in an uint8 array
    let bytes = FS.readFile(jsFilePath, { encoding: 'binary', flags: 'r' });

    // create download element
    let element = document.createElement('a');
    // bind the bytes to the data
    element.setAttribute('href', 'data:' + jsMimeType + ';base64,' + btoa(String.fromCharCode.apply(null, bytes)));
    element.setAttribute('download', jsFileName);

    element.style.display = 'none';
    document.body.appendChild(element);
    // activate the download
    element.click();
    document.body.removeChild(element);
});

// --------------------------------------------------
// MARK: - Unexposed functions -
// --------------------------------------------------

/// Converts bundle relative path into FS absolute path.
static std::string _getAbsBundlePath(const std::string& relPath) {
    std::string result = BundleDirectoryName;
    if (*(relPath.cbegin()) != '/') {
        result += "/";
    }
    return result + relPath;
}

/// Converts storage relative path into FS absolute path.
static std::string _getAbsStoragePath(const std::string& relPath) {
    std::string result = StorageDirectoryName;
    if (*(relPath.cbegin()) != '/') {
        result += "/";
    }
    return result + relPath;
}

static bool _createDirectoryWithParents(const std::string &path) {
    static const std::string separators("/");

    // If the specified directory name doesn't exist, do our thing
    struct stat stat_buf;
    const bool fileExists = stat(path.c_str(), &stat_buf) == 0;
    const bool isDir = (stat_buf.st_mode & S_IFMT) == S_IFDIR;

    if (fileExists == false) {

        // Recursively do it all again for the parent directory, if any
        std::size_t slashIndex = path.find_last_of(separators);
        if (slashIndex != std::wstring::npos) {
            const bool ok = _createDirectoryWithParents(path.substr(0, slashIndex));
            if (ok == false) {
                printf("failed to create directory %s\n", path.substr(0, slashIndex).c_str());
            }
        }

        // Create the last directory on the path (the recursive calls will have
        // taken care of the parent directories by now)
        const int result = mkdir(path.c_str(), 0777); // mkdir returns 0 on success
        if (result != 0) {
            // failed to create directory
            return false;
        }

    } else { // Specified directory name already exists as a file or directory
        if (isDir == false) {
            // failed to create directory
            return false;
        }
    }
    return true;
}

/// Create directory and all its parents in storage.
/// Returns true on success, false otherwise.
static bool _createDirectoriesInStorage(const std::string& relDirPath) {
    std::vector<std::string> dirs;
    std::istringstream iss(relDirPath);
    std::string dir;

    while (std::getline(iss, dir, '/')) {
        if (!dir.empty()) {
            dirs.push_back(dir);
        }
    }
    
    // create directories in order
    std::string currPath;
    for (const auto& dir : dirs) {
        currPath += "/" + dir;
        // check if directory exists
        {
            bool isDir = false;
            const bool exists = vx::fs::storageFileExists(currPath, isDir);
            if (exists) {
                if (isDir) {
                    continue;
                } 
                printf("Failed to create directory (file with same name exists): %s\n", currPath.c_str());
                return false;
            }
        }
        // create directory
        const std::string& absPath = _getAbsStoragePath(currPath);
        if (mkdir(absPath.c_str(), 0777) != 0) {
            printf("Failed to create directory: %s\n", absPath.c_str());
            return false;
        }
    }

    return true;
}

std::vector<std::string> _splitString(const std::string &s, char delimiter) {
    std::vector<std::string> tokens;
    std::string token;
    std::istringstream tokenStream(s);
    while (std::getline(tokenStream, token, delimiter))
    {
        tokens.push_back(token);
    }
    return tokens;
}

FILE *vx::fs::openFile(const std::string& absFilePath, const std::string& mode) {
    return fopen(absFilePath.c_str(), mode.c_str());
}

std::string vx::fs::getBundleFilePath(const std::string& relFilePath) {
    return _getAbsBundlePath(relFilePath);
}

FILE *vx::fs::openBundleFile(std::string filename, std::string mode) {
    const std::string absPath = getBundleFilePath(filename);
    FILE* result = openFile(absPath, mode);
    if (result == nullptr) {
        // try within storage (where we put dynamically loaded "bundle" files).
        result = openStorageFile(std::string("bundle/") + filename, mode);
    }
    return result;
}

FILE *vx::fs::openStorageFile(std::string relFilePath, std::string mode, size_t writeSize) {
    // if mode starts with 'w', then mode is a write mode
    const bool isWriteMode = mode[0] == 'w';

    // ...
    const std::string& absPath = _getAbsStoragePath(relFilePath);

    // open the file
    FILE *fd = openFile(absPath, mode);

    // if the file is not found and we are in write mode 
    // we try to create the parent directories and retry
    if (fd == nullptr && isWriteMode) {
        // failed to create new file, try to create the directory first, and retry
        const std::string relDirPath = vx::fs::pathDir(relFilePath);
        // 
        const bool ok = _createDirectoriesInStorage(relDirPath);
        if (ok) {
            // retry opening the file
            fd = openFile(absPath, mode);
        } else {
            // failed to create parent directories, fd remains nullptr
        }
    }

    return fd;
}

// TODO: implement this!
std::vector<std::string> vx::fs::listStorageDirectory(const std::string& relStoragePath) {
    std::vector<std::string> result;
    printf("[vx::fs::listStorageDirectory] IMPLEMENT ME!");
    return result;
}

void vx::fs::importFile(ImportFileCallback callback) {
    // keep reference on callback function
    currentCallback = callback;
    //
    js_fs_import_file();
}

bool vx::fs::removeStorageFileOrDirectory(std::string relFilePath) {
    const std::string absPath = _getAbsStoragePath(relFilePath);
    return remove(absPath.c_str()) == 0;
}

bool vx::fs::bundleFileExists(const std::string& relFilePath, bool& isDir) {
    struct stat stat_buf;
    if(stat(getBundleFilePath(relFilePath).c_str(), &stat_buf) != 0 ) {
        isDir = false;
        return false;
    }
    isDir = (stat_buf.st_mode & S_IFMT) == S_IFDIR;
    return true;
}

bool vx::fs::storageFileExists(const std::string &relFilePath, bool &isDir) {
    const std::string absPath = _getAbsStoragePath(relFilePath);
    struct stat stat_buf;
    if(stat(absPath.c_str(), &stat_buf) != 0 ) {
        isDir = false;
        return false;
    }
    isDir = (stat_buf.st_mode & S_IFMT) == S_IFDIR;
    return true;
}

bool vx::fs::mergeBundleDirInStorage(const std::string &bundleDir, 
                                     const std::string &storageDir) {
    printf("vx::fs::mergeBundleDirInStorage %s %s\n", bundleDir.c_str(), storageDir.c_str());
    
    const std::string absBundleDir = getBundleFilePath(bundleDir);
    const std::string absStorageDir = _getAbsStoragePath(storageDir);
    
    char buffer[FileCopyBufferSize];
    size_t n = 0;
    
    bool isDirectory = false;
    bool fileExists = false;
    
    fileExists = bundleFileExists(bundleDir, isDirectory);
    if (isDirectory == false || fileExists == false) {
        printf("vx::fs::mergeBundleDirInStorage failed : bundle dir doesn't exist %s\n", bundleDir.c_str());
        return false;
    }

    fileExists = storageFileExists(storageDir, isDirectory);
    if (fileExists == false) {
        // create directory (including parents if necessary)
        const bool ok = _createDirectoryWithParents(absStorageDir);
        if (ok == false) {
            printf("vx::fs::mergeBundleDirInStorage failed : storage dir doesn't exist %s\n", absStorageDir.c_str());
            return false;
        }
    } else if (isDirectory == false) {
        printf("vx::fs::mergeBundleDirInStorage failed : storage dir path exists but isn't a directory\n");
        return false;
    }
    
    struct dirent *entry = nullptr;
    DIR *dp = nullptr;
    
    std::list<std::string> dirs;
    dirs.push_front(bundleDir);
        
    while (dirs.empty() == false) {
        
        const std::string relBundleDirPath = dirs.front();
        dirs.pop_front();
        const std::string absBundleDirPath = _getAbsBundlePath(relBundleDirPath);
        // printf("vx::fs::mergeBundleDir process dir ----- %s %s\n", relBundleDirPath.c_str(), absBundleDirPath.c_str());

        dp = opendir(absBundleDirPath.c_str());
        if (dp != nullptr) {
            while (true) {
                entry = readdir(dp);
                if (entry == nullptr) { 
                    // printf("vx::fs::mergeBundleDirInStorage [end of dir %s]\n", relBundleDirPath.c_str());
                    break;
                }
                
                if (entry->d_type == DT_DIR) { // found a directory
                    // ignore . and .. files representing the current and parent directories
                    if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
                        const std::string relBundleChildPath = relBundleDirPath + "/" + std::string(entry->d_name);
                        // printf("vx::fs::mergeBundleDirInStorage     found dir : %s\n", relBundleChildPath.c_str()); 
                        dirs.push_front(relBundleChildPath);

                        // create directory in destination
                        const std::string dirToCreate = _getAbsStoragePath(relBundleChildPath);
                        const bool ok = _createDirectoryWithParents(dirToCreate);
                        if (ok == false) {
                            printf("vx::fs::mergeBundleDirInStorage CREATE DIR [%s] [%s]\n", dirToCreate.c_str(), ok ? "SUCCESS" : "FAILURE");
                        }
                    }
                    
                } else if (entry->d_type == DT_REG) { // found a regular file
                    const std::string relBundleChildPath = relBundleDirPath + "/" + std::string(entry->d_name);
                    // printf("vx::fs::mergeBundleDirInStorage     found file: %s\n", relBundleChildPath.c_str());

                    struct stat stat_buf;
                    int rc = stat(_getAbsBundlePath(relBundleChildPath).c_str(), &stat_buf);
                    if (rc != 0) {
                        printf("CAN'T STAT %s\n", _getAbsBundlePath(relBundleChildPath).c_str());
                        return false;
                    }
                    const size_t fileSize = stat_buf.st_size;

                    // std::string relPath = absBundlePath.substr(bundlePrefix.length());
                    // const std::string absDestinationPath = _getAbsStoragePath(relBundleChildPath);
                    // printf("%s -> %s (%lu bytes)\n", absBundleChildPath.c_str(), absDestinationPath.c_str(), fileSize);
                    
                    FILE* src = openBundleFile(relBundleChildPath, "rb");
                    if (src == nullptr) {
                        printf("CAN'T OPEN BUNDLE FILE: %s\n", relBundleChildPath.c_str());
                        return false;
                    }
                    
                    FILE *dst = openStorageFile(relBundleChildPath, "wb", fileSize);
                    if (dst == nullptr) {
                        printf("CAN'T OPEN STORAGE FILE: %s\n", relBundleChildPath.c_str());
                        fclose(src);
                        return false;
                    }
                    
                    n = fread(buffer, 1, FileCopyBufferSize, src);
                    fwrite(buffer, 1, n, dst);

                    // do while ?
                    while (n == FileCopyBufferSize) {
                        n = fread(buffer, 1, FileCopyBufferSize, src);
                        fwrite(buffer, 1, n, dst);
                    }
                    
                    fclose(src);
                    fclose(dst);
                }
            }
            
            closedir(dp);
        }
    }
    
    return false;
}

// TODO: implement this!
void vx::fs::pickThumbnail(std::function<void(FILE* thumbnail)> callback) {
    callback(nullptr);
}

// on this platform we can't let the user choose the location for security reasons
void vx::fs::shareFile(const std::string& filepath, const std::string& title, const std::string& filename, const fs::FileType type) {
    switch (type) {
        case fs::FileType::PNG:
            js_fs_share_file(filepath.c_str(), (filename + ".png").c_str(), "image/png");
            break;
        case fs::FileType::PCUBES:
            js_fs_share_file(filepath.c_str(), (filename + ".pcubes").c_str(), "application/octet-stream");
            break;
        case fs::FileType::CUBZH:
            js_fs_share_file(filepath.c_str(), (filename + ".3zh").c_str(), "application/octet-stream");
            break;
        case fs::FileType::VOX:
            js_fs_share_file(filepath.c_str(), (filename + ".vox").c_str(), "application/octet-stream");
            break;
        case fs::FileType::OBJ:
            js_fs_share_file(filepath.c_str(), (filename + ".obj").c_str(), "application/octet-stream");
            break;
        default:
            js_fs_share_file(filepath.c_str(), filename.c_str(), "application/octet-stream");
            break;
    }
}

bool vx::fs::removeStorageFilesWithPrefix(const std::string& directory, const std::string& prefix) {
    return false;
}

void vx::fs::syncFSToDisk() {
    EM_ASM(
        fs_sync_to_disk();
    );
}

// --------------------------------------------------
// Helper
// --------------------------------------------------

bool vx::fs::Helper::setInMemoryStorage(bool b) {
    // in memory storage not allowed on Android for now
    return false;
}
