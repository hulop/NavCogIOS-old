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

#import "NavEdge.h"
#import "NavNode.h"
#import <AVFoundation/AVFoundation.h>

@interface NavEdge ()

@property (strong, nonatomic) KDTreeLocalization *localization;

@end

@implementation NavEdge

- (float)getOriFromNode:(NavNode *)node {
    if (node == _node1) {
        return _ori1;
    } else {
        return _ori2;
    }
}

- (NSString *)getInfoFromNode:(NavNode *)node {
    if (node == _node1) {
        return _info1;
    } else {
        return _info2;
    }
}

- (void)setLocalizationWithDataString:(NSString *)dataStr {
    _localization = [[KDTreeLocalization alloc] init];

    // sscanf is very slow so save as temp file before loading
    // https://bugs.launchpad.net/ubuntu/+source/glibc/+bug/1391510
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent: @"nav_edge_temp.txt"];
    NSError *error;
    [dataStr writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    [_localization initializeWithAbsolutePath:tempPath];
}

- (void)initLocalization {
    [_localization initializaState];
}

- (struct NavPoint)getCurrentPositionInEdgeUsingBeacons:(NSArray *)beacons {
    return [_localization localizeWithBeacons:beacons];
}

@end
