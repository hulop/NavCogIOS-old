//
//  NavLocation.m
//  NavCog
//
//  Created by Cole Gleason on 12/11/15.
//  Copyright © 2015 Chengxiong Ruan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NavLocation.h"

@interface NavLocation ()

@property (strong, nonatomic) TopoMap *map;

@end

@implementation NavLocation

- (instancetype)initWithMap:(TopoMap *)map {
    self = [super init];
    if (self) {
        _map = map;
    }
    return self;
}

- (NavEdge *) getEdge {
    if (_map)
        return [_map getEdgeFromLayer:_layerID withEdgeID:_edgeID];
    else
        return nil;
}

@end