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

#import "NavNode.h"

@interface NavNode ()

@end

@implementation NavNode

- (instancetype)init
{
    self = [super init];
    if (self) {
        _neighbors = [[NSMutableArray alloc] init];
        _infoFromEdges = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (Boolean)transitEnabledToNode:(NavNode *)node {
    NSDictionary *transitJson = [_transitInfo objectForKey:node.layerZIndex];
    Boolean transitEnabled = ((NSNumber *)[transitJson objectForKey:@"enabled"]).boolValue;
    if (transitEnabled) {
        NSString *nodeID = [transitJson objectForKey:@"node"];
        return [node.nodeID isEqualToString:nodeID] ? YES : NO;
    }
    return false;
}

- (Boolean)hasTransition {
    for (NSString *layerID in _transitInfo) {
        NSDictionary *transitJson = [_transitInfo objectForKey:layerID];
        Boolean transitEnabled = ((NSNumber *)[transitJson objectForKey:@"enabled"]).boolValue;
        if (transitEnabled) {
            return true;
        }
    }
    return false;
}

- (NSString *)getTransitInfoToNode:(NavNode *)node {
    NSDictionary *transitJson = [_transitInfo objectForKey:node.layerZIndex];
    Boolean transitEnabled = ((NSNumber *)[transitJson objectForKey:@"enabled"]).boolValue;
    if (transitEnabled) {
        NSString *nodeID = [transitJson objectForKey:@"node"];
        return [node.nodeID isEqualToString:nodeID] ? [transitJson objectForKey:@"info"] : nil;
    }
    return nil;
}

- (float)getXInEdgeWithID:(NSString *)edgeID {
    NSDictionary *infoFromEdgeJson = [_infoFromEdges objectForKey:edgeID];
    return infoFromEdgeJson == nil ? INT32_MIN : ((NSNumber *)[infoFromEdgeJson objectForKey:@"x"]).floatValue;
}

- (float)getYInEdgeWithID:(NSString *)edgeID {
    NSDictionary *infoFromEdgeJson = [_infoFromEdges objectForKey:edgeID];
    return infoFromEdgeJson == nil ? INT32_MIN : ((NSNumber *)[infoFromEdgeJson objectForKey:@"y"]).floatValue;
}

- (NSString *)getInfoComingFromEdgeWithID:(NSString *)edgeID {
    NSDictionary *infoFromEdgeJson = [_infoFromEdges objectForKey:edgeID];
    return infoFromEdgeJson == nil ? @"" : [infoFromEdgeJson objectForKey:@"info"];
}

- (NSString *)getDestInfoComingFromEdgeWithID:(NSString *)edgeID {
    NSDictionary *infoFromEdgeJson = [_infoFromEdges objectForKey:edgeID];
    return infoFromEdgeJson == nil ? @"" : [infoFromEdgeJson objectForKey:@"destInfo"];
}

- (Boolean)isTrickyComingFromEdgeWithID:(NSString *)edgeID {
    NSDictionary *infoFromEdgeJson = [_infoFromEdges objectForKey:edgeID];
    if (infoFromEdgeJson != nil) {
        Boolean isTricky = ((NSNumber *)[infoFromEdgeJson objectForKey:@"beTricky"]).boolValue;
        return isTricky;
    }
    return false;
}

- (NSString *)getTrickyInfoComingFromEdgeWithID:(NSString *)edgeID {
    NSDictionary *infoFromEdgeJson = [_infoFromEdges objectForKey:edgeID];
    if (infoFromEdgeJson != nil) {
        Boolean isTricky = ((NSNumber *)[infoFromEdgeJson objectForKey:@"beTricky"]).boolValue;
        return isTricky ? [infoFromEdgeJson objectForKey:@"trickyInfo"] : nil;
    }
    return nil;
}

@end
