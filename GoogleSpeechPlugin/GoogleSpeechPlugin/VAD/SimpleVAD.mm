//
//  SimpleVAD.cpp
//  GoogleSpeechPlugin
//
//  Created by Pavel on 30.08.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import "SimpleVAD.h"

#import <algorithm>
#import <numeric>
#import <cmath>

#import <Foundation/Foundation.h>


void SimpleVAD::feed(int32_t const* pcm, uint32_t samples)
{
    double rms = rootMeanSquare(pcm, samples);
    
    NSLog(@"rms = %lf", rms);
    
    was_voice_prev = was_voice_now;
    was_voice_now = rms > threshold;
    
    if (was_voice_prev && !was_voice_now)
        edge_called = false;
}

bool SimpleVAD::has_voice_now()
{
    return was_voice_now;
}

bool SimpleVAD::has_voice_prev()
{
    return was_voice_prev;
}

bool SimpleVAD::back_edge()
{
    if (edge_called)
        return false;
    edge_called = true;
    return was_voice_prev && !was_voice_now;
}

    
SimpleVAD::SimpleVAD(double threshold/* = 100.0*/) :
    was_voice_now(false),
    was_voice_prev(false),
    edge_called(true),
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

