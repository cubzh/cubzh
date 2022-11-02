// -------------------------------------------------------------
//  Cubzh Core
//  test_config.h
//  Created by Nino PLANE on November 2, 2022.
// -------------------------------------------------------------

#pragma once 

#include "config.h"

// Create diffrent unsigned long and check if the function return the closest power of two
void test_upper_power_of_two(void) {
    unsigned long a = 0;
    unsigned long b = 1;
    unsigned long c = 3;
    unsigned long d = 7;
    unsigned long e = 15;
    unsigned long f = 31;
    unsigned long g = 63;
    unsigned long h = 127;
    unsigned long i = -127;

    a = upper_power_of_two(a);
    b = upper_power_of_two(b);
    c = upper_power_of_two(c);
    d = upper_power_of_two(d);
    e = upper_power_of_two(e);
    f = upper_power_of_two(f);
    g = upper_power_of_two(g);
    h = upper_power_of_two(h);
    i = upper_power_of_two(i);

    TEST_CHECK(a == 0);
    TEST_CHECK(b == 1);
    TEST_CHECK(c == 4);
    TEST_CHECK(d == 8);
    TEST_CHECK(e == 16);
    TEST_CHECK(f == 32);
    TEST_CHECK(g == 64);
    TEST_CHECK(h == 128);
    TEST_CHECK(i == 0);
}
