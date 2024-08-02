//
//  tracking.hpp
//  xptools
//
//  Created by Gaetan de Villele on 04/01/2021.
//  Copyright © 2021 voxowl. All rights reserved.
//

#pragma once

// C++
#include <unordered_map>
#include <string>

// xptools
#include "json.hpp"
#include "OperationQueue.hpp"

namespace vx {
namespace tracking {

/// Client for the Tracking service.
/// This is a Singleton.
class TrackingClient final {

public:

    /// Getter for shared instance (singleton)
    static TrackingClient& shared();

    /// Destructor
    virtual ~TrackingClient();

    // _session_id is a unix timestamp, in milliseconds
    // Calling this function initializes it, keeps it if already set,
    // or creates a new one if it's been used for the last time more
    // than 10 minutes ago.
    void appDidBecomeActive();

    //
    void appWillResignActive();

    ///
    void trackEvent(const std::string& eventType);

    ///
    void trackEvent(const std::string& eventType,
                    std::unordered_map<std::string, std::string> properties);

    /// flush debugID value from credentials.json
    void removeDebugID();

private:

    ///
    static TrackingClient *_sharedInstance;

    /// Constructor
    TrackingClient(const std::string& host,
                   const uint16_t& port,
                   const bool& secure);

    /// Returns the user account ID stored in credentials JSON file.
    bool _getUserAccountID(std::string &userID) const;

    /// Creates (if necessary) and returns a debug ID.
    /// It is used as "device ID" for tracking.
    bool _getDebugID(std::string &debugID) const;

    /// returns the name of the platform
    std::string _getPlatformName() const;

    /// returns the name of the OS
    std::string _getOSName() const;

    /// returns the version of the OS
    std::string _getOSVersion() const;

    /// returns the version of the App
    std::string _getAppVersion() const;

    // always sent within _operationQueue
    void _trackEvent(const std::string& eventType,
                     std::unordered_map<std::string, std::string> properties);

    //
    void _checkAndRefreshSession();

    //
    void _sendKeepAliveEventIfNeeded();

    /// utility function
    bool _createCredentialsJsonWithDebugID(std::string &debugID) const;

    // fields
#ifndef P3S_NO_METRICS
    OperationQueue *_operationQueue;
    std::string _host;
    uint64_t _session_id;
    uint64_t _session_used_at;
    uint16_t _port;
    bool _secure;
    bool _keep_alive_activated;
#endif
};

}
}
