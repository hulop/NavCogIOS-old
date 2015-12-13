//
//  NavLocation.h
//  NavCog
//
//  Created by Cole Gleason on 12/11/15.
//  Copyright © 2015 Chengxiong Ruan. All rights reserved.
//

#ifndef NavLocation_h
#define NavLocation_h

#import "TopoMap.h"
#import "NavEdge.h"

@class TopoMap;

@interface NavLocation : NSObject

@property (strong, nonatomic) NSString *layerID;
@property (strong, nonatomic) NSString *edgeID;
@property (nonatomic) float yInEdge;
@property (nonatomic) float xInEdge;

- (instancetype)initWithMap:(TopoMap *)map;
- (NavEdge *)getEdge;

@end

#endif /* NavLocation_h */
