//
//  VAD_factory.cpp
//  GoogleSpeechPlugin
//
//  Created by Pavel on 30.08.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#include "VAD_factory.h"

#include "SimpleVAD.h"

struct VAD* getSimpleVAD()
{
    return new SimpleVAD;
}

void destroyVAD(VAD* vad)
{
    delete vad;
}