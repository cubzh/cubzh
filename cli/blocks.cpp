//
//  combine.cpp
//  cli
//
//  Created by Gaetan de Villele on 13/10/2022.
//

#include "combine.hpp"

// C++
#include <iostream>
#include <vector>

// Cubzh Core
#include "shape.h"
#include "stream.h"
#include "color_atlas.h"
#include "serialization_vox.h"
#include "serialization.h"

bool count_blocks(cxxopts::ParseResult parseResult, std::string& err) {
    
    // validation

    if (parseResult.count("input") <= 0) {
        err.assign("no input files");
        return false;
    }

    if (parseResult.count("input") != 1) {
        err.assign("only 1 input file is allowed");
        return false;
    }

    // processing

    const std::string input_path = parseResult["input"].as<std::vector<std::string>>()[0];
    
    FILE * const fd = fopen(input_path.c_str(), "rb");
    if (fd == nullptr) {
        err.assign("can't open input file: " + input_path);
        return false;
    }

    ColorAtlas * const colorAtlas = color_atlas_new();
    Stream * const stream = stream_new_file_read(fd); // Stream is responsible for fclose-ing the file descriptor

    const ShapeSettings shapeSettings = {
        .lighting = false,
        .isMutable = false
    };

    const bool allowLegacy = true; // support .pcubes files
    DoublyLinkedList *assets = NULL;
    if (serialization_load_assets(stream,
                                  NULL,
                                  AssetType_Shape,
                                  colorAtlas,
                                  &shapeSettings,
                                  allowLegacy,
                                  &assets) == false) {
        color_atlas_free(colorAtlas);
        err.assign("can't load assets");
        return false;
    }
    // `stream` is freed by `serialization_load_assets`
    // `stream` took care of fclose-ing `fd`
    
    size_t blockCount = 0;
    
    DoublyLinkedListNode *node = doubly_linked_list_first(assets);
    while (node != NULL) {
        Asset * const r = (Asset *)doubly_linked_list_node_pointer(node);
        if (r->type == AssetType_Shape) {
            blockCount += shape_get_nb_blocks((Shape *)r->ptr);
            shape_free((Shape *)r->ptr);
        }
        node = doubly_linked_list_node_next(node);
    }
    doubly_linked_list_flush(assets, free);
    doubly_linked_list_free(assets);
    
    color_atlas_free(colorAtlas);

    // Don't print a new line ('\n') character since this command is used by another program (the Hub CLI)
    std::cout << blockCount;
    
    return true;
}
