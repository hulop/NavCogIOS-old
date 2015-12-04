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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#import "NavState.h"
#import "TopoMap.h"
#import "TTTOrdinalNumberFormatter.h"

@protocol NavMachineDelegate;

@interface NavMachine : NSObject <CLLocationManagerDelegate>

- (void)startNavigationOnTopoMap:(TopoMap *)topoMap fromNodeWithName:(NSString *)fromNodeName toNodeWithName:(NSString *)toNodeName usingBeaconsWithUUID:(NSString *)uuidstr andMajorID:(CLBeaconMajorValue)majorID withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled;
- (void)simulateNavigationOnTopoMap:(TopoMap *)topoMap usingLogFileWithPath:(NSString *)logFilePath usingBeaconsWithUUID:(NSString *)uuidstr withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled;
- (void)initializeOrientation;
- (void)triggerMotionWithData: (NSMutableDictionary*) data;
- (void)stopNavigation;
- (void)repeatInstruction;
- (void)announceSurroundInfo;
- (void)announceAccessibilityInfo;
- (void)triggerNextState;
- (NSArray *)getPathNodes;

@property (strong, nonatomic) id <NavMachineDelegate> delegate;

@end


@protocol NavMachineDelegate <NSObject>

- (void)navigationFinished;
- (void)navigationReadyToGo;

@end