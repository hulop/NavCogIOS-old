//
//  NavCurrentLocationManager.h
//  NavCog
//

#ifndef NavCurrentLocationManager_h
#define NavCurrentLocationManager_h

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "KDTreeLocalization.h"
#import "TopoMap.h"

#define CURRENT_LOCATION_NOTIFICATION_NAME "CurrentLocationNotification"

// This will be used for exploration. It will first find an edge
// you are in, then create a localization KDTree on that edge.
// It will provide notification updates, and other services may
// subscribe to those.
// How do we handle transitions to other edges?

@interface NavCurrentLocationManager : NSObject

@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (nonatomic) TopoMap *topoMap;
@property (nonatomic) NavLocation *currentLocation;
@property (nonatomic) NavEdge *currentEdge;
@property (nonatomic) NavNode *currentNode;

@end;

#endif /* NavCurrentLocationManager_h */
