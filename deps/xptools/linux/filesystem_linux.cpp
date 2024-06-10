//
//  filesystem_linux.cpp
//  xptools
//
//  Created by Gaetan de Villele on 09/03/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "filesystem.hpp"

// C++
#include <cstdio>
#include <string.h>
#include <list>
#include <fstream>

// C
#include <libgen.h> // for basename
#include <dirent.h>
#include <sys/stat.h>

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

typedef struct stat Stat;

static int do_mkdir(const char *path, mode_t mode)
{
    Stat            st;
    int             status = 0;

    if (stat(path, &st) != 0)
    {
        /* Directory does not exist. EEXIST for race condition */
        if (mkdir(path, mode) != 0 && errno != EEXIST)
            status = -1;
    }
    else if (!S_ISDIR(st.st_mode))
    {
        errno = ENOTDIR;
        status = -1;
    }

    return(status);
}

static int mkpath(const char *path, mode_t mode)
{
    char *pp;
    char *sp;
    int status;
    char *copypath = strdup(path);

    status = 0;
    pp = copypath;
    while (status == 0 && (sp = strchr(pp, '/')) != 0)
    {
        if (sp != pp)
        {
            /* Neither root nor double slash in path */
            *sp = '\0';
            status = do_mkdir(copypath, mode);
            *sp = '/';
        }
        pp = sp + 1;
    }
    
    if (status == 0) status = do_mkdir(path, mode);
    
    free(copypath);
    return (status);
}

std::string getStoragePath(const std::string& relFilePath) {
    std::string storagePath = "/storage";

    std::string pathPrefix = vx::fs::Helper::shared()->getStorageRelPathPrefix();
    if (pathPrefix != "") {
        if (*(pathPrefix.cbegin()) != '/') {
            pathPrefix = "/" + pathPrefix;
        }
        storagePath += pathPrefix;
    }

    if (*(relFilePath.cbegin()) != '/') {
        storagePath += "/";
    }
    return storagePath + relFilePath;
}

FILE *vx::fs::openFile(const std::string& filePath, const std::string& mode) {
    FILE *result = fopen(filePath.c_str(), mode.c_str());
    return result;
}

std::string vx::fs::getBundleFilePath(const std::string& relFilePath) {
    std::string bundlePath = "/bundle";
    if (*(relFilePath.cbegin()) != '/') {
        bundlePath += "/";
    }
    return bundlePath + relFilePath;
}

/// Opens a file located in the bundle "assets" directory.
/// @param filename name of the file to open. It should not start with a '/'.
FILE *vx::fs::openBundleFile(std::string relFilePath, std::string mode) {
    // TODO: create intermediary parent directories when writing
    std::string absPath = getBundleFilePath(relFilePath);
    FILE *result = fopen(absPath.c_str(), mode.c_str());
    if (result == nullptr) {
        // try within storage (where we put dynamically loaded "bundle" files).
        result = openStorageFile(std::string("bundle/") + relFilePath, mode);
    }
    return result;
}

bool ensureParentDirs(const std::string& path) {
    mode_t mode = 0755;
    struct stat sb;

    if (stat(path.c_str(), &sb) == 0 && S_ISDIR(sb.st_mode)) {
        return true;  // Directory already exists
    }

    size_t pos = 0;
    std::string currentDir;
    std::string delimiter = "/";

    while ((pos = path.find_first_of(delimiter, pos)) != std::string::npos) {
        currentDir = path.substr(0, pos++);
        if (currentDir.empty()) continue;  // If leading /, first token will be empty

        if (mkdir(currentDir.c_str(), mode) != 0 && errno != EEXIST) {
            printf("ensureParentDirs ERROR (1)\n");
            return false;
        }
    }

    // Try to create the last segment of path, in case it didn't end with a slash
    if (mkdir(path.c_str(), mode) != 0 && errno != EEXIST) {
                printf("ensureParentDirs ERROR (2)\n");
        return false;
    }

    return true;
}

///
FILE *vx::fs::openStorageFile(std::string relFilePath, std::string mode, size_t writeSize) {

    if (Helper::shared()->inMemoryStorage()) {

        /*
         FROM: https://man7.org/linux/man-pages/man3/fmemopen.3.html
         When a stream that has been opened for writing is flushed
         (fflush(3)) or closed (fclose(3)), a null byte is written at the
         end of the buffer if there is space. The caller should ensure
         that an extra byte is available in the buffer (and that size
         counts that byte) to allow for this
         
         /!\ the "if there is space" condition doesn't seem to be verified 
         the same way on all platforms. We spent a full day debugging a crash
         caused by this... And that's why we don't take chances and add
         an extra byte when creating an in memory file.
         When opening the file for reading, the size if decreased not to read
         that last byte.
         */

        FILE* f = nullptr;
        
        if (mode == "rb") {
            
            InMemoryFile *inMemFile = Helper::shared()->getInMemoryFile("storage/" + relFilePath);
            if (inMemFile != nullptr) {
                f = fmemopen(inMemFile->bytes, inMemFile->size - 1, mode.c_str());
            }
            
        } else if (mode == "wb" && writeSize != 0) {
            
            InMemoryFile *inMemFile = Helper::shared()->createInMemoryFile("storage/" + relFilePath, writeSize + 1);
            if (inMemFile != nullptr) {
                f = fmemopen(inMemFile->bytes, inMemFile->size, mode.c_str());
            }
        }
        return f;

    } else {
        std::string fullPath = getStoragePath(relFilePath);

        // Create directories if they do not exist
        size_t lastSlashPos = fullPath.rfind('/');
        if (lastSlashPos != std::string::npos) {
            std::string dirPath = fullPath.substr(0, lastSlashPos);
            if (!ensureParentDirs(dirPath)) {
                printf("FAILED TO CREATE PARENT DIRECTORIES %s\n", dirPath.c_str());
                return nullptr;
            }
        }

        return fopen(fullPath.c_str(), mode.c_str());
    }
}

std::vector<std::string> vx::fs::listStorageDirectory(const std::string& relStoragePath) {
    const std::string absPath = getStoragePath(relStoragePath);
    std::vector<std::string> files;

    DIR *dir = opendir(absPath.c_str());
    if (dir == nullptr) {
        // __android_log_print(ANDROID_LOG_ERROR, "Particubes", "opendir failed in storage. (%s)", absPath.c_str());
        return files;
    }

    struct dirent *ent;
    while((ent = readdir(dir)) != nullptr) {
        // filter out "." and ".."
        if (strcmp(ent->d_name, ".") == 0 ||
            strcmp(ent->d_name, "..") == 0) {
            continue;
        }

        std::string fullName(relStoragePath + "/" + ent->d_name);

        if (ent->d_type == DT_REG || ent->d_type == DT_DIR) {
            // regular file or directory
            files.push_back(fullName);
        }
    }
    closedir(dir);

    return files;
}

void vx::fs::importFile(ImportFileCallback callback) {
    // no import function on Linux for now
    return;
}

///
bool vx::fs::removeStorageFileOrDirectory(std::string relFilePath) {
    return remove(getStoragePath(relFilePath).c_str()) == 0;
}

///
bool vx::fs::bundleFileExists(const std::string& relFilePath, bool& isDir) {
    struct stat stat_buf;

    if(stat(getBundleFilePath(relFilePath).c_str(),&stat_buf) != 0 ) {
        isDir = false;
        return false;
    }

    isDir = (stat_buf.st_mode & S_IFMT) == S_IFDIR;
    return true;
}

///
bool vx::fs::storageFileExists(const std::string& relFilePath, bool& isDir) {

    if (Helper::shared()->inMemoryStorage()) {
        
        InMemoryFile *inMemFile = Helper::shared()->getInMemoryFile("storage/" + relFilePath);
        return inMemFile != nullptr;
        
    } else {

        struct stat stat_buf;

        if(stat(getStoragePath(relFilePath).c_str(),&stat_buf) != 0 )
        {
            isDir = false;
            return false;
        }

        isDir = (stat_buf.st_mode & S_IFMT) == S_IFDIR;

        return true;
    }
}

#define FILE_COPY_BUFFER_SIZE 255

bool vx::fs::mergeBundleDirInStorage(const std::string& bundleDir, const std::string& storageDir) {
    
    const std::string bundlePrefix = getBundleFilePath("");
    const std::string absBundleDir = getBundleFilePath(bundleDir);
    const std::string absStorageDir = getStoragePath(storageDir);
    
    char buffer[FILE_COPY_BUFFER_SIZE];
    size_t n;
    
    bool isDirectory = false;
    bool fileExists = false;
    
    fileExists = bundleFileExists(bundleDir, isDirectory);
    if (isDirectory == false || fileExists == false) {
        return false;
    }

    // no need to check for storage dir presence when
    // using in-memory storage.
    if (Helper::shared()->inMemoryStorage() == false) {
        fileExists = storageFileExists(storageDir, isDirectory);
        if (fileExists == false) {
            // TODO: create directory (including parents if necessary)
            return false;
        } else if (isDirectory == false) {
            return false;
        }
    }
    
    struct dirent *entry = nullptr;
    DIR *dp = nullptr;
    
    std::list<std::string> dirs;
    dirs.push_front(absBundleDir);
    
    while (dirs.empty() == false) {
        
        std::string dirAbsPath = dirs.front();
        dirs.pop_front();
        
        dp = opendir(dirAbsPath.c_str());
        if (dp != nullptr) {
            while ((entry = readdir(dp))) {
                
                if (entry->d_type == DT_DIR) {
                    if (strcmp(entry->d_name, ".") != 0 &&
                        strcmp(entry->d_name, "..") != 0) {
                        dirs.push_front(dirAbsPath + "/" + std::string(entry->d_name));
                        
                        // TODO: create dir if not using in-mem storage
                    }
                    
                } else if (entry->d_type == DT_REG) {
                    
                    std::string absBundlePath = dirAbsPath + "/" + std::string(entry->d_name);
                    
                    struct stat stat_buf;
                    int rc = stat(absBundlePath.c_str(), &stat_buf);
                    if (rc != 0) {
                        printf("CAN'T STAT %s\n", absBundlePath.c_str());
                        return false;
                    }
                    size_t fileSize = stat_buf.st_size;
                    
                    std::string relPath = absBundlePath.substr(bundlePrefix.length());
                    
                    // printf("%s -> %s (%lu bytes)\n", absBundlePath.c_str(), relPath.c_str(), fileSize);
                    
                    FILE *src = openBundleFile(relPath, "rb");
                    if (src == nullptr) {
                        printf("CAN'T OPEN BUNDLE FILE: %s\n", relPath.c_str());
                        return false;
                    }
                    
                    FILE *dst = openStorageFile(relPath, "wb", fileSize);
                    if (dst == nullptr) {
                        printf("CAN'T OPEN STORAGE FILE: %s\n", relPath.c_str());
                        fclose(src);
                        return false;
                    }
                    
                    n = fread(buffer, 1, FILE_COPY_BUFFER_SIZE, src);
                    fwrite(buffer, 1, n, dst);

                    while (n == FILE_COPY_BUFFER_SIZE) {
                        n = fread(buffer, 1, FILE_COPY_BUFFER_SIZE, src);
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

///
void vx::fs::pickThumbnail(std::function<void(FILE* thumbnail)> callback) {
    // TODO: implement
    callback(nullptr);
}

/// works without prompting where to save file
void vx::fs::shareFile(const std::string &filepath,
                       const std::string &title,
                       const std::string &filename,
                       const FileType type) {

    // TODO: fix

    // const std::string srcFullPath = getStoragePath(filePath);
    // const std::string dstPath = filename;
    // switch (type) {
    // case FileType::PNG:
    //     dstPath += ".png";
    //     break;
    // case FileType::PCUBES:
    //     dstPath += ".pcubes";
    //     break;
    // case FileType::CUBZH:
    //     dstPath += ".3zh";
    //     break;
    // case FileType::VOX:
    //     dstPath += ".vox";
    //     break;
    // case FileType::OBJ:
    //     fuldstPathlname += ".obj";
    //     break;
    // }

    // dstPath = getStoragePath(dstPath);
    // std::ifstream src(srcFullPath, std::ios::binary);
    // std::ofstream dst(dstPath, std::ios::binary);
    // dst << src.rdbuf();
}

bool vx::fs::removeStorageFilesWithPrefix(const std::string& directory, const std::string& prefix) {
    // TODO: implement me
    return false;
}

// ------------------------------
// Helper
// ------------------------------

bool vx::fs::Helper::setInMemoryStorage(bool b) {
    this->_inMemoryStorage = b;
    return true;
}
