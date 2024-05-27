//
//  Channel.hpp
//  xptools
//
//  Created by Gaetan de Villele on 08/02/2022.
//

#pragma once

// C++
#include <mutex>
#include <queue>

namespace vx {

/// simple-duplex channel
template <typename T>
class Channel final {

public:
    
    Channel();
    ~Channel();
    
    ///
    void push(T msg);
    
    ///
    void pushMove(T&& msg);

    /// Returns true when a message has been popped
    bool pop(T& msgRef);
    
    void clear();
    
private:
    
    std::mutex _mutex;
    std::queue<T> _queue;
    
};

// Full definition must be available here for template classes

template <typename T>
Channel<T>::Channel() :
_mutex(),
_queue() {}

template <typename T>
Channel<T>::~Channel() {}

template <typename T>
void Channel<T>::push(T msg) {
    const std::lock_guard<std::mutex> locker(_mutex);
    _queue.push(msg);
}

template <typename T>
void Channel<T>::pushMove(T&& msg) {
    const std::lock_guard<std::mutex> locker(_mutex);
    _queue.push(std::move(msg));
}

template <typename T>
bool Channel<T>::pop(T& msgRef) {
    const std::lock_guard<std::mutex> locker(_mutex);
    if (_queue.empty()) { return false; }
    msgRef = _queue.front();
    _queue.pop();
    return true;
}

template <typename T>
void Channel<T>::clear() {
    const std::lock_guard<std::mutex> locker(_mutex);
    std::queue<T> empty;
    std::swap( _queue, empty );
}


} // namespace vx
