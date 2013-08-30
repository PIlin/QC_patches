//
//  SimpleVAD.cpp
//  GoogleSpeechPlugin
//
//  Created by Pavel on 30.08.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#include "SimpleVAD.h"

#include <algorithm>
#include <numeric>
#include <cmath>




void SimpleVAD::feed(int32_t const* pcm, uint32_t samples)
{
    double rms = rootMeanSquare(pcm, samples);
    
    NSLog(@"rms = %lf", rms);
    
    was_voice_prev = was_voice_now;
    was_voice_now = rms > threshold;
    
    if (was_voice_prev && !was_voice_now)
        edge_called = NO;
}

BOOL SimpleVAD::has_voice_now()
{
    return was_voice_now;
}

BOOL SimpleVAD::has_voice_prev()
{
    return was_voice_prev;
}

BOOL SimpleVAD::back_edge()
{
    if (edge_called)
        return NO;
    edge_called = YES;
    return was_voice_prev && !was_voice_now;
}

    
SimpleVAD::SimpleVAD(double threshold/* = 100.0*/) :
    was_voice_now(NO),
    was_voice_prev(NO),
    edge_called(YES),
    threshold(threshold)
{}
    
double SimpleVAD::rootMeanSquare(int32_t const* pcm, uint32_t samples)
{
    if (!samples)
        return 0.0;
    
//    int32_t const* min = std::min_element(pcm, pcm + samples);
//    int32_t const* max = std::max_element(pcm, pcm + samples);
    
    int32_t sum = std::accumulate(pcm, pcm + samples, 0);
    double avg = sum / (double)samples;
    
    double summs = std::accumulate(pcm, pcm + samples, 0.0, [=](double init, int32_t v) {
        return init + pow(v - avg, 2.0);
    });
    
    double avgms = summs / (double) samples;
    double rms = sqrt(avgms);
    
//    NSLog(@"min = %d\tmax = %d\tavgms = %lf\trms = %lf", *min, *max, avgms, rms);
    
    return rms;
}

