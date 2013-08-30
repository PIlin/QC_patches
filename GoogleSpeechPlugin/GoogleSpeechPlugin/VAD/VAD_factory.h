//
//  VAD_factory.h
//  GoogleSpeechPlugin
//
//  Created by Pavel on 30.08.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#ifndef GoogleSpeechPlugin_VAD_factory_h
#define GoogleSpeechPlugin_VAD_factory_h

struct VAD;

#if defined __cplusplus
extern "C" {
#endif

struct VAD* getSimpleVAD(double levelThreshold);

void destroyVAD(struct VAD* vad);

#if defined __cplusplus
}
#endif
    
    
#endif
