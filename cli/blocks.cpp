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
#include "magicavoxel.h"
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

    std::string input_path = parseResult["input"].as<std::vector<std::string>>()[0];
    
    FILE *fd = fopen(input_path.c_str(), "rw");
    if (fd == nullptr) {
        err = std::string("can't open ") + input_path;
        return false;
    }
    
    ColorAtlas *colorAtlas = color_atlas_new();
    Stream *s = stream_new_file_read(fd);
    
    LoadShapeSettings shapeSettings;
    shapeSettings.octree = true;
    shapeSettings.lighting = false;
    shapeSettings.isMutable = false;
    
    DoublyLinkedList *assets = serialization_load_assets(s, "", AssetType_Shape, colorAtlas, &shapeSettings);
    if (assets == NULL) {
        fclose(fd);
        color_atlas_free(colorAtlas);
        err.assign("can't load assets");
        return false;
    }
    
    size_t n = 0;
    
    DoublyLinkedListNode *node = doubly_linked_list_first(assets);
    while (node != NULL) {
        Asset *r = (Asset *)doubly_linked_list_node_pointer(node);
        if (r->type == AssetType_Shape) {
            n += shape_get_nb_blocks((Shape *)r->ptr);
            shape_free((Shape *)r->ptr);
        }
        node = doubly_linked_list_node_next(node);
    }
    doubly_linked_list_flush(assets, free);
    doubly_linked_list_free(assets);
    
    color_atlas_free(colorAtlas);
    
    std::cout << n << std::endl;
    
    return true;
}
