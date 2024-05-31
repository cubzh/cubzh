//
//  Macros.h
//  xptools
//
//  Created by Gaetan de Villele on 04/02/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#pragma once

/// disable assign operator (=) and copy constructor for the given type
#define VX_DISALLOW_COPY_AND_ASSIGN(TypeName) \
TypeName( const TypeName& ) = delete;\
TypeName& operator=( const TypeName& ) = delete;
