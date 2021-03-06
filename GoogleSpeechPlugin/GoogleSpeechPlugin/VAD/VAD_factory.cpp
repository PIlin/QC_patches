//
//  VAD_factory.cpp
//  GoogleSpeechPlugin
//
//  Created by Pavel on 30.08.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#include "VAD_factory.h"

#include "SimpleVAD.h"

struct VAD* getSimpleVAD(double levelThreshold)
{
    return new SimpleVAD(levelThreshold);
}

void destroyVAD(VAD* vad)
{
    delete vad;
}