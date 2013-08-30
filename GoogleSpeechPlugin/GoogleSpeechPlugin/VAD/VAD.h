//
//  VAD.h
//  GoogleSpeechPlugin
//
//  Created by Pavel on 30.08.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#ifndef GoogleSpeechPlugin_VAD_h
#define GoogleSpeechPlugin_VAD_h

#include <stdint.h>

struct VAD
{
    virtual void feed(int32_t const* pcm, uint32_t samples) = 0;
    virtual bool has_voice_now() = 0;
    virtual bool has_voice_prev() = 0;
    
    virtual bool back_edge() = 0;
    
    virtual ~VAD() {}
};


#endif
