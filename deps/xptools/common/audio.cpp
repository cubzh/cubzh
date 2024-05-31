//
//  audio.cpp
//  xptools
//
//  Created by Gaetan de Villele on 07/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#if !defined(P3S_CLIENT_HEADLESS)

#include "audio.hpp"

// C++
#include <thread>
#include <cassert>

// xptools
#include "vxlog.h"
#include "filesystem.hpp"

#define DEFAULT_MAX_DISTANCE 100.0f
#define DEFAULT_RADIUS_RATIO 0.5f

#define FADE_DURATION_SEC 0.01f // in seconds
#define CUT_WAIT_DURATION_AFTER_FADE_SEC 0.02 // in seconds

#define OGG_PAGE_HEADER "OggS"

using namespace vx::audio;

typedef struct {
    ma_data_source_node node;
    ma_decoder decoder;
} sound_node;

ma_result xptools_vfs_onOpen(ma_vfs* pVFS, const char* pFilePath, ma_uint32 openMode, ma_vfs_file* pFile);
ma_result xptools_vfs_onOpenW(ma_vfs* pVFS, const wchar_t* pFilePath, ma_uint32 openMode, ma_vfs_file* pFile);
ma_result xptools_vfs_onClose(ma_vfs* pVFS, ma_vfs_file file);
ma_result xptools_vfs_onRead(ma_vfs* pVFS, ma_vfs_file file, void* pDst, size_t sizeInBytes, size_t* pBytesRead);
ma_result xptools_vfs_onWrite(ma_vfs* pVFS, ma_vfs_file file, const void* pSrc, size_t sizeInBytes, size_t* pBytesWritten);
ma_result xptools_vfs_onSeek(ma_vfs* pVFS, ma_vfs_file file, ma_int64 offset, ma_seek_origin origin);
ma_result xptools_vfs_onTell(ma_vfs* pVFS, ma_vfs_file file, ma_int64* pCursor);
ma_result xptools_vfs_onInfo(ma_vfs* pVFS, ma_vfs_file file, ma_file_info* pInfo);
vx_tools_vfs* xptools_vfs_init();

ma_result xptools_vfs_onOpen(ma_vfs* pVFS, const char* pFilePath, ma_uint32 openMode, ma_vfs_file* pFile) {
    
    std::string path = std::string(pFilePath);
    bool inCache = false;
    
    if (path.rfind("cache/_audio_", 0) == 0) {
        inCache = true;
    } else {
        path = "audio/" + path;
    }
        
    std::string openModeStr;
    switch (openMode) {
        case MA_OPEN_MODE_WRITE:
            openModeStr = "wb";
            break;
        case MA_OPEN_MODE_READ:
        default:
            openModeStr = "rb";
            break;
    }

    FILE *fd;
    
    if (inCache) {
        fd = ::vx::fs::openStorageFile(path);
    } else {
        fd = ::vx::fs::openBundleFile(path, openModeStr);
    }
    
    if (fd == nullptr) {
        return MA_ERROR;
    }
    *pFile = reinterpret_cast<ma_vfs_file>(fd);
    return MA_SUCCESS;
}

ma_result xptools_vfs_onOpenW(ma_vfs* pVFS, const wchar_t* pFilePath, ma_uint32 openMode, ma_vfs_file* pFile) {
    // TODO: implement me!
    return MA_ERROR;
}

ma_result xptools_vfs_onClose(ma_vfs* pVFS, ma_vfs_file file) {
    FILE *fd = reinterpret_cast<FILE *>(file);
    if (fd == nullptr) {
        return MA_ERROR;
    }
    fclose(fd);
    return MA_SUCCESS;
}

ma_result xptools_vfs_onRead(ma_vfs* pVFS, ma_vfs_file file, void* pDst, size_t sizeInBytes, size_t* pBytesRead) {
    FILE *fd = reinterpret_cast<FILE *>(file);
    if (fd == nullptr) {
        return MA_ERROR;
    }
    *pBytesRead = fread(pDst, 1, sizeInBytes, fd);
    return MA_SUCCESS;
}

ma_result xptools_vfs_onWrite(ma_vfs* pVFS, ma_vfs_file file, const void* pSrc, size_t sizeInBytes, size_t* pBytesWritten) {
    vxlog_debug("xptools_vfs_onWrite");
    FILE *fd = reinterpret_cast<FILE *>(file);
    if (fd == nullptr) {
        return MA_ERROR;
    }
    *pBytesWritten = fwrite(pSrc, 1, sizeInBytes, fd);
    return MA_SUCCESS;
}

ma_result xptools_vfs_onSeek(ma_vfs* pVFS, ma_vfs_file file, ma_int64 offset, ma_seek_origin origin) {
    vxlog_debug("xptools_vfs_onSeek");
    FILE *fd = reinterpret_cast<FILE *>(file);
    if (fd == nullptr) {
        return MA_ERROR;
    }
    int position = 0;
    switch (origin) {
        case ma_seek_origin_start:
            position = SEEK_SET;
            break;
        case ma_seek_origin_current:
            position = SEEK_CUR;
            break;
        case ma_seek_origin_end:
            position = SEEK_END;
            break;
    }
    fseek(fd, static_cast<long>(offset), position);
    return MA_SUCCESS;
}

ma_result xptools_vfs_onTell(ma_vfs* pVFS, ma_vfs_file file, ma_int64* pCursor) {
    vxlog_debug("xptools_vfs_onTell");
    FILE *fd = reinterpret_cast<FILE *>(file);
    if (fd == nullptr) {
        return MA_ERROR;
    }
    *pCursor = ftell(fd);
    return MA_SUCCESS;
}

ma_result xptools_vfs_onInfo(ma_vfs* pVFS, ma_vfs_file file, ma_file_info* pInfo) {
    FILE *fd = reinterpret_cast<FILE *>(file);
    if (fd == nullptr) {
        return MA_ERROR;
    }
    const long previousPosition = ftell(fd);
    fseek(fd, 0L, SEEK_END);
    pInfo->sizeInBytes = ftell(fd);
    // seek back
    fseek(fd, previousPosition, SEEK_SET);
    return MA_SUCCESS;
}

vx_tools_vfs* xptools_vfs_init() {
    vx_tools_vfs *result = static_cast<vx_tools_vfs *>(malloc(sizeof(vx_tools_vfs)));
    if (result == nullptr) {
        return result;
    }
    
    result->cb.onOpen = xptools_vfs_onOpen;
    result->cb.onOpenW = xptools_vfs_onOpenW;
    result->cb.onClose = xptools_vfs_onClose;
    result->cb.onRead = xptools_vfs_onRead;
    result->cb.onWrite = xptools_vfs_onWrite;
    result->cb.onSeek = xptools_vfs_onSeek;
    result->cb.onTell = xptools_vfs_onTell;
    result->cb.onInfo = xptools_vfs_onInfo;
    
    // not used for now
    result->allocationCallbacks.pUserData = nullptr;
    result->allocationCallbacks.onMalloc = nullptr;
    result->allocationCallbacks.onRealloc = nullptr;
    result->allocationCallbacks.onFree = nullptr;
    
    return result;
}

// --------------------------------------------------
// MARK: - Engine type -
// --------------------------------------------------

// MARK: - public -

AudioEngine *AudioEngine::shared() {
    static AudioEngine *sharedInstance = nullptr;
    if (sharedInstance == nullptr) {
        sharedInstance = new AudioEngine();
        // vx_assert(sharedInstance != nullptr);
    }
    return sharedInstance;
}

AudioEngine::~AudioEngine() {
    ma_engine_uninit(&_engine);
    free(_vfs);
    _vfs = nullptr;
}


Sound *AudioEngine::createSound(const std::string &soundName, bool looping) {
    return new Sound(this, soundName, looping);
}

Listener *AudioEngine::createListener() {
    return new Listener(this);
}

bool AudioEngine::setVolume(float volumePercentage) {
    if (volumePercentage < 0.0f || volumePercentage > 1.0f) {
        return false;
    }

    ma_result result = ma_engine_set_volume(&_engine, volumePercentage);
    if (result != MA_SUCCESS) {
        return false;
    }

    return true;
}

// MARK: - private -

AudioEngine::AudioEngine() {
    
    ma_result result;
    
    // vfs
    _vfs = xptools_vfs_init();

    // create engine with config
    ma_engine_config engineConfig = ma_engine_config_init();
    engineConfig.listenerCount = 1;
    engineConfig.pResourceManagerVFS = _vfs;

    result = ma_engine_init(&engineConfig, &_engine);
    if (result != MA_SUCCESS) {
        // failed to initialize the engine.
        return;
    }
}

// --------------------------------------------------
// MARK: - SoundsTicks type -
// --------------------------------------------------

SoundsTicks::SoundsTicks():
_sounds() {}

SoundsTicks::~SoundsTicks() {

}

SoundsTicks *SoundsTicks::shared() {
    static SoundsTicks *instance = nullptr;
    if (instance == nullptr) {
        instance = new SoundsTicks();
    }
    return instance;
}

void SoundsTicks::tick(const double dt) {
    if (_sounds.size() == 0) {
        return;
    }

    Sound_SharedPtr sptr;
    for (std::vector<Sound_WeakPtr>::iterator it = _sounds.begin(); it != _sounds.end();) {
        sptr = (*it).lock();
        if (sptr != nullptr) {
            sptr->tick(dt);
            it++;
        } else {
            // remove sound reference from the list
            it = _sounds.erase(it);
        }
    }
}

void SoundsTicks::addSound(const Sound_SharedPtr sound) {
    Sound_WeakPtr soundWeakRef = sound;
    _sounds.push_back(soundWeakRef);
}

// --------------------------------------------------
// MARK: - Sound type -
// --------------------------------------------------

// MARK: - public -
Sound::Sound(AudioEngine * const engine, const std::string& soundName, const bool looping) :
_weakSelf(),
_retainer(),
_soundName(soundName),
_startAt(-1.0f),
_stopAt(-1.0f),
_duration(0.0f),
_originalDuration(0.0f),
_volume(1.0f),
_hasDefaultRadiusRatio(true),
_pitch(1.0f),
_looping(looping),
_playScheduled(false),
_timeSinceStartOfPlay(-1.0),
_timeSinceStartOfFade(-1.0),
_startFrame(0),
_sampleRate(0) {}

Sound_SharedPtr Sound::make(AudioEngine * const engine, const std::string& soundName, const bool looping) {
    assert(engine != nullptr);

    Sound_SharedPtr newSound(new Sound(engine, soundName, looping));
    newSound->_weakSelf = newSound;

    bool ok = newSound->init(engine, soundName);
    if (ok == false) {
        return nullptr;
    }

    SoundsTicks::shared()->addSound(newSound);

    return newSound;
}
    
bool Sound::init(AudioEngine * const engine, const std::string& soundName) {
    ma_result result;
    
    // maybe we should use "ma_sound_init_from_data_source"
    // - Spatialization is enabled by default
    result = ma_sound_init_from_file(&(engine->_engine), soundName.c_str(), 0, nullptr, nullptr, &_ma_sound);
    if (result != MA_SUCCESS) {
        // error
        vxlog_error("[vx::audio::Sound] failed to init Sound object (1)");
        return false;
    }
    
    // default tweaking values
    ma_sound_set_rolloff(&_ma_sound, 1.0f);
    ma_sound_set_min_distance(&_ma_sound, DEFAULT_MAX_DISTANCE * DEFAULT_RADIUS_RATIO);
    ma_sound_set_max_distance(&_ma_sound, DEFAULT_MAX_DISTANCE);
    ma_sound_set_volume(&_ma_sound, _volume);

    // retreive information about the sound
    result = ma_sound_get_data_format(&_ma_sound, nullptr, nullptr, &_sampleRate, nullptr, 0);
    if (result != MA_SUCCESS || _sampleRate == 0) {
        vxlog_error("[vx::audio::Sound] failed to retreive format.");
        return false;
    }

    ma_uint64 nbFrames;
    result = ma_data_source_get_length_in_pcm_frames(&_ma_sound, &nbFrames);
    if (result != MA_SUCCESS) {
        nbFrames = static_cast<ma_uint64>(this->getNbSamplesFromOggFile());
    }

    _originalDuration = static_cast<float>(nbFrames) / static_cast<float>(_sampleRate);

    // reset
    result = ma_sound_seek_to_pcm_frame(&_ma_sound, 0);
    if (result != MA_SUCCESS) {
        vxlog_error("[vx::audio::Sound] failed to init Sound object (3)");
        return false;
    }

    _duration = _originalDuration / _pitch;

    return true;
}

Sound::~Sound() {
    ma_sound_stop(&_ma_sound);
    ma_sound_uninit(&_ma_sound);
}

void Sound::tick(double dt) {
    if (_playScheduled && ma_sound_is_playing(&_ma_sound) == MA_FALSE) {
        // fade out is done, play again
        _playScheduled = false;
        this->play();
        return;
    }

    if (_timeSinceStartOfPlay > -1.0) {
        _timeSinceStartOfPlay += dt;
    }

    if (_timeSinceStartOfFade > -1.0) {
        _timeSinceStartOfFade += dt;
    }

    // handle stopAt
    if (_looping == false && _timeSinceStartOfPlay >= static_cast<double>(_duration)) {
        this->fadeOut();
    }

    if (_timeSinceStartOfFade >= CUT_WAIT_DURATION_AFTER_FADE_SEC) {
        this->stopWithoutFadeOut();
    }
}

void Sound::play() {
    ma_result result;

    if (ma_sound_is_playing(&_ma_sound) == MA_TRUE) {
        // stop the sound and schedule another play after the fade
        _playScheduled = true;
        this->stop();
        return;
    }

    result = ma_sound_seek_to_pcm_frame(&_ma_sound, 0);
    if (result != MA_SUCCESS) {
        vxlog_error("play (1)");
        return;
    }

    // reset volume
    ma_sound_set_volume(&_ma_sound, _volume);

    // sound has been paused
    if (_startFrame != 0) {
        result = ma_sound_seek_to_pcm_frame(&_ma_sound, _startFrame);
        if (result != MA_SUCCESS) {
            vxlog_error("[Sound::play] failed to set the startAt value");
        }
        _startFrame = 0; // reset
    } else if (this->getStartAtEnabled()) {
        ma_uint64 startAtFrame = static_cast<ma_uint64>(_startAt * static_cast<float>(_sampleRate));
        result = ma_sound_seek_to_pcm_frame(&_ma_sound, startAtFrame);
        if (result != MA_SUCCESS) {
            vxlog_error("[Sound::play] failed to set the startAt value");
        }
    }
    
    // fade in
    const ma_uint64 fadeDuration = static_cast<ma_uint64>(static_cast<float>(_sampleRate) * FADE_DURATION_SEC);
    ma_sound_set_fade_in_pcm_frames(&_ma_sound, 0.0, _volume, fadeDuration);

    ma_sound_set_looping(&_ma_sound, _looping);

    _timeSinceStartOfPlay = 0.0;
    _timeSinceStartOfFade = -1.0;

    result = ma_sound_start(&_ma_sound);
    if (result != MA_SUCCESS) {
        vxlog_error("play (2)");
        return;
    }
}

void Sound::pause() {
    if (ma_sound_is_playing(&_ma_sound) == MA_FALSE) {
        return;
    }

    // keep track of where we are
    if (ma_sound_get_cursor_in_pcm_frames(&_ma_sound, &_startFrame) != MA_SUCCESS) {
        vxlog_error("audio: error during pause");
        _startFrame = 0;
    }

    this->fadeOut();
}

void Sound::stop() {
    if (ma_sound_is_playing(&_ma_sound) == MA_FALSE) {
        return;
    }

    _startFrame = 0;

    this->fadeOut();
}

void Sound::stopWithoutFadeOut() {
    ma_sound_stop(&_ma_sound);

    _retainer = nullptr;
}

bool Sound::isPlaying() {
    return ma_sound_is_playing(&_ma_sound) == MA_TRUE;
}

bool Sound::getSpatialized() {
    const ma_bool32 enabled = ma_sound_is_spatialization_enabled(&_ma_sound);
    return enabled == MA_TRUE;
}

void Sound::setSpatialized(const bool spatialized) {
    const ma_bool32 enabled = spatialized ? MA_TRUE : MA_FALSE;
    ma_sound_set_spatialization_enabled(&_ma_sound, enabled);
    
    if (spatialized) {
        ma_sound_set_attenuation_model(&_ma_sound, ma_attenuation_model_linear);
        // ma_sound_set_position(&_ma_sound, float x, float y, float z)
    }
}

bool Sound::getLooping() {
    return _looping;
}

void Sound::setLooping(const bool loop) {
    _looping = loop;
    ma_sound_set_looping(&_ma_sound, loop);
}

// must be set before calling play()
bool Sound::setStartAt(float newValue) {
    if (newValue > _originalDuration || newValue < 0.0f) {
        return false;
    }

    if (this->getStopAtEnabled() && newValue > _stopAt) {
        // can't stop before starting
        return false;
    }

    _startAt = newValue;

    this->updateDuration();

    return true;
}

void Sound::disableStartAt() {
    _startAt = -1.0f;

    this->updateDuration();
}

// must be set before calling play()
bool Sound::setStopAt(float newValue) {
    if (newValue > _originalDuration || newValue < 0.0f) {
        return false;
    }

    if (newValue < _startAt) {
        // can't stop before starting
        return false;
    }

    _stopAt = newValue;

    this->updateDuration();

    return true;
}

void Sound::disableStopAt() {
    _stopAt = -1.0f;

    this->updateDuration();
}

void Sound::fadeOut() {
    // -1.0f: start from current volume
    const ma_uint64 fadeDuration = static_cast<ma_uint64>(static_cast<float>(_sampleRate) * FADE_DURATION_SEC);
    ma_sound_set_fade_in_pcm_frames(&_ma_sound, -1.0f, 0.0f, fadeDuration);

    _timeSinceStartOfPlay = -1.0; // fade out only once
    _timeSinceStartOfFade = 0.0;

    _retainer = _weakSelf.lock();
}

float Sound::getVolume() {
    return _volume;
}

float Sound::getOriginalDuration() {
    return _originalDuration;
}

void Sound::setVolume(float volume) {
    if (volume > 1.0f) {
        volume = 1.0f;
    }
    if (volume < 0.0f) {
        volume = 0.0f;
    }
    _volume = volume;
    ma_sound_set_volume(&_ma_sound, volume);
}

ma_engine *Sound::getEngine() {
    return ma_sound_get_engine(&_ma_sound);
}

float Sound::getMaxDistance() {
    return ma_sound_get_max_distance(&_ma_sound);
}

void Sound::setMaxDistance(float distance) {
    ma_sound_set_max_distance(&_ma_sound, distance);
    if (_hasDefaultRadiusRatio) {
        ma_sound_set_min_distance(&_ma_sound, distance * DEFAULT_RADIUS_RATIO);
    }
}

float Sound::getMinDistance() {
    return ma_sound_get_min_distance(&_ma_sound);
}

void Sound::setMinDistance(float distance) {
    ma_sound_set_min_distance(&_ma_sound, distance);
    _hasDefaultRadiusRatio = false;
}

float Sound::getPitch() {
    return _pitch;
}

void Sound::setPitch(float pitch) {
    if (pitch <= 0.001f) {
        pitch = 0.001f; // absolute 0 pitch makes no sense
    }
    ma_sound_set_pitch(&_ma_sound, pitch);

    _duration = _originalDuration / pitch;

    _pitch = pitch;
}

float Sound::getPan() {
    float pan = ma_sound_get_pan(&_ma_sound);
    if (pan > 1.0f) {
        pan = 1.0f;
    }
    if (pan < -1.0f) {
        pan = -1.0f;
    }
    return pan;
}

void Sound::setPan(float pan) {
    if (pan > 1.0f) {
        pan = 1.0f;
    }
    if (pan < -1.0f) {
        pan = -1.0f;
    }
    ma_sound_set_pan(&_ma_sound, pan);
}

void Sound::getPosition(float& x, float& y, float& z) {
    const ma_vec3f p = ma_sound_get_position(&_ma_sound);
    x = p.x;
    y = p.y;
    z = p.z;
}

void Sound::setPosition(const float x, const float y, const float z) {
    ma_sound_set_position(&_ma_sound, x, y, z);
}

ma_uint32 Sound::getNbSamplesFromOggFile() {
    bool inCache = false;

    if (_soundName.rfind("cache/_audio_", 0) == 0) {
        inCache = true;
    } else {
        _soundName = "audio/" + _soundName;
    }

    FILE *fd;

    if (inCache) {
        fd = ::vx::fs::openStorageFile(_soundName.c_str());
    } else {
        fd = ::vx::fs::openBundleFile(_soundName.c_str());
    }

    if (fd == nullptr) {
        return 0.0f;
    }

    const size_t headerSize = 27;
    const uint8_t lastPageFlag = 0x04;
    size_t size = 0;
    ma_uint32 nbSamples = 0;

    uint8_t *data = static_cast<uint8_t *>(::vx::fs::getFileContent(fd, &size));
    if (size < headerSize) {
        return 0;
    }

    // look for last ogg page
    for (size_t i = size - headerSize; i > 0; --i) {
        if (data[i] == OGG_PAGE_HEADER[0] && data[i + 1] == OGG_PAGE_HEADER[1] &&
            data[i + 2] == OGG_PAGE_HEADER[2] && data[i + 3] == OGG_PAGE_HEADER[3] &&
            (data[i + 5] & lastPageFlag)) {
            // found the start of last header
            // read the 1st 32 bits of granule position (from byte 6 to byte 9)
            // (can go up to 24 h and 51 m at 48 kHz)
            nbSamples = static_cast<ma_uint32>(data[i + 6]) |
                        static_cast<ma_uint32>(data[i + 7] << 8) |
                        static_cast<ma_uint32>(data[i + 8] << 16) |
                        static_cast<ma_uint32>(data[i + 9] << 24);
            break;
        }
    }

    free(data);

    return nbSamples;
}

void Sound::updateDuration() {
    _duration = _originalDuration;

    if (this->getStartAtEnabled()) {
        _duration -= _startAt;
    }
    if (this->getStopAtEnabled()) {
        _duration -= _originalDuration - _stopAt;
    }

    _duration /= _pitch;
}

// --------------------------------------------------
// MARK: - Listener type -
// --------------------------------------------------

// uint32_t Listener::nextIndex = 0;

Listener::Listener(AudioEngine *engine) :
_engine(engine) {
    // allocate index to the new listener
    _listenerIndex = 0;
    // _listenerIndex = Listener::nextIndex;
    // Listener::nextIndex += 1;
}

Listener::~Listener() {
    
}

void Listener::getPosition(float& x, float& y, float& z) {
    const ma_vec3f p = ma_engine_listener_get_position(&_engine->_engine, _listenerIndex);
    x = p.x;
    y = p.y;
    z = p.z;
}

void Listener::setPosition(const float x, const float y, const float z) {
    ma_engine_listener_set_position(&_engine->_engine, _listenerIndex, x, y, z);
}

void Listener::getDirection(float& x, float& y, float& z) {
    const ma_vec3f dir = ma_engine_listener_get_direction(&_engine->_engine, _listenerIndex);
    x = dir.x;
    y = dir.y;
    z = dir.z;
}

void Listener::setDirection(const float x, const float y, const float z) {
    ma_engine_listener_set_direction(&_engine->_engine, _listenerIndex, x, y, z);
}

#endif
