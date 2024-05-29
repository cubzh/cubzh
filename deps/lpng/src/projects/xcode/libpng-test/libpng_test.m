//
//  mac_libpng_test.m
//  mac-libpng-test
//
//  Created by Vitalii Parovishnyk on 2/20/15.
//
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#include "png.h"

@interface mac_libpng_test : XCTestCase

@end

@implementation mac_libpng_test

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPngToPng {
    // This is an example of a functional test case.
    
    int result = 1;
    png_image image;
    
    NSString *infilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"basn0g01" ofType:@"png"];
    NSString *outfilePath = [[NSBundle bundleForClass:[self class]] bundlePath];
    outfilePath = [outfilePath stringByAppendingPathComponent:@"output.png"];
    
    const char *file_name_input = [infilePath UTF8String];
    const char *file_name_output = [outfilePath UTF8String];
    
    /* Only the image structure version number needs to be set. */
    memset(&image, 0, sizeof image);
    image.version = PNG_IMAGE_VERSION;
    
    if (png_image_begin_read_from_file(&image, file_name_input))
    {
        png_bytep buffer;
        
        /* Change this to try different formats!  If you set a colormap format
         * then you must also supply a colormap below.
         */
        image.format = PNG_FORMAT_RGBA;
        
        buffer = malloc(PNG_IMAGE_SIZE(image));
        
        if (buffer != NULL)
        {
            if (png_image_finish_read(&image, NULL/*background*/, buffer,
                                      0/*row_stride*/, NULL/*colormap for PNG_FORMAT_FLAG_COLORMAP */))
            {
                if (png_image_write_to_file(&image, file_name_output,
                                            0/*convert_to_8bit*/, buffer, 0/*row_stride*/,
                                            NULL/*colormap*/))
                {
                    result = 0;
                }
                else
                {
                    XCTAssert(NO, @"pngtopng: write %s: %s\n", file_name_output, image.message);
                }
                
                free(buffer);
            }
            
            else
            {
                XCTAssert(NO, @"pngtopng: read %s: %s\n", file_name_input, image.message);
                
                /* This is the only place where a 'free' is required; libpng does
                 * the cleanup on error and success, but in this case we couldn't
                 * complete the read because of running out of memory.
                 */
                png_image_free(&image);
            }
        }
        else
        {
            XCTAssert(NO, @"pngtopng: out of memory: %lu bytes\n", (unsigned long)PNG_IMAGE_SIZE(image));
        }
    }
    
    else
    {
        /* Failed to read the first argument: */
        XCTAssert(NO, @"pngtopng: %s: %s\n", file_name_input, image.message);
    }
    
    XCTAssert(result == 0, @"Pass");
}

@end
