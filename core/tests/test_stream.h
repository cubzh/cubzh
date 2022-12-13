// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_stream.h
//  Created by Xavier Legland on October 21, 2022.
// -------------------------------------------------------------

#pragma once

#include "stream.h"

// functions that are NOT tested:
// stream_new_buffer_write
// stream_free
// stream_new_buffer_write_prealloc
// stream_buffer_unload
// stream_new_file_write

// check that we read the content correctly
void test_stream_new_buffer_read(void) {
    const size_t len = 6;
    const char *content = "Hello";
    Stream *s = stream_new_buffer_read(content, len);
    char *buf = (char *)malloc(len * sizeof(char));
    const bool ok = stream_read_string(s, len, buf);

    TEST_CHECK(ok);
    TEST_CHECK(strcmp(buf, content) == 0);

    stream_free(s);
    free(buf);
}

// check that the file is read correctly
void test_stream_new_file_read(void) {
    const char *file_name = "hi.txt";
    const size_t len = 6;
    const char *content = "Hello";
    char *buf = (char *)malloc(len * sizeof(char));
    FILE *f = fopen(file_name, "w"); // open for writing
    const int err = fputs(content, f);
    TEST_ASSERT(err != EOF);
    fclose(f);
    f = fopen(file_name, "r"); // open for reading
    Stream *s = stream_new_file_read(f);
    const bool ok = stream_read_string(s, 5, buf);
    buf[len - 1] = '\0'; // end the string

    TEST_CHECK(ok);
    TEST_CHECK(strcmp(buf, content) == 0);

    stream_free(s);
    free(buf);
    remove(file_name);
}

// check that the output matches the content
void test_stream_read(void) {
    const size_t len = 6; // length of "Hello" (+ NULL terminator)
    char *content = (char *)malloc(len * sizeof(char));
    strcpy(content, "Hello");
    char *buf = (char *)malloc(len * sizeof(char));
    Stream *s = stream_new_buffer_read(content, len);
    const bool ok = stream_read(s, buf, len, 1);

    TEST_CHECK(ok);
    TEST_CHECK(strcmp(buf, content) == 0);
    // cannot read beyond the stream
    TEST_CHECK(stream_read(s, buf, 1, 1) == false);

    stream_free(s);
    free(buf);
}

// we should have the same value on both ends
void test_stream_read_uint8(void) {
    const size_t len = 1;
    char *content = (char *)malloc(len * sizeof(char));
    const uint8_t value = 5;
    uint8_t result = 0;
    content[0] = (char)value;
    Stream *s = stream_new_buffer_read(content, len);
    const bool ok = stream_read_uint8(s, &result);

    TEST_CHECK(ok);
    TEST_CHECK(result == value);

    stream_free(s);
    free(content);
}

// we should have the same value on both ends
void test_stream_read_uint16(void) {
    const size_t len = 2;
    char *content = (char *)malloc(len * sizeof(char));
    const uint16_t value = 4000; // 4k
    uint16_t result = 0;
    content[0] = (char)(value % 256); // LSB first
    content[1] = (char)(value / 256);
    Stream *s = stream_new_buffer_read(content, len);
    const bool ok = stream_read_uint16(s, &result);

    TEST_CHECK(ok);
    TEST_CHECK(result == value);

    stream_free(s);
    free(content);
}

// we should have the same value on both ends
void test_stream_read_uint32(void) {
    const size_t len = 4;
    uint8_t *content = (uint8_t *)malloc(len * sizeof(uint8_t));
    const uint32_t value = 400000; // 400 k / 0x061A80
    uint32_t result = 0;
    content[3] = 0x00;
    content[2] = 0x06;
    content[1] = 0x1A;
    content[0] = 0x80;
    Stream *s = stream_new_buffer_read((const char *)content, len);
    const bool ok = stream_read_uint32(s, &result);

    TEST_CHECK(ok);
    TEST_CHECK(result == value);

    stream_free(s);
    free(content);
}

// we should have the same value on both ends
void test_stream_read_float32(void) {
    // -200 <=> 0b11000011 0b01001000 0b00000000 0b00000000
    const size_t len = 4;
    uint8_t *content = (uint8_t *)malloc(len * sizeof(uint8_t));
    const float value = -200.0f;
    float result = 0;
    content[3] = 0b11000011;
    content[2] = 0b01001000;
    content[1] = 0b00000000;
    content[0] = 0b00000000;
    Stream *s = stream_new_buffer_read((const char *)content, len);
    const bool ok = stream_read_float32(s, &result);

    TEST_CHECK(ok);
    TEST_CHECK(result == value);

    stream_free(s);
    free(content);
}

// we should have the same value on both ends
void test_stream_read_string(void) {
    const size_t len = 6;
    char *content = "Hello";
    char *buf = (char *)malloc(len * sizeof(char));
    Stream *s = stream_new_buffer_read(content, len);
    const bool ok = stream_read_string(s, len, buf);

    TEST_CHECK(ok);
    TEST_CHECK(strcmp(buf, content) == 0);

    stream_free(s);
    free(buf);
}

// check that we can read only the second byte
void test_stream_skip(void) {
    const size_t len = 2;
    char *content = (char *)malloc(len * sizeof(char));
    const uint8_t value = 5;
    uint8_t result = 0;
    content[0] = (char)2;
    content[1] = (char)value;
    Stream *s = stream_new_buffer_read(content, len);
    const bool ok = stream_skip(s, 1);

    TEST_CHECK(ok);
    stream_read_uint8(s, &result);
    TEST_CHECK(result == value);

    stream_free(s);
    free(content);
}

// check that skipping increases the cursor position
void test_stream_get_cursor_position(void) {
    const size_t len = 2;
    char *content = (char *)malloc(len * sizeof(char));
    content[0] = (char)2;
    content[1] = (char)5;
    Stream *s = stream_new_buffer_read(content, len);
    stream_skip(s, 1);
    const size_t position = stream_get_cursor_position(s);

    TEST_CHECK(position == 1);

    stream_free(s);
    free(content);
}

// check that the cursor is set at the given position
void test_stream_set_cursor_position(void) {
    const size_t len = 3;
    char *content = (char *)malloc(len * sizeof(char));
    const uint8_t value = 5;
    uint8_t result = 0;
    content[0] = (char)2;
    content[1] = (char)3;
    content[2] = (char)value;
    Stream *s = stream_new_buffer_read(content, len);
    stream_set_cursor_position(s, 2);
    const size_t position = stream_get_cursor_position(s);
    stream_read_uint8(s, &result);

    TEST_CHECK(position == 2);
    TEST_CHECK(result == value);

    stream_free(s);
    free(content);
}

// reach the end and test
void test_stream_reached_the_end(void) {
    const size_t len = 2;
    char *content = (char *)malloc(len * sizeof(char));
    const uint8_t value = 5;
    content[0] = (char)2;
    content[1] = (char)value;
    Stream *s = stream_new_buffer_read(content, len);
    bool ok = stream_reached_the_end(s);

    TEST_CHECK(ok == false);

    stream_skip(s, 2);
    ok = stream_reached_the_end(s);

    TEST_CHECK(ok);

    stream_free(s);
    free(content);
}
