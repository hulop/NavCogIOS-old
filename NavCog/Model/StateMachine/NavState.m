/*******************************************************************************
 * Copyright (c) 2015 Chengxiong Ruan
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/



#import "NavState.h"
#import "NavCogFuncViewController.h"
#import "NavCogMainViewController.h"
#import "NavNotificationSpeaker.h"
#import "NavLog.h"

@interface NavState ()

@property (nonatomic) Boolean bstarted;
@property (nonatomic) float preAnnounceDist;
@property (nonatomic) Boolean did40feet;
@property (nonatomic) Boolean didApproaching;
@property (nonatomic) Boolean didTrickyNotification;
@property (nonatomic) int longDistAnnounceCount;
@property (nonatomic) int targetLongDistAnnounceCount;
@property (strong, nonatomic) NSTimer *audioTimer;

@end

@implementation NavState

- (instancetype)init
{
    self = [super init];
    if (self) {
        _bstarted = false;
        _preAnnounceDist = INT_MAX;
        _did40feet = false;
        _didApproaching = false;
        _nextState = nil;
        _isTricky = false;
        _didTrickyNotification = false;
    }
    return self;
}

- (void)setWalkingEdge:(NavEdge *)walkingEdge {
    _walkingEdge = walkingEdge;
    _preAnnounceDist = walkingEdge.len;
    _longDistAnnounceCount = _preAnnounceDist / 30;
    if (ABS(walkingEdge.len - _longDistAnnounceCount * 30) <= 10) {
        _longDistAnnounceCount --;
    }
    _targetLongDistAnnounceCount = _longDistAnnounceCount;
}

- (Boolean)checkStateStatusUsingBeacons:(NSArray *)beacons withSpeechOn:(Boolean)isSpeechEnabled withClickOn:(Boolean)isClickEnabled {
    if (!_bstarted) {
        _bstarted = true;
        if (_type == STATE_TYPE_WALKING && _walkingEdge.len < 40) {
            _did40feet = true;
        }
        
        // if the distance is less than 30, then it's not necessary to announce 20
        if (_type == STATE_TYPE_WALKING && _walkingEdge.len <= 20) {
            _didApproaching = true;
        }
        if (_type == STATE_TYPE_TRANSITION) {
            [_targetEdge initLocalization];
        } else {
            [_walkingEdge initLocalization];
        }
        
        [self speakInstructionImmediately:_stateStartInfo];
        if (_type == STATE_TYPE_TRANSITION || isClickEnabled) {
            _audioTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(playClickSound) userInfo:nil repeats:YES];
            [_audioTimer fire];
        }
        return false;
    }
    // get position and push to visual map
    struct NavPoint pos;
    if (_type == STATE_TYPE_WALKING) {
        pos = [_walkingEdge getCurrentPositionInEdgeUsingBeacons:beacons];
        float cy = pos.y;
        float slat = _startNode.lat;
        float slng = _startNode.lng;
        float tlat = _targetNode.lat;
        float tlng = _targetNode.lng;
        float ratio = (cy - _sy) / (_ty - _sy);
        ratio = ratio < 0 ? 0 : ratio;
        ratio = ratio > 1 ? 1 : ratio;
        float lat = slat + ratio * (tlat - slat);
        float lng = slng + ratio * (tlng - slng);
        NSString *cmd = [NSString stringWithFormat:@"updateBlueDot({lat:%f, lng:%f})", lat, lng];
        [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
    } else {
        pos = [_targetEdge getCurrentPositionInEdgeUsingBeacons:beacons];
    }
    
    NSMutableArray *data = [[NSMutableArray alloc] init];
    [data addObject:[NSNumber numberWithFloat:pos.x]];
    [data addObject:[NSNumber numberWithFloat:pos.y]];
    [data addObject:[NSNumber numberWithFloat:pos.knndist]];
    NavEdge *edge = _type == STATE_TYPE_WALKING ? _walkingEdge : _targetEdge;
    [data addObject:edge.edgeID];
    [data addObject:[NSNumber numberWithFloat:edge.len]];
    [data addObject:[NSNumber numberWithFloat:ABS(pos.y - _ty)]];
    [NavLog logArray:data withType:@"CurrentPosition"];
    
    
    //float dist = sqrtf((pos.x - _tx) * (pos.x - _tx) + (pos.y - _ty) * (pos.y - _ty)); // use this if you use 2d
    float dist = ABS(pos.y - _ty); // use this if you use 1d, x has no affects
    if (dist < 50 && _isTricky && !_didTrickyNotification) {
        _didTrickyNotification = true;
        [NavNotificationSpeaker speakImmediatelyAndSlowly:NSLocalizedString(@"accessNotif", @"Alert that an accessibility notification is available")];
    }
    float threshold = 5;
    if (_type == STATE_TYPE_WALKING) {
        NSString *distFormat = NSLocalizedString(@"feetFormat", @"Use to express a distance in feet");
        // if you're walking, check distance to target node
        if (dist < _preAnnounceDist) {
            if (dist > 40.0) { // announce every 30 feet
                if (dist <= 30 * _longDistAnnounceCount + threshold) {
                    if (isSpeechEnabled) {
                        [self speakInstructionImmediately:[NSString stringWithFormat:distFormat, _longDistAnnounceCount * 30]];
                    } else {
                        _previousInstruction = [NSString stringWithFormat:distFormat, _longDistAnnounceCount * 30];
                    }
                    _preAnnounceDist = _longDistAnnounceCount * 30;
                    _longDistAnnounceCount --;
                    return false;
                }
            } else if (!_did40feet && dist <= 40 + threshold) {
                if (isSpeechEnabled) {
                    [self speakInstructionImmediately:[NSString stringWithFormat:distFormat, 40]];
                } else {
                    _previousInstruction = [NSString stringWithFormat:distFormat, 40];
                }
                _preAnnounceDist = 40;
                _did40feet = true;
                return false;
            } else if (!_didApproaching && dist <= 20 + threshold) {
                if (isClickEnabled) {
                    [self stopAudios];
                    _audioTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(playClickSound) userInfo:nil repeats:YES];
                    [_audioTimer fire];
                }
                if (_approachingInfo != nil) {
                    if (isSpeechEnabled) {
                        [self speakInstructionImmediately:_approachingInfo];
                    } else {
                        _previousInstruction = _approachingInfo;
                    }
                } else {
                    NSString *approaching = NSLocalizedString(@"approaching", @"Spoken when approaching specific nodes");
                    if (isSpeechEnabled) {
                        [self speakInstructionImmediately:approaching];
                    } else {
                        _previousInstruction = approaching;
                    }
                }
                _didApproaching = true;
                return false;
            } else if (dist <= 2 + threshold) {
                _bstarted = false;
                _longDistAnnounceCount = _targetLongDistAnnounceCount;
                _did40feet = _walkingEdge.len < 40 ? true : false;
                _didApproaching = _walkingEdge.len < 20 ? true : false;
                [self stopAudios];
                if (_arrivedInfo != nil) {
                    [self speakInstructionImmediately:_arrivedInfo];
                }
                NSString *cmd = [NSString stringWithFormat:@"updateBlueDot({lat:%f, lng:%f})", _targetNode.lat, _targetNode.lng];
                [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
                return true;
            }
        }
    } else if (_type == STATE_TYPE_TRANSITION) {
        pos.knndist = (pos.knndist - _targetEdge.minKnnDist) / (_targetEdge.maxKnnDist - _targetEdge.minKnnDist);
        pos.knndist = pos.knndist < 0 ? 0 : pos.knndist;
        pos.knndist = pos.knndist > 1 ? 1 : pos.knndist;
        
        NSLog(@"type=%d y=%f knnDist=%f dist=%f", _type, pos.y, pos.knndist, dist);

        if (_targetNode.type == NODE_TYPE_DOOR_TRANSIT || _targetNode.type == NODE_TYPE_STAIR_TRANSIT) {
            if (pos.knndist < _targetNode.transitKnnDistThres && dist < _targetNode.transitPosThres) {
                NSString *cmd = [NSString stringWithFormat:@"switchToLayerWithID('%@')", _targetNode.layerZIndex];
                [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
                [self stopAudios];
                return true;
            }
            return false;
        } else if (_targetNode.type == NODE_TYPE_ELEVATOR_TRANSIT) {
            if (pos.knndist < _targetNode.transitKnnDistThres) {
                NSString *cmd = [NSString stringWithFormat:@"switchToLayerWithID('%@')", _targetNode.layerZIndex];
                [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
                [self stopAudios];
                return true;
            }
            return false;
        }
    }
    return false;
}

- (void)repeatPreviousInstruction {
    if (_previousInstruction != nil) {
        if ([_previousInstruction containsString:NSLocalizedString(@"feet", @"A unit of distance in feet")] && ([_previousInstruction length] == 8 || [_previousInstruction length] == 7)) {
            [self speakInstructionImmediately:[NSString stringWithFormat:NSLocalizedString(@"andFormat", @"Used to join two instructions"), _previousInstruction, _nextActionInfo]];
        } else {
            [self speakInstructionImmediately:_previousInstruction];
        }
    }
}

- (void)announceSurroundInfo {
    if ([_surroundInfo isEqualToString:@""]) {
        [NavNotificationSpeaker speakImmediatelyAndSlowly:NSLocalizedString(@"noInformation", @"Spoken when no information is available")];
    } else {
        [NavNotificationSpeaker speakImmediatelyAndSlowly:_surroundInfo];
    }
}

- (void)announceAccessibilityInfo {
    if (_trickyInfo != nil) {
        [NavNotificationSpeaker speakImmediatelyAndSlowly:_trickyInfo];
    }
}

- (void)playClickSound {
    [NavSoundEffects playClickSound];
}

- (void)stopAudios {
    if (_audioTimer != nil) {
        [_audioTimer invalidate];
        _audioTimer = nil;
    }
}

- (void)speakInstruction:(NSString *)str {
    _previousInstruction = str;
    [NavNotificationSpeaker speakWithCustomizedSpeed:str];
}

- (void)speakInstructionImmediately:(NSString *)str {
    _previousInstruction = str;
    [NavNotificationSpeaker speakWithCustomizedSpeedImmediately:str];
}

@end
