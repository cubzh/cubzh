// -------------------------------------------------------------
//  Cubzh Core
//  stream.h
//  Created by Adrien Duermael on August 10, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

typedef struct _Stream Stream;

// Frees underlying buffer if it hasn't been unloaded.
// Closes underlying FILE if there's one.
void stream_free(Stream *s);

//
Stream *stream_new_buffer_write(void);

//
Stream *stream_new_buffer_write_prealloc(const size_t prealloc_size);

// Moves buffer to given pointer.
// The Stream loses buffer responsability after this and can't keep writing.
bool stream_buffer_unload(Stream *s, char **buf, size_t *written, size_t *bufSize);

//
Stream *stream_new_buffer_read(const char *buf, const size_t size);

// Expecting a file opened with "wb" flag
Stream *stream_new_file_write(FILE *fd);

/// Expecting a file opened with "rb" flag.
/// The file descriptor `fd` is owned by the stream, which will fclose it in the future.
Stream *stream_new_file_read(FILE *fd);

// READ

bool stream_read(Stream *s, void *outValue, size_t itemSize, size_t nbItems);
bool stream_read_uint8(Stream *s, uint8_t *outValue);
bool stream_read_uint16(Stream *s, uint16_t *outValue);
bool stream_read_uint32(Stream *s, uint32_t *outValue);
bool stream_read_float32(Stream *s, float *outValue);
bool stream_read_string(Stream *s, size_t size, char *outValue);
bool stream_skip(Stream *s, size_t bytesToSkip);

size_t stream_get_cursor_position(Stream *s);
void stream_set_cursor_position(Stream *s, size_t pos);

bool stream_reached_the_end(Stream *s);

#ifdef __cplusplus
} // extern "C"
#endif
