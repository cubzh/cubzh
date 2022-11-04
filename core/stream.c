// -------------------------------------------------------------
//  Cubzh Core
//  stream.c
//  Created by Adrien Duermael on August 10, 2022.
// -------------------------------------------------------------

#include "stream.h"

#include <stdlib.h>
#include <string.h>

enum STREAM_TYPE {
    STREAM_TYPE_FILE_READ = 1,
    STREAM_TYPE_FILE_WRITE = 2,
    STREAM_TYPE_BUFFER_READ = 3,
    STREAM_TYPE_BUFFER_WRITE = 4
};

typedef struct {
    char *buffer;
    size_t bufferSize;
    char *cursor;
} StreamData_BUFFER_WRITE;

typedef struct {
    const char *buffer;
    size_t bufferSize;
    const char *cursor;
} StreamData_BUFFER_READ;

typedef struct {
    FILE *file;
} StreamData_FILE;

struct _Stream {
    enum STREAM_TYPE type;
    void *data;
};

void stream_free(Stream *s) {
    switch (s->type) {
        case STREAM_TYPE_BUFFER_READ: {
            // nothing to do, Stream not responsible for buffer memory
            break;
        }
        case STREAM_TYPE_BUFFER_WRITE: {
            StreamData_BUFFER_WRITE *data = (StreamData_BUFFER_WRITE *)(s->data);
            if (data->buffer != NULL) {
                free(data->buffer);
                data->cursor = NULL;
                data->bufferSize = 0;
            }
            break;
        }
        case STREAM_TYPE_FILE_READ:
        case STREAM_TYPE_FILE_WRITE: {
            StreamData_FILE *data = (StreamData_FILE *)(s->data);
            fclose(data->file);
            data->file = NULL;
            break;
        }
    }

    free(s->data);
    free(s);
}

Stream *stream_new_buffer_write(void) {
    Stream *s = (Stream *)malloc(sizeof(Stream));
    s->type = STREAM_TYPE_BUFFER_WRITE;

    StreamData_BUFFER_WRITE *data = malloc(sizeof(StreamData_BUFFER_WRITE));
    data->bufferSize = 1;
    data->buffer = malloc(data->bufferSize);
    data->cursor = data->buffer;

    s->data = (void *)data;
    return s;
}

Stream *stream_new_buffer_write_prealloc(const size_t prealloc_size) {
    Stream *s = (Stream *)malloc(sizeof(Stream));
    s->type = STREAM_TYPE_BUFFER_WRITE;

    StreamData_BUFFER_WRITE *data = malloc(sizeof(StreamData_BUFFER_WRITE));
    data->bufferSize = prealloc_size;
    data->buffer = malloc(data->bufferSize);
    data->cursor = data->buffer;

    s->data = (void *)data;
    return s;
}

Stream *stream_new_buffer_read(const char *buf, const size_t size) {
    Stream *s = (Stream *)malloc(sizeof(Stream));
    s->type = STREAM_TYPE_BUFFER_READ;

    StreamData_BUFFER_READ *data = malloc(sizeof(StreamData_BUFFER_READ));
    data->bufferSize = size;
    data->buffer = buf;
    data->cursor = data->buffer;

    s->data = (void *)data;

    return s;
}

Stream *stream_new_file_write(FILE *fd) {
    Stream *s = (Stream *)malloc(sizeof(Stream));
    s->type = STREAM_TYPE_FILE_WRITE;

    StreamData_FILE *data = malloc(sizeof(StreamData_FILE));
    data->file = fd;

    s->data = (void *)data;
    return s;
}

Stream *stream_new_file_read(FILE *fd) {
    Stream *s = (Stream *)malloc(sizeof(Stream));
    s->type = STREAM_TYPE_FILE_READ;

    StreamData_FILE *data = malloc(sizeof(StreamData_FILE));
    data->file = fd;

    s->data = (void *)data;
    return s;
}

bool stream_buffer_unload(Stream *s, char **buf, size_t *written, size_t *bufSize) {
    if (s->type != STREAM_TYPE_BUFFER_WRITE)
        return false;
    if (buf == NULL)
        return false;
    if (*buf != NULL) {
        free(*buf);
    }

    StreamData_BUFFER_WRITE *data = (StreamData_BUFFER_WRITE *)(s->data);
    *buf = data->buffer;
    *written = data->cursor - data->buffer;
    *bufSize = data->bufferSize;

    data->buffer = NULL;
    data->cursor = NULL;
    data->bufferSize = 0;

    return true;
}

bool stream_read(Stream *s, void *outValue, size_t itemSize, size_t nbItems) {
    switch (s->type) {
        case STREAM_TYPE_BUFFER_READ: {
            size_t toRead = itemSize * nbItems;
            StreamData_BUFFER_READ *data = (StreamData_BUFFER_READ *)(s->data);
            if (data->cursor - data->buffer + toRead > data->bufferSize) {
                return false;
            }
            memcpy(outValue, data->cursor, toRead);
            data->cursor += toRead;
            return true;
        }
        case STREAM_TYPE_FILE_READ: {
            StreamData_FILE *data = (StreamData_FILE *)(s->data);
            size_t n = fread(outValue, itemSize, nbItems, data->file);
            if (n != nbItems) {
                return false;
            }
            return true;
        }
        default:
            break;
    }
    return false;
}

bool stream_read_uint8(Stream *s, uint8_t *outValue) {
    return stream_read(s, (void *)outValue, sizeof(uint8_t), 1);
}

bool stream_read_uint16(Stream *s, uint16_t *outValue) {
    return stream_read(s, (void *)outValue, sizeof(uint16_t), 1);
}

bool stream_read_uint32(Stream *s, uint32_t *outValue) {
    return stream_read(s, (void *)outValue, sizeof(uint32_t), 1);
}

bool stream_read_float32(Stream *s, float *outValue) {
    return stream_read(s, (void *)outValue, sizeof(float), 1);
}

bool stream_read_string(Stream *s, size_t size, char *outValue) {
    return stream_read(s, (void *)outValue, size, 1);
}

bool stream_skip(Stream *s, size_t bytesToSkip) {
    switch (s->type) {
        case STREAM_TYPE_BUFFER_READ: {
            StreamData_BUFFER_READ *data = (StreamData_BUFFER_READ *)(s->data);
            if (data->cursor - data->buffer + bytesToSkip > data->bufferSize) {
                return false;
            }
            data->cursor += bytesToSkip;
            return true;
        }
        case STREAM_TYPE_FILE_READ: {
            StreamData_FILE *data = (StreamData_FILE *)(s->data);
            if (fseek(data->file, bytesToSkip, SEEK_CUR) != 0) {
                return false;
            }
            return true;
        }
        default:
            break;
    }
    return false;
}

size_t stream_get_cursor_position(Stream *s) {
    switch (s->type) {
        case STREAM_TYPE_BUFFER_READ: {
            StreamData_BUFFER_READ *data = (StreamData_BUFFER_READ *)(s->data);
            return data->cursor - data->buffer;
        }
        case STREAM_TYPE_FILE_READ: {
            StreamData_FILE *data = (StreamData_FILE *)(s->data);
            return ftell(data->file);
        }
        default:
            break;
    }
    return 0;
}

void stream_set_cursor_position(Stream *s, size_t pos) {
    switch (s->type) {
        case STREAM_TYPE_BUFFER_READ: {
            StreamData_BUFFER_READ *data = (StreamData_BUFFER_READ *)(s->data);
            data->cursor = data->buffer + pos;
            break;
        }
        case STREAM_TYPE_FILE_READ: {
            StreamData_FILE *data = (StreamData_FILE *)(s->data);
            fseek(data->file, pos, SEEK_SET);
            break;
        }
        default:
            break;
    }
}

bool stream_reached_the_end(Stream *s) {
    switch (s->type) {
        case STREAM_TYPE_BUFFER_READ: {
            StreamData_BUFFER_READ *data = (StreamData_BUFFER_READ *)(s->data);
            return (size_t)(data->cursor - data->buffer) == data->bufferSize;
        }
        case STREAM_TYPE_FILE_READ: {
            StreamData_FILE *data = (StreamData_FILE *)(s->data);
            if (feof(data->file)) {
                return true;
            }
            if (getc(data->file) == EOF) {
                return true;
            }
            fseek(data->file, -1L, SEEK_CUR);
            return false;
        }
        default:
            break;
    }
    return false;
}
