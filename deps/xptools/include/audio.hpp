//
//  audio.hpp
//  xptools
//
//  Created by Gaetan de Villele on 07/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

#ifndef P3S_CLIENT_HEADLESS

// C++
#include <string>
#include <memory>
#include <vector>

// miniaudio
#include "miniaudio.h"

namespace vx {
namespace audio {

class Sound;
typedef std::shared_ptr<Sound> Sound_SharedPtr;
typedef std::weak_ptr<Sound> Sound_WeakPtr;

class Sound;
class Listener;

typedef struct {
    ma_vfs_callbacks cb;
    ma_allocation_callbacks allocationCallbacks;    /* Only used for the wchar_t version of open() on non-Windows platforms. */
} vx_tools_vfs;

extern "C" {
typedef struct {
    ma_node_base base;
    Sound_WeakPtr parent;
} FadingNode;
}

// --------------------------------------------------
// MARK: - Engine -
// --------------------------------------------------
class AudioEngine final {
    
    // MARK: - Public -
public:
    
    ///
    static AudioEngine *shared();
    
    ///
    ~AudioEngine();
    
    ///
    Sound *createSound(const std::string& soundName, bool looping = false);
    
    ///
    Listener *createListener();

    bool setVolume(float volumePercentage);
    
    // MARK: - Private -
private:
    
    ///
    AudioEngine();
    
    // miniaudio stuff
    ma_engine _engine;
    
    vx_tools_vfs *_vfs;
    
    // Now class Sound can access private members of Engine
    friend class Sound;
    
    // Now class Listener can access private members of Engine
    friend class Listener;
};

// --------------------------------------------------
// MARK: - SoundsTicks -
// --------------------------------------------------

class SoundsTicks final {
public:

    /// returns shared instance
    static SoundsTicks *shared();

    /// destructor
    ~SoundsTicks();

    void tick(const double dt);

    void addSound(const Sound_SharedPtr sound);

private:

    /// private constructor
    SoundsTicks();

    /// sounds currently allocated
    std::vector<Sound_WeakPtr> _sounds;
};

// --------------------------------------------------
// MARK: - Sound -
// --------------------------------------------------

class Sound final {
public:
    
    static Sound_SharedPtr make(AudioEngine * const engine, const std::string& soundName, const bool looping = false);

    bool init(AudioEngine * const engine, const std::string& soundName);

    ///
    Sound(AudioEngine * const engine, const std::string& soundName, const bool looping = false);
    
    ///
    ~Sound();

    void tick(double dt);

    ///
    inline const std::string& getSoundName() { return _soundName; }

    ///
    void play();
    
    ///
    void pause();
    
    ///
    void stop();

    // do not use unless the sound ends with 0 values
    // use stop() instead
    void stopWithoutFadeOut();

    bool isPlaying();
    
    ///
    bool getSpatialized();
    
    ///
    void setSpatialized(const bool spacialized);

    ///
    bool getLooping();

    ///
    void setLooping(const bool loop);
    
    ///
    inline float getStartAt() { return _startAt; }
    
    ///
    inline bool getStartAtEnabled() { return _startAt >= 0.0f; }
    
    /// returns false if the start time greater than the track's length
    bool setStartAt(float newValue);

    void disableStartAt();
    
    ///
    inline float getStopAt() { return _stopAt; }
    
    ///
    inline bool getStopAtEnabled() { return _stopAt >= 0.0f; }
    
    ///
    bool setStopAt(float newValue);

    void disableStopAt();

    void fadeOut();
    
    ///
    float getVolume();

    float getOriginalDuration();
    
    ///
    void setVolume(float volume);

    ma_engine *getEngine();

    ///
    float getMaxDistance();

    ///
    void setMaxDistance(float distance);

    ///
    float getMinDistance();

    ///
    void setMinDistance(float distance);

    ///
    float getPitch();

    ///
    void setPitch(float pitch);
    
    ///
    float getPan();
    
    ///
    void setPan(float pan);
    
    /// Position (for 3D spatialization)
    void getPosition(float& x, float& y, float& z);
    
    ///
    void setPosition(const float x, const float y, const float z);
    
private:
    /// reads the file and returns the number of samples
    /// /!\ only works with ogg files
    ma_uint32 getNbSamplesFromOggFile();

    /// updates the duration taking into account startAt and stopAt
    void updateDuration();

    Sound_WeakPtr _weakSelf;

    Sound_SharedPtr _retainer;
    
    /// variable from miniaudio that controls the sound itself
    ma_sound _ma_sound;
    
    ///
    std::string _soundName;
    
    /// time at which the sound must start (in s)
    float _startAt;

    /// time at which the sound must stop (in s)
    float _stopAt;

    /// length in s that will be played
    float _duration;

    /// length in s without pitch, startAt and stopAt
    float _originalDuration;

    float _volume;

    /// true if min_distance changes depending on max_distance
    bool _hasDefaultRadiusRatio;

    float _pitch;

    ///
    bool _looping;

    bool _playScheduled;

    // if it is -1.0, the Sound has been stopped / paused and fade has started
    double _timeSinceStartOfPlay;

    // if it is -1.0, fade has not started
    double _timeSinceStartOfFade;

    // if the sound is paused, it will start again at this frame
    ma_uint64 _startFrame;

    ma_uint32 _sampleRate;

    friend class AudioEngine;
};

// --------------------------------------------------
// MARK: - Listener -
// --------------------------------------------------

class Listener final {
    
public:
    
    ///
    Listener(AudioEngine *engine);
    
    ///
    ~Listener();
    
    ///
    void getPosition(float& x, float& y, float& z);
    
    ///
    void setPosition(const float x, const float y, const float z);
    
    ///
    void getDirection(float& x, float& y, float& z);
    
    ///
    void setDirection(const float x, const float y, const float z);
    
private:
    
    // static uint32_t nextIndex;
    
    ///
    AudioEngine *_engine;
    
    /// starts at 0
    uint32_t _listenerIndex;
};

}
}

#endif
