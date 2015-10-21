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
 
#ifndef HELLO_NAV_EDGE
#define HEELO_NAV_EDGE HI_NAV_EDGE

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "KDTreeLocalization.h"

@class NavNode;
@class NavLayer;
@class NavLocation;

enum EdgeType {EDGE_NORMAL, EDGE_NON_NAVIGATIONAL};

@interface NavEdge : NSObject

@property (nonatomic) enum EdgeType type;
@property (nonatomic) NSString *edgeID;
@property (nonatomic) int len;
@property (nonatomic) float ori1; // edge orientation when coming from node 1
@property (nonatomic) float ori2; // edge orientation when coming from node 2
@property (nonatomic) float minKnnDist;
@property (nonatomic) float maxKnnDist;
@property (strong, nonatomic) NavNode *node1;
@property (strong, nonatomic) NavNode *node2;
@property (strong, nonatomic) NSString *nodeID1; // node id of node 1
@property (strong, nonatomic) NSString *nodeID2; // node id of node 2
@property (strong, nonatomic) NSString *info1; // information needed when coming from node 1
@property (strong, nonatomic) NSString *info2; // information needed when coming from node 2
@property (strong, nonatomic) NavLayer *parentLayer;

- (void)initLocalization;
- (void)setLocalizationWithDataString:(NSString *)dataStr;
- (void)setLocalizationWithInstance:(KDTreeLocalization *)localization;
- (float)getOriFromNode:(NavNode *)node;
- (NSString *)getInfoFromNode:(NavNode *)node;
- (struct NavPoint)getCurrentPositionInEdgeUsingBeacons:(NSArray *)beacons;
- (NavNode *)checkValidEndNodeAtLocation:(NavLocation *)location;
- (NavEdge *)clone;

@end


#endif