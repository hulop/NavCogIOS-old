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

#import "NavLayer.h"
#import "NavNeighbor.h"
#import <Foundation/Foundation.h>

@interface NavLocation : NSObject

@property (strong, nonatomic) NSString *layerID;
@property (strong, nonatomic) NSString *edgeID;
@property (nonatomic) float yInEdge;
@property (nonatomic) float xInEdge;

@end

@interface TopoMap : NSObject

- (NavNode *)getNodeFromLayer:(NSString *)layerID withNodeID:(NSString *)nodeID;
- (NavEdge *)getEdgeFromLayer:(NSString *)layerID withEdgeID:(NSString *)edgeID;
- (NSString *)getUUIDString;
- (NSString *)getMajorIDString;
- (NSString *)initializaWithFile:(NSString *)filePath;
- (NSArray *)findShortestPathFromNodeWithName:(NSString *)fromName toNodeWithName:(NSString *)toName;
- (NSArray *)getAllLocationNamesOnMap;
- (NavLocation *)getCurrentLocationOnMapUsingBeacons:(NSArray *)beacons withInit:(Boolean)init;
- (NavLocation *)getLocationInEdges:(NSArray *)edges withBeacons:(NSArray *)beacons withKNNThreshold:(float)knnThreshold withInit:(Boolean)init;
- (NSArray *)findShortestPathFromCurrentLocation:(NavLocation *)curLocation toNodeWithName:(NSString *)toNodeName;
- (void)cleanTmpNodeAndEdges;

@end
