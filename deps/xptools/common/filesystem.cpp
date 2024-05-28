//
//  filesystem.cpp
//  xptools
//
//  Created by Gaetan de Villele on 03/03/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "filesystem.hpp"

// C++
#include <cstring>
#include <cstdio>
#include <fstream>

// xptools
#include "vxlog.h"

using namespace vx::fs;

size_t vx::fs::getFileSize(FILE *fp) {
    long off = 0;
    long sz = 0;
    return ((off = ftell(fp)) != -1 && !fseek(fp, 0, SEEK_END) && (sz = ftell(fp)) != -1 && !fseek(fp, off, SEEK_SET)) ? size_t(sz) : size_t(0);
}

void *vx::fs::getFileContent(FILE *fp, size_t *outDataSize) {
    if (fp == nullptr) {
        return nullptr;
    }

    size_t data_size = getFileSize(fp);
    if (data_size == 0) {
        fclose(fp);
        return nullptr;
    }

    void *data = static_cast<void *>(malloc(data_size));
    if (data == nullptr) {
        fclose(fp);
        return nullptr;
    }
    if (fread(data, size_t(1), data_size, fp) != data_size) {
        fclose(fp);
        free(data);
        return nullptr;
    }

    fclose(fp);
    if (outDataSize != nullptr) {
        *outDataSize = data_size;
    }

    return data;
}

/// Returns a null-terminated string containing the content of a text file.
/// @param fd a valid FILE pointer.
char *vx::fs::getFileTextContent(FILE *fd) {
    if (fd == nullptr) {
        return nullptr;
    }

    const size_t fileSize = getFileSize(fd);
    if (fileSize == 0) {
        fclose(fd);
        // TODO: gdevillele: should return an empty string (not null)
        return nullptr;
    }

    char *textContent = static_cast<char *>(malloc(fileSize + 1)); // +1 for the null terminator
    if (textContent == nullptr) {
        fclose(fd);
        return nullptr;
    }
    if (fread(textContent, size_t(1), fileSize, fd) != fileSize) {
        fclose(fd);
        free(textContent);
        return nullptr;
    }
    textContent[fileSize] = '\0';

    fclose(fd);
    return textContent;
}

bool vx::fs::getFileTextContentAsString(FILE *fd, std::string &textContent) {
    char *text = getFileTextContent(fd);
    if (text == nullptr) {
        return false;
    }
    textContent.assign(text);
    free(text);
    text = nullptr;
    return true;
}

bool vx::fs::storageFileExists(const std::string& relFilePath) {
    bool isDir;
    return vx::fs::storageFileExists(relFilePath, isDir);
}

struct WritePngIO {
    uint8_t *out;
    size_t size;
};

static void writePngFn(png_structp png_ptr, png_bytep data, png_size_t length) {
    WritePngIO *io = static_cast<WritePngIO*>(png_get_io_ptr(png_ptr));
    io->out = static_cast<uint8_t *>(realloc(io->out, io->size + length));
    if (io->out == nullptr) {
        png_error(png_ptr, "alloc error");
    }
    memcpy(io->out + io->size, data, length);
    io->size +=length;
}

bool vx::fs::writePng(const std::string& filename, uint32_t w, uint32_t h, png_bytepp row_pointers,
                      void **out, size_t *outSize, int bitDepth, bool doWrite) {

    /// Init structures
    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
    if (png_ptr == nullptr) {
        vxlog_error("⚠️ savePng: png_create_write_struct failed");
        return false;
    }
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (info_ptr == nullptr) {
        vxlog_error("⚠️ savePng: png_create_info_struct failed");
        return false;
    }
    if (setjmp(png_jmpbuf(png_ptr))) {
        vxlog_error("⚠️ savePng: error during init_io");
        return false;
    }
    //png_init_io(png_ptr, fp); // used if writing to a file directly, instead of png_set_write_fn
    WritePngIO io = { nullptr, 0 };
    png_set_write_fn(png_ptr, &io, writePngFn, nullptr);

    /// Header
    if (setjmp(png_jmpbuf(png_ptr))) {
        vxlog_error("⚠️ savePng: error writing header");
        return false;
    }
    png_set_IHDR(png_ptr, info_ptr, w, h,
                 bitDepth, PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE,
                 PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
    png_write_info(png_ptr, info_ptr);

    /// Content
    if (setjmp(png_jmpbuf(png_ptr))) {
        vxlog_error("⚠️ savePng: write error");
        return false;
    }
    png_write_image(png_ptr, row_pointers);

    if (setjmp(png_jmpbuf(png_ptr))) {
        vxlog_error("⚠️ savePng: write end error");
        return false;
    }
    png_write_end(png_ptr, nullptr);

    if (doWrite) {
        FILE *fp = vx::fs::openStorageFile(filename, "wb");
        if (fp == nullptr) {
            vxlog_error("⚠️ savePng: failed to open file");
            return false;
        }

        fwrite(io.out, 1, io.size, fp);
        fclose(fp);
    }
    if (out != nullptr) {
        *out = io.out;
    } else {
        free(io.out);
    }
    if (outSize != nullptr) {
        *outSize = io.size;
    }

    png_destroy_write_struct(&png_ptr, &info_ptr);

    return true;
}

// ------------------------------
// InMemoryFile
// ------------------------------

InMemoryFile::InMemoryFile(size_t aSize) {
    this->size = aSize;
    this->bytes = static_cast<char*>(malloc(sizeof(char) * this->size));
}

InMemoryFile::~InMemoryFile() {
    free(this->bytes);
}

// ------------------------------
// Helper
// ------------------------------

vx::fs::Helper *vx::fs::Helper::_instance = nullptr;

vx::fs::Helper *vx::fs::Helper::shared() {
    if (_instance == nullptr) {
        _instance = new Helper();
    }
    return _instance;
}

vx::fs::Helper::Helper() {
    this->_thumbnailCallback = nullptr;
    this->_inMemoryStorage = false;
    this->_inMemoryFiles = std::map<std::string, InMemoryFile*>();
    this->_storageRelPathPrefix = "";
}

void vx::fs::Helper::setStorageRelPathPrefix(const std::string &prefix) {
    _storageRelPathPrefix = prefix;
}

std::string vx::fs::Helper::getStorageRelPathPrefix() {
    return _storageRelPathPrefix;
}

void vx::fs::Helper::setThumbnailCallback(std::function<void(FILE* thumbnail)> callback) {
    this->_thumbnailCallback = callback;
}

void vx::fs::Helper::callThumbnailCallback(FILE* thumbnail) {
    if (this->_thumbnailCallback != nullptr) {
        this->_thumbnailCallback(thumbnail);
    }
}

bool vx::fs::Helper::inMemoryStorage() {
    return this->_inMemoryStorage;
}

InMemoryFile* vx::fs::Helper::getInMemoryFile(std::string path) {

    std::map<std::string, InMemoryFile*>::iterator it = this->_inMemoryFiles.find(path);

    if (it == this->_inMemoryFiles.end()) {
        return nullptr;
    }

    return it->second;
}

InMemoryFile* vx::fs::Helper::createInMemoryFile(std::string path, size_t size) {

    InMemoryFile *inMemFile = this->getInMemoryFile(path);

    if (inMemFile != nullptr) {
        this->_inMemoryFiles.erase(path);
        delete inMemFile;
    }

    inMemFile = new InMemoryFile(size);
    this->_inMemoryFiles.insert(std::make_pair(path, inMemFile));

    return inMemFile;
}

#if !defined(__VX_PLATFORM_WASM)
void vx::fs::syncFSToDisk() {
    // nothing on non-web platforms
}
#endif

void vx::fs::removeStorageDirectoryRecurse(std::string dirPath) {
    std::vector<std::string> files = vx::fs::listStorageDirectory(dirPath);
    // `files` contains paths relative to storage root directory
    bool isDir = false;

    for (std::string childPath : files) {
        vx::fs::storageFileExists(childPath, isDir);
        if (isDir) {
            vx::fs::removeStorageDirectoryRecurse(childPath);
        }
        // vxlog_debug("RM: %s", childPath.c_str());
        vx::fs::removeStorageFileOrDirectory(childPath);
    }
}

bool vx::fs::readFile(const std::string filepath, std::string& dest) {
    // Open the file
    std::ifstream file(filepath);

    // Check if the file is open
    if (file.is_open() == false) {
        return false; // failure
    }

    // Read the entire file into a string
    dest.assign((std::istreambuf_iterator<char>(file)),
                std::istreambuf_iterator<char>());

    // Close the file
    file.close();

    return true; // success
}

std::string vx::fs::pathDir(const std::string &path) {
    const size_t lastSlashPos = path.find_last_of(::vx::fs::getPathSeparator());
    if (lastSlashPos != std::string::npos) {
        return path.substr(0, lastSlashPos);
    }
    // if no path separator found, then return `path` unchanged
    return path;
}

/// --------------------------------------------------
///
/// C-style functions
///
/// --------------------------------------------------

extern "C" {

size_t c_getFileSize(FILE *fp) {
    return vx::fs::getFileSize(fp);
}

void *c_getFileContent(FILE *fp, size_t *outDataSize) {
    return vx::fs::getFileContent(fp, outDataSize);
}

FILE *c_openBundleFile(const char *relFilePath, const char *mode) {
    if (relFilePath == nullptr || mode == nullptr) {
        if (relFilePath == nullptr) {
            vxlog_error("c_openBundleFile - relFilePath can't be NULL");
        }
        if (mode == nullptr) {
            vxlog_error("c_openBundleFile - mode can't be NULL");
        }
        return nullptr;
    }
    std::string relFilePathStr(relFilePath);
    std::string modeStr(mode);
    return vx::fs::openBundleFile(relFilePathStr, modeStr);
}

FILE *c_openStorageFile(const char *relFilePath, const char *mode) {
    if (relFilePath == nullptr || mode == nullptr) {
        return nullptr;
    }
    std::string relFilePathStr = std::string(relFilePath);
    std::string modeStr = std::string(mode);
    return vx::fs::openStorageFile(relFilePathStr, modeStr);
}

FILE *c_openStorageFileWithSize(const char *relFilePath, const char *mode, size_t size) {
    if (relFilePath == nullptr || mode == nullptr) {
        return nullptr;
    }
    std::string relFilePathStr = std::string(relFilePath);
    std::string modeStr = std::string(mode);
    return vx::fs::openStorageFile(relFilePathStr, modeStr, size);
}

bool c_removeStorageFile(const char *relFilePath) {
    std::string relFilePathStr = std::string(relFilePath);
    return vx::fs::removeStorageFileOrDirectory(relFilePathStr);
}

char *c_readStorageFileTextContent(const char *relFilePath) {
    FILE *fd = c_openStorageFile(relFilePath, "rb");
    if (fd == nullptr) {
        return nullptr;
    }
    size_t fileSize = c_getFileSize(fd);
    if (fileSize == 0) {
        fclose(fd);
        return nullptr;
    }
    char *string = static_cast<char *>(malloc(fileSize + 1));
    fread(string, 1, fileSize, fd);
    fclose(fd);
    string[fileSize] = 0;
    return string;
}

bool c_writeStorageFileTextContent(const char *relFilePath, const char *content) {
    // open file
    FILE *fd = c_openStorageFile(relFilePath, "wb");
    if (fd == nullptr) {
        vxlog_error("🔥 can't open file (%s)", relFilePath);
        return false;
    }
    size_t contentSize = strlen(content);
    if (fwrite(content, sizeof(char), contentSize, fd) != contentSize) {
        vxlog_error("🔥 failed to write string in %s", relFilePath);
        fclose(fd);
        return false;
    }
    fclose(fd);
    return true;
}

bool c_bundleFileExists(const char *relFilePath, bool *isDir) {

    if (relFilePath == nullptr) {
        return false;
    }

    std::string relFilePathStr = std::string(relFilePath);

    bool b;
    bool exists = vx::fs::bundleFileExists(relFilePathStr, b);

    if (isDir != nullptr) {
        *isDir = b;
    }

    return exists;
}

bool c_storageFileExists(const char *relFilePath, bool *isDir) {

    if (relFilePath == nullptr) {
        return false;
    }

    std::string relFilePathStr = std::string(relFilePath);

    bool b = false;
    bool exists = vx::fs::storageFileExists(relFilePathStr, b);

    if (isDir != nullptr) {
        *isDir = b;
    }

    return exists;
}

bool c_mergeBundleDirInStorage(const char *bundleDir, const char *storageDir) {

    if (bundleDir == nullptr) {
        return false;
    }

    if (storageDir == nullptr) {
        return false;
    }

    std::string bundleDirStr(bundleDir);
    std::string storageDirStr(storageDir);

    return vx::fs::mergeBundleDirInStorage(bundleDirStr, storageDirStr);
}

bool c_removeStorageFilesWithPrefix(const char* c_directory, const char* c_prefix) {
    if (c_directory == nullptr) { return false; }
    if (c_prefix == nullptr || strlen(c_prefix) == 0) { return false; }
    const std::string directory(c_directory);
    const std::string prefix(c_prefix);
    return vx::fs::removeStorageFilesWithPrefix(directory, prefix);
}

void c_syncFSToDisk(void) {
    vx::fs::syncFSToDisk();
}

} // extern "C"
