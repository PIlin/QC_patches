//
//  SimpleVAD.h
//  GoogleSpeechPlugin
//
//  Created by Pavel on 30.08.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#ifndef GoogleSpeechPlugin_SimpleVAD_h
#define GoogleSpeechPlugin_SimpleVAD_h

#include "VAD.h"

// This VAD will compute root mean square value of the samples in the packet.
// If this value is higher than specified threshold, than SimpleVAD decides, that
// the packet contains voice.
class SimpleVAD : public VAD
{
public:
    virtual void feed(int32_t const* pcm, uint32_t samples);
    
    virtual bool has_voice_now();
    
    virtual bool has_voice_prev();
    
    virtual bool back_edge();
    
    SimpleVAD(double threshold = 100.0);
    
private:
    
    double rootMeanSquare(int32_t const* pcm, uint32_t samples);

    
    bool was_voice_now;
    bool was_voice_prev;
    bool edge_called;
    double threshold;
};


#endif
