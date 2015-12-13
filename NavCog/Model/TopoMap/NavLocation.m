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

- (BOOL)isEqualToNavLocation:(NavLocation *)other {
    if (!other) {
        return NO;
    }
    
    BOOL sameEdge = (!self.edgeID && !other.edgeID) || [self.edgeID isEqualToString:other.edgeID];
    BOOL sameLayer = (!self.layerID && !other.layerID) || [self.layerID isEqualToString:other.layerID];
    
    
    return sameEdge && sameLayer && (self.xInEdge == other.xInEdge) && (self.yInEdge == other.yInEdge);
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[NavLocation class]]) {
        return NO;
    }
    
    return [self isEqualToNavLocation:(NavLocation *)object];
}

- (NSUInteger)hash {
    return [self.edgeID hash] ^ [self.layerID hash] ^ [@([self xInEdge]) hash] ^ [@([self yInEdge]) hash];
}

@end