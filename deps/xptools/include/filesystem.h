//
//  filesystem.h
//  xptools
//
//  Created by Gaetan de Villele on 05/03/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// C
#include <stdio.h>
#include <stdbool.h>

// C wrapper for C++ filesystem functions

char c_getPathSeparator(void);
const char *c_getPathSeparatorCStr(void);

size_t c_getFileSize(FILE *fp);

void *c_getFileContent(FILE *fp, size_t *outDataSize);

FILE *c_openBundleFile(const char *relFilePath, const char *mode);

FILE *c_openStorageFile(const char *relFilePath, const char *mode);

FILE *c_openStorageFileWithSize(const char *relFilePath, const char *mode, size_t size);

bool c_removeStorageFile(const char *relFilePath);

char *c_readStorageFile(const char *relFilePath);

char *c_readStorageFileTextContent(const char *relFilePath);

bool c_writeStorageFileTextContent(const char *relFilePath, const char *content);

bool c_bundleFileExists(const char *relFilePath, bool *isDir);

bool c_storageFileExists(const char *relFilePath, bool *isDir);

bool c_mergeBundleDirInStorage(const char *bundleDir, const char *storageDir);

bool c_removeStorageFilesWithPrefix(const char* directory, const char* prefix);

void c_syncFSToDisk(void);

#ifdef __cplusplus
} // extern "C"
#endif
