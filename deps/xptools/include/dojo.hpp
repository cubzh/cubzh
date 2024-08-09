//
//  dojo.hpp
//  xptools
//
//  Created by Corentin Cailleaud on 01/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

// C++
#include <string>

namespace dojo {

class Dojo final {
public:
    static void createClientAndProvider(const char *rpcUrl,
                                        const char *toriiUrl,
                                        const char *relayUrl,
                                        const char *worldAddress,
                                        int userdata,
                                        void (*cb)(int, int, int));
    
    static void createBurner(int provider,
                             const char *playerAddress,
                             const char *playerSigningKey,
                             int userdata,
                             void (*cb)(int, int));
    
    static void execute(int account, const char* calldataJson);
    
    static char *bytearraySerialize(const char* string);
    static char *bytearrayDeserialize(const char* string);
    
    static void getEntities(int client,
                            int query,
                            int userdata,
                            void (*cb)(int, int));
    
    static void getEventMessages(int client,
                                 int query,
                                 int userdata,
                                 void (*cb)(int, int));

    static void onEntityUpdate(int client,
                                int clause,
                                int userdata,
                                void (*cb)(int, int));

    static char *accountAddress(int account);
};

}
