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

#import "NavMachine.h"
#import "NavNotificationSpeaker.h"
#import "NavCogFuncViewController.h"
#import "NavLog.h"

enum NavigationState {NAV_STATE_IDLE, NAV_STATE_INIT, NAV_STATE_WALKING, NAV_STATE_TURNING};

@interface NavMachine ()

@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NavState *initialState;
@property (strong, nonatomic) NavState *currentState;
@property (strong, nonatomic) NavLocation *currentLocation;
@property (strong, nonatomic) NavLocation *previousLocation;
@property (nonatomic) enum NavigationState navState;
@property (nonatomic) float curOri;
@property (nonatomic) float gyroDrift;
@property (nonatomic) float gyroDriftMultiplier;
@property (nonatomic) float gyroDriftLimit;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic) Boolean logReplay;
@property (nonatomic) Boolean speechEnabled;
@property (nonatomic) Boolean clickEnabled;
@property (nonatomic) Boolean isStartFromCurrentLocation;
@property (nonatomic) Boolean isNavigationStarted;
@property (strong, nonatomic) NSString *destNodeName;
@property (strong, atomic) NSArray *pathNodes;
@property (strong, nonatomic) TopoMap *topoMap;
@property (strong, nonatomic) NSString *lastPre, *lastAccess, *lastSurround;

@end

double clipAngle(double x) { //clips the angle between 0 and 360
    x = fmod(x, 360);
    if (x<0)
        x+=360;

        return x;
}

double clipAngle2(double x) { //clips the angle between -180 and 180
    x = fmod(x+180, 360);
    if (x<0)
        x+=360;

    return x-180;
}

double limitAngle(double x, double l) { //limits angle change to l
    if (x > l)
        return l;
    else if (x < -l)
        return -l;
    else
        return x;
}

@implementation NavMachine

- (instancetype)init
{
    self = [super init];
    if (self) {
        _logReplay = false;
        _gyroDrift = -110;
        _gyroDriftMultiplier = 100;
        _gyroDriftLimit = 3;
        _initialState = nil;
        _currentState = nil;
        _currentLocation = nil;
        _previousLocation = nil;
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 0.1;
        _motionManager.accelerometerUpdateInterval = 0.01;
        _navState = NAV_STATE_IDLE;
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
        [_dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EDT"]];
    }
    return self;
}

// initialize the state machine with a new path of nodes
- (void)initializeWithPathNodes:(NSArray *)pathNodes {
    _initialState = nil;
    _currentState = nil;
    _navState = NAV_STATE_IDLE;
    for (int i = (int)[pathNodes count] - 1; i >= 1; i--) {
        NavNode *node1 = [pathNodes objectAtIndex:i];
        NavNode *node2 = [pathNodes objectAtIndex:i-1];
        NSMutableString *startInfo = [[NSMutableString alloc] init];

        NavState *newState = [[NavState alloc] init];
        newState.startNode = node1;
        newState.targetNode = node2;

        // if node2 is node1's transit node, then is should be a transition.
        if ([node1 transitEnabledToNode:node2]) {
            newState.type = STATE_TYPE_TRANSITION;
            newState.surroundInfo = [node1 getTransitInfoToNode:node2];
            // targetEdge is used to check if we arrive at next edge or not
            // in our project, we presume that there's no Destination node with transition
            // so we depend on node3's preEdgeInPath to get node2' position
            if (i >= 2) {
                NavNode *node3 = [pathNodes objectAtIndex:i - 2];
                newState.targetEdge = node3.preEdgeInPath;
                [newState.targetEdge initLocalization];
                newState.tx = [node2 getXInEdgeWithID:node3.preEdgeInPath.edgeID];
                newState.ty = [node2 getYInEdgeWithID:node3.preEdgeInPath.edgeID];
                newState.sx = [node3 getXInEdgeWithID:node3.preEdgeInPath.edgeID];// fix for snap min/max
                newState.sy = [node3 getYInEdgeWithID:node3.preEdgeInPath.edgeID];// fix for snap min/max
            }
            [startInfo appendString:[node1 getInfoComingFromEdgeWithID:node1.preEdgeInPath.edgeID]];
            switch (node1.type) {
                case NODE_TYPE_DOOR_TRANSIT:
                    break;
                case NODE_TYPE_STAIR_TRANSIT:
                    [startInfo appendFormat:NSLocalizedString(@"takeStairsFormat", @"Format string for taking the stairs"), [self getFloorString:node2.floor]];
                    [startInfo appendFormat:NSLocalizedString(@"currentlyOnFormat", @"Format string describes the floor you are currently on"), [self getFloorString:node1.floor]];
                    break;
                case NODE_TYPE_ELEVATOR_TRANSIT:
                    [startInfo appendFormat:NSLocalizedString(@"takeElevatorFormat", @"Format string for taking the elevator"), [self getFloorString:node2.floor]];
                    [startInfo appendFormat:NSLocalizedString(@"currentlyOnFormat", @"Format string describes the floor you are currently on"), [self getFloorString:node1.floor]];
                    break;
                default:
                    break;
            }
        } else {
            newState.type = STATE_TYPE_WALKING;
            newState.walkingEdge = node2.preEdgeInPath;
            [newState.walkingEdge initLocalization];
            newState.surroundInfo = [node2.preEdgeInPath getInfoFromNode:node1];
            newState.isTricky = [node2 isTrickyComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.trickyInfo = newState.isTricky ? [node2 getTrickyInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID] : nil;
            int edgeLen = [newState isMeter] ? [newState toMeter:node2.preEdgeInPath.len]:node2.preEdgeInPath.len;
            if (![node2.name isEqualToString:@""]) {
                [startInfo appendFormat:NSLocalizedString([newState isMeter]?@"meterToNameFormat":@"feetToNameFormat", @"format string describing the number of feet left to a named location"), edgeLen, node2.name];
            } else {
                [startInfo appendFormat:NSLocalizedString([newState isMeter]?@"meterPauseFormat":@"feetPauseFormat", @"Use to express a distance in feet with a pause"), edgeLen];
            }

            float curOri = [node2.preEdgeInPath getOriFromNode:node1];
            newState.ori = curOri;
            newState.sx = [node1 getXInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.sy = [node1 getYInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.tx = [node2 getXInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.ty = [node2 getYInEdgeWithID:node2.preEdgeInPath.edgeID];
            if (i >= 2) {
                NavNode *node3 = [pathNodes objectAtIndex:i - 2];
                [startInfo appendString:NSLocalizedString(@"and", "Simple and used to join two nodes.")];
                if ([node2 transitEnabledToNode:node3]) { // next state is a transition
                    switch (node2.type) {
                        case NODE_TYPE_DOOR_TRANSIT:
                            // for door transition node, we use node information
                            newState.nextActionInfo = [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                            [startInfo appendString:[node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                            break;
                        case NODE_TYPE_STAIR_TRANSIT:
                            if (node2.floor < node3.floor) {
                                newState.nextActionInfo = NSLocalizedString(@"goUpstairs", @"Short command telling the user to go upstairs");
                                [startInfo appendString:NSLocalizedString(@"goUpstairsStairCase", @"Command telling the user to go up the stairs using the stair case")];
                            } else {
                                newState.nextActionInfo = NSLocalizedString(@"goDownstairs", @"Short command telling the user to go downstairs");
                                [startInfo appendString:NSLocalizedString(@"goDownstairsStairCase", @"Command telling the user to go down the stairs using the stair case")];
                            }
                            break;
                        case NODE_TYPE_ELEVATOR_TRANSIT:
                            if (node2.floor < node3.floor) {
                                newState.nextActionInfo =NSLocalizedString(@"goUpstairsElevator", @"Command telling the user to go upstairs using the elevator");
                                [startInfo appendString:NSLocalizedString(@"takeUpstairsElevator", @"Command telling the user take the elevator upstairs")];
                            } else {
                                newState.nextActionInfo = NSLocalizedString(@"goDownstairsElevator", @"Command telling the user to go downstairs using the elevator");
                                [startInfo appendString:NSLocalizedString(@"takeDownstairsElevator", @"Command telling the user take the elevator downstairs")];
                            }
                            break;
                        default:
                            break;
                    }
                } else { // if next state is normal walking state, then pre-tell the turn
                    float nextOri = [node3.preEdgeInPath getOriFromNode:node2];
                    [startInfo appendString:[self getTurnStringFromOri:curOri toOri:nextOri]];
                    if (![node2 hasTransition] && node2.type != NODE_TYPE_DESTINATION) {
                        newState.arrivedInfo = [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                    }
                    newState.nextActionInfo = [self getTurnStringFromOri:curOri toOri:nextOri];
                    if (curOri != nextOri) {
                        newState.approachingInfo = [NSString stringWithFormat:NSLocalizedString(@"approachingToTurnFormat", @"Format string to tell the user they are approaching a turn"), [self getTurnStringFromOri:curOri toOri:nextOri]];
                    }
                }
            } else {
                newState.nextActionInfo = [NSString stringWithFormat:NSLocalizedString(@"destinationFormat", @"Format string for destination alert"), [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                newState.arrivedInfo = [node2 getDestInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                [startInfo appendString:[node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                [startInfo appendString:NSLocalizedString(@"destination", @"Destination alert")];
            }
        }

        if (![node1.buildingName isEqualToString:node2.buildingName]) {
            [startInfo appendString:[NSString stringWithFormat:NSLocalizedString(@"enteringFormat", @"Spoken when entering a location"), node2.buildingName]];
        }

        newState.stateStartInfo = startInfo;
        if (i == (int)[pathNodes count] - 1) {
            _initialState = newState;
        } else {
            _currentState.nextState = newState;
        }
        _currentState = newState;
    }

    _currentState = _initialState;
    // check if we need a initial turning

    if (_initialState.type == STATE_TYPE_WALKING) {
        float diff = clipAngle2(clipAngle2(_curOri - _gyroDrift) - clipAngle2(_initialState.ori));

        if (ABS(diff) > 15) { //have to rotate
            _currentState.previousInstruction = [self getTurnStringFromOri:clipAngle(_curOri-_gyroDrift) toOri:_currentState.ori];
            [NavNotificationSpeaker speakWithCustomizedSpeed:_currentState.previousInstruction];
            _navState = NAV_STATE_TURNING;
        } else { //straight
            _navState = NAV_STATE_WALKING;
        }
    }
    [self setHintTexts];

    NavState *state = _initialState;
    while (state != nil) {
        NSLog(@"*****************************************************************");
        NSLog(@"************                                          ***********");
        NSLog(@"*****************************************************************");
        NSLog(@"start info : %@", state.stateStartInfo);
        NSLog(@"approaching info : %@", state.approachingInfo);
        NSLog(@"arrived info : %@", state.arrivedInfo);
        NSLog(@"surounding info : %@", state.surroundInfo);
        NSLog(@"accessibility info : %@", state.trickyInfo);
        state = state.nextState;
    }
}

- (NSString *)getFloorString:(int)floor {
    NSString *ordinalNumber;

    // TODO(cgleason): find way to remove special case for floor numbering in Japanese
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    if([@"ja" compare:language] == NSOrderedSame) {
        ordinalNumber = [NSString stringWithFormat:@"%d", floor];
    } else {
        TTTOrdinalNumberFormatter*ordinalNumberFormatter = [[TTTOrdinalNumberFormatter alloc] init];
        [ordinalNumberFormatter setLocale:[NSLocale currentLocale]];
        [ordinalNumberFormatter setGrammaticalGender:TTTOrdinalNumberFormatterMaleGender];
        NSNumber *number = [NSNumber numberWithInteger:floor];
        ordinalNumber = [ordinalNumberFormatter stringFromNumber:number];
    }
    return [NSString stringWithFormat:NSLocalizedString(@"floorFormat", @"Format string for a floor that takes an ordinal number"), ordinalNumber];
}

- (NSString *)getTurnStringFromOri:(float)curOri toOri:(float)nextOri {
    curOri = clipAngle2(curOri);
    nextOri = clipAngle2(nextOri);

    float diff = clipAngle2(curOri - nextOri);

    NSString *slightLeft = NSLocalizedString(@"slightLeft", @"Instruction to turn slightly left");
    NSString *slightRight = NSLocalizedString(@"slightRight", @"Instruction to turn slightly right");
    NSString *turnLeft = NSLocalizedString(@"turnLeft", @"Instruction to turn left");
    NSString *turnRight = NSLocalizedString(@"turnRight", @"Instruction to turn right");
    NSString *keepStraight = NSLocalizedString(@"keepStraight", @"Instruction to keep straight");
    
    if (diff > 0) { //definitely right
        if (diff > 45) {
            return turnLeft;
        } else if (diff > 15) {
            return slightLeft;
        }
    } else { //definitely left
        if (diff < -45) {
            return turnRight;
        } else if (diff < -15) {
            return slightRight;
        }
    }

    return keepStraight;
}

- (NSString *)getTurnStringWithDegreeFromOri:(float)curOri toOri:(float)nextOri {
    if (curOri == nextOri || clipAngle2(curOri - nextOri) == -180) {
        return NSLocalizedString(@"keepStraight", @"Instruction to keep straight");
    }

    int diff = clipAngle(curOri - nextOri);
    NSString *leftFormat = NSLocalizedString(@"turnLeftDegreeFormat", @"Format string to turn left in degrees");
    NSString *rightFormat = NSLocalizedString(@"turnRightDegreeFormat", @"Format string to turn right in degrees");
    if (diff < 180) {
        return nextOri < curOri ? [NSString stringWithFormat:leftFormat, diff] : [NSString stringWithFormat:rightFormat, diff ];
    } else {
        return nextOri < curOri ? [NSString stringWithFormat:rightFormat, diff ] : [NSString stringWithFormat:leftFormat, diff] ;
    }

    return @"";
}

- (void)initializeOrientation {

    _gyroDrift = 0;
    [_motionManager stopDeviceMotionUpdates];
    [_motionManager startDeviceMotionUpdatesUsingReferenceFrame: CMAttitudeReferenceFrameXTrueNorthZVertical toQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *dm, NSError *error){
        if(!_logReplay) {
            NSMutableDictionary* motionData = [[NSMutableDictionary alloc] init];
            
            [motionData setObject: [[NSNumber alloc] initWithDouble: dm.attitude.pitch] forKey:@"pitch"];
            [motionData setObject: [[NSNumber alloc] initWithDouble: dm.attitude.roll] forKey:@"roll"];
            [motionData setObject: [[NSNumber alloc] initWithDouble: dm.attitude.yaw] forKey:@"yaw"];
            
            [self triggerMotionWithData:motionData];
        }
    }];

    [_motionManager stopAccelerometerUpdates];
    [_motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData *acc, NSError *error) {
        if(!_logReplay) {
            [NavLog logAcc:acc];
        }
    }];
}

- (void)triggerMotionWithData: (NSMutableDictionary*) data {

    NSNumber* yaw = [data objectForKey:@"yaw"];

    _curOri = - [yaw doubleValue] / M_PI * 180;

    [NavLog logMotion:data];
    [self logState];

    if (_navState == NAV_STATE_TURNING) {
        //if (ABS(_curOri - _currentState.ori) <= 10) {
        float diff = clipAngle2(clipAngle2(_curOri - _gyroDrift) - clipAngle2(_currentState.ori));
        if (ABS(diff) <= 10) {
            [NavSoundEffects playSuccessSound];
            _navState = NAV_STATE_WALKING;
            [self logState];
        }
    } else if ((_navState == NAV_STATE_WALKING) && (_currentState.type != STATE_TYPE_TRANSITION)) {
        double edgeori;
        if (_currentState.startNode == _currentState.walkingEdge.node1)
            edgeori = _currentState.walkingEdge.ori1;
        else
            edgeori = _currentState.walkingEdge.ori2;
        
//        double deltay = ABS(_currentState.walkingEdge.node1.lat - _currentState.walkingEdge.node2.lat);
//        double deltax = ABS(_currentState.walkingEdge.node1.lng - _currentState.walkingEdge.node2.lng);
//        double delta=sqrt(deltax*deltax+deltay*deltax);
        
//        if (delta > _gyroDriftMinEdgeLength) {
            //model that gracefully adapts to drift.
            _gyroDrift += clipAngle2(clipAngle2(_curOri - _gyroDrift) - clipAngle2(edgeori))/_gyroDriftMultiplier;
            //limit drift correction to some degrees each update. very naive
            //_gyroDrift += limitAngle(clipAngle2(_curOri - _gyroDrift - clipAngle2(edgeori)));
            //simple model that completely offsets drift
            //_gyroDrift = clipAngle2(_curOri - clipAngle2(edgeori));
            [NavLog logGyroDrift:_gyroDrift edge:clipAngle2(edgeori) curori:_curOri fixedDelta: clipAngle2(clipAngle2(_curOri - _gyroDrift) - clipAngle2(edgeori)) oldDelta: clipAngle2(_curOri - clipAngle2(edgeori))];
//        }
    }
}

//TODO: try to get pedometer updates and only update gyro drift on steps

- (NSString *)getTimeStamp {
    return [_dateFormatter stringFromDate:[NSDate date]];
}

- (void)startNavigationOnTopoMap:(TopoMap *)topoMap fromNodeWithName:(NSString *)fromNodeName toNodeWithName:(NSString *)toNodeName usingBeaconsWithUUID:(NSString *)uuidstr andMajorID:(CLBeaconMajorValue)majorID withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled {
    _logReplay = false;
    [NavLog startLog];
    [NavLog logArray:@[fromNodeName,toNodeName] withType:@"Route"];

    // set speech rate of notification speaker
    [NavNotificationSpeaker setFastSpeechOnAndOff:fastSpeechEnabled];

    // set UI type (speech and click sound)
    _speechEnabled = speechEnabled;
    _clickEnabled = clickEnabled;

    // search a path
    _topoMap = topoMap;
    _pathNodes = nil;
    _navState = NAV_STATE_INIT;
    if (![fromNodeName isEqualToString:NSLocalizedString(@"currentLocation", @"Current Location")]) {
        _pathNodes = [_topoMap findShortestPathFromNodeWithName:fromNodeName toNodeWithName:toNodeName];
        [self initializeWithPathNodes:_pathNodes];
        _isStartFromCurrentLocation = false;
        _isNavigationStarted = true;
        [_delegate navigationReadyToGo];
    } else {
        _destNodeName = toNodeName;
        _isStartFromCurrentLocation = true;
        _isNavigationStarted = false;
    }

    // start navigation
    _beaconManager = [[CLLocationManager alloc] init];
    if([_beaconManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [_beaconManager requestAlwaysAuthorization];
    }
    _beaconManager.delegate = self;
    _beaconManager.pausesLocationUpdatesAutomatically = NO;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidstr];
    _beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:majorID identifier:@"cmaccess"];
    [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
}

- (void)simulateNavigationOnTopoMap:(TopoMap *)topoMap usingLogFileWithPath:(NSString *)logFilePath usingBeaconsWithUUID:(NSString *)uuidstr withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled {
    _logReplay = true;

    //if started kill motionmanager
    [_motionManager stopAccelerometerUpdates];
    [_motionManager stopDeviceMotionUpdates];
    [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];

    NSString* fromNodeName;
    NSString* toNodeName;
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSDate* startTime;

    //parse log to array

    //create dictionary with time -> object: either motion or beaconlist
    NSMutableArray* timesArray = [[NSMutableArray alloc] init];
    NSMutableArray* objectsArray = [[NSMutableArray alloc] init];

    //motion holds just 3 values, beaconlist holds array of clbeacons
    NSString *fileContents = [NSString stringWithContentsOfFile:logFilePath encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *line in [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {

        if ([line isEqualToString:@""])
            break;

        //Explode the line with space
        if ([line length] < 23)
            continue;
        NSDate* dateAndTime = [dateFormat dateFromString:[line substringToIndex:23]];
        
        if (dateAndTime == nil)
            continue;
        
        NSArray *breakarray = [line componentsSeparatedByString:@"]"];
        if ([breakarray count] < 2)
            continue;
        
        NSString* typeAndData = [breakarray[1] substringFromIndex:1];
        NSArray *typeAndDataStringArray = [typeAndData componentsSeparatedByString:@","];

        if ([typeAndDataStringArray[0] isEqualToString: @"Route"]) {
            startTime = dateAndTime;
            fromNodeName = typeAndDataStringArray[1];
            toNodeName = typeAndDataStringArray[2];
        } else if ([typeAndDataStringArray[0] isEqualToString: @"Motion"]) {
            //get time
            NSDate* currentTime = dateAndTime;

            //create motion data object
            NSMutableDictionary* motionData = [[NSMutableDictionary alloc] init];

            [motionData setObject: [[NSNumber alloc] initWithFloat: [typeAndDataStringArray[1] floatValue]] forKey:@"pitch"];
            [motionData setObject: [[NSNumber alloc] initWithFloat: [typeAndDataStringArray[2] floatValue]] forKey:@"roll"];
            [motionData setObject: [[NSNumber alloc] initWithFloat: [typeAndDataStringArray[3] floatValue]] forKey:@"yaw"];

            //feed to object
            [timesArray addObject: currentTime];
            [objectsArray addObject: motionData];

        } else if ([typeAndDataStringArray[0] isEqualToString: @"Beacon"]) { //beacon data
            //get number of beacons
            int beaconsNumber = [typeAndDataStringArray[1] intValue];
            NSMutableArray* beaconArrayTmp = [NSMutableArray arrayWithCapacity:beaconsNumber];

            for (int i = 0; i < beaconsNumber; i++) {
                CLBeacon* newBeacon = [[CLBeacon alloc] init];
                [newBeacon setValue:[NSNumber numberWithInt:[typeAndDataStringArray[3*i+2] intValue]] forKey:@"major"];
                [newBeacon setValue:[NSNumber numberWithInt:[typeAndDataStringArray[3*i+3] intValue]] forKey:@"minor"];
                [newBeacon setValue:[NSNumber numberWithInt:[typeAndDataStringArray[3*i+4] intValue]] forKey:@"rssi"];
                [newBeacon setValue:[[NSUUID alloc] initWithUUIDString:uuidstr] forKey:@"proximityUUID"];

                [beaconArrayTmp addObject:newBeacon];
            }
            //transform it to nsarray
            NSArray* beaconArray = [NSArray arrayWithArray:beaconArrayTmp];
            //get time
            NSDate* currentTime = dateAndTime;

            //feed to object
            [timesArray addObject: currentTime];
            [objectsArray addObject: beaconArray];
        }
    }

    //logging
    [NavLog startLog];
    [NavLog logArray:@[fromNodeName,toNodeName] withType:@"Route"];
    // set speech rate of notification speaker
    [NavNotificationSpeaker setFastSpeechOnAndOff:fastSpeechEnabled];

    // set UI type (speech and click sound)
    _speechEnabled = speechEnabled;
    _clickEnabled = clickEnabled;

    // search a path
    _topoMap = topoMap;
    _pathNodes = nil;
    _navState = NAV_STATE_INIT;
    if (![fromNodeName isEqualToString:NSLocalizedString(@"currentLocation", @"Current Location")]) {
        _pathNodes = [_topoMap findShortestPathFromNodeWithName:fromNodeName toNodeWithName:toNodeName];
        [self initializeWithPathNodes:_pathNodes];
        _isStartFromCurrentLocation = false;
        _isNavigationStarted = true;
        [_delegate navigationReadyToGo];
    } else {
        _destNodeName = toNodeName;
        _isStartFromCurrentLocation = true;
        _isNavigationStarted = false;
    }

    dispatch_queue_t queue = dispatch_queue_create("com.navcog.logsimulatorqueue", NULL);

    unsigned long int arraySize = [timesArray count];

    dispatch_async(queue, ^{

        NSDate* time = startTime;

        for (int i=0; i < arraySize; i++) {

            if (_navState == NAV_STATE_IDLE)
                break;

            if ([objectsArray[i] isKindOfClass: [NSArray class]]) {
                //create
                NSTimeInterval waitTime = [timesArray[i] timeIntervalSinceDate:time];

                NSArray* beacons = objectsArray[i];

                //call beacons
                [NSThread sleepForTimeInterval:waitTime];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [self receivedBeaconsArray: beacons];
                });

                time = timesArray[i];

            } else if ([objectsArray[i] isKindOfClass: [NSMutableDictionary class]]) {

                NSTimeInterval waitTime = [timesArray[i] timeIntervalSinceDate:time];

                NSMutableDictionary* motionData = objectsArray[i];

                //call motion
                [NSThread sleepForTimeInterval:waitTime];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [self triggerMotionWithData:motionData];
                });

                time = timesArray[i];

            }

        }

        dispatch_sync(dispatch_get_main_queue(), ^{
            [self stopNavigation];
            [_delegate navigationFinished];
            _logReplay = false;
        });

    });

}

- (void)stopNavigation {
    [self stopAudio];
    [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
    [_topoMap cleanTmpNodeAndEdges];
    _navState = NAV_STATE_IDLE;
    _initialState = nil;
    _currentState = nil;
}

- (void)repeatInstruction {
    if (_currentState != nil) {
        [_currentState repeatPreviousInstruction];
    }
}

- (void)announceSurroundInfo {
    if (_currentState != nil) {
        [_currentState announceSurroundInfo];
    }
}

- (void)announceAccessibilityInfo {
    if (_currentState != nil && _currentState.isTricky) {
        [_currentState announceAccessibilityInfo];
    }
}

//TODO: this even used?
- (void)triggerNextState {
    if (!(_logReplay)) {
        [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
    }
    _currentState = _currentState.nextState;
    if (_currentState != nil) {
        if (!(_logReplay)) {
            [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
        }
    } else {
        [_delegate navigationFinished];
        [NavNotificationSpeaker speakWithCustomizedSpeed:NSLocalizedString(@"arrived", @"Spoken when you arrive at a destination")];
        [_topoMap cleanTmpNodeAndEdges];
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    if(!_logReplay) {
        [self receivedBeaconsArray:beacons];
    }
}

- (void)receivedBeaconsArray:(NSArray *)beacons {
    [NavLog logBeacons:beacons];
    [self logState];

    // if we start navigation from current location
    // and the navigation does not start yet
    if (_isStartFromCurrentLocation && !_isNavigationStarted) {
        //_previousLocation = _currentLocation;
        // if navigation has not started yet, then init all edge localization
        // otherwise ignore
        _currentLocation = [_topoMap getCurrentLocationOnMapUsingBeacons:beacons withInit:!_isNavigationStarted];
        if (_currentLocation.edgeID == nil)
            return;

        _pathNodes = [_topoMap findShortestPathFromCurrentLocation:_currentLocation toNodeWithName:_destNodeName];
        [self initializeWithPathNodes:_pathNodes];
        _isNavigationStarted = true;
        [_delegate navigationReadyToGo];
        NSLog(@"***********************************************");
        NSLog(@"layer : %@", _currentLocation.layerID);
        NSLog(@"edge : %@", _currentLocation.edgeID);
        NSLog(@"x : %f", _currentLocation.xInEdge);
        NSLog(@"y : %f", _currentLocation.yInEdge);
    } else {
        [self logState];
        if ([NavLog isLogging] == YES) {
            [_topoMap getCurrentLocationOnMapUsingBeacons:beacons withInit:NO];
        }
        if (_navState == NAV_STATE_TURNING && [beacons count] > 0) {
            // check if user keep moving to destination without turn
            struct NavPoint pos = [_currentState.walkingEdge getCurrentPositionInEdgeUsingBeacons:beacons];
            float startDist = [_currentState getStartDistance:pos];
            float startRatio = [_currentState getStartRatio:pos];
            if (startDist > 20 || (startDist > 10 && startRatio > 0.25)) {
                NSLog(@"ForceTurn,%f,%f",startDist, startRatio);
                [NavSoundEffects playSuccessSound];
                _navState = NAV_STATE_WALKING;
            }
        }
        if (_navState == NAV_STATE_WALKING) {
            if ([beacons count] > 0) {
                if ([_currentState checkStateStatusUsingBeacons:beacons withSpeechOn:_speechEnabled withClickOn:_clickEnabled]) {
                    NavState *prev = _currentState;
                    _currentState = _currentState.nextState;
                    _currentState.prevState = prev;
                    if (_currentState == nil) {
                        [_delegate navigationFinished];
                        [NavNotificationSpeaker speakWithCustomizedSpeed:NSLocalizedString(@"arrived", @"Spoken when you arrive at a destination")];
                        [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
                        [_topoMap cleanTmpNodeAndEdges];
                    } else if (_currentState.type == STATE_TYPE_WALKING) {
                        // Attempt to do gyro drift updates only while moving. however the localization is not reliable enough to use it
                        //                    if(_previousLocation != nil) {
                        //                        if(_currentLocation.edgeID == _previousLocation.edgeID) {
                        //                            //calculate delta, TODO: only validate delta in forward direction
                        //                            double deltax = _currentLocation.xInEdge-_previousLocation.xInEdge;
                        //                            double deltay = _currentLocation.yInEdge-_previousLocation.yInEdge;
                        //                            double delta = sqrt(deltax*deltax+deltay*deltay);
                        //                            if (delta > _gyroDriftThreshold) {
                        //                                //update drift, called only in WALKING state, else check it
                        //                                double edgeori;
                        //                                if (_currentState.startNode == _currentState.walkingEdge.node1)
                        //                                    edgeori = _currentState.walkingEdge.ori1;
                        //                                else
                        //                                    edgeori = _currentState.walkingEdge.ori2;
                        //
                        //                                _gyroDrift = (_gyroDrift + (_curOri - edgeori))/2;
                        //                                [NavLog logGyroDrift:_gyroDrift edge: edgeori curori: _curOri];
                        //                            }
                        //                        }
                        //                    }


                        //                        if (ABS(_curOri - _currentState.ori) > 15) {
                        float diff = clipAngle2(clipAngle2(_curOri - _gyroDrift) - clipAngle2(_currentState.ori));
                        if (ABS(diff) > 15) {
                            _currentState.previousInstruction = [self getTurnStringFromOri:clipAngle(_curOri-_gyroDrift) toOri:_currentState.ori];
                            [NavNotificationSpeaker speakWithCustomizedSpeed:_currentState.previousInstruction];
                            _navState = NAV_STATE_TURNING;
                        } else {
                            _navState = NAV_STATE_WALKING;
                        }
                    } else if (_currentState.type == STATE_TYPE_TRANSITION) {
                        _navState = NAV_STATE_WALKING;
                    }
                } else if (_currentState.type == STATE_TYPE_TRANSITION) {
                    _navState = NAV_STATE_WALKING;
                }
                [self logState];
            }
        }
    }
    [self setHintTexts];
}

- (void)setHintTexts {
    if (UIAccessibilityIsVoiceOverRunning()) {
        NSString *pre = [_currentState getPreviousInstruction], *surround = [_currentState getSurroundInfo], *access = [_currentState getAccessibilityInfo];
        if (![pre isEqualToString:_lastPre]) {
            [[NavCogFuncViewController sharedNavCogFuntionViewController] setHintText:_lastPre = pre withTag:BUTTON_PRE];
        }
        if (![surround isEqualToString:_lastSurround]) {
            [[NavCogFuncViewController sharedNavCogFuntionViewController] setHintText:_lastSurround = surround withTag:BUTTON_SURROUND];
        }
        if (![access isEqualToString:_lastAccess]) {
            [[NavCogFuncViewController sharedNavCogFuntionViewController] setHintText:_lastAccess = access withTag:BUTTON_ACCESS];
        }
    }
}

- (NSArray *)getPathNodes {
    return _pathNodes;
}

- (void)stopAudio {
    if (_currentState != nil) {
        [_currentState stopAudios];
    }
}

- (void)logState {
    NSMutableArray *data = [[NSMutableArray alloc] init];
    [data addObject:[NSNumber numberWithFloat:_curOri]];
    if(_currentState != nil) {
        [data addObject:[NSNumber numberWithFloat:_currentState.ori]];
        [data addObject:[NSNumber numberWithFloat:_currentState.sx]];
        [data addObject:[NSNumber numberWithFloat:_currentState.sy]];
        [data addObject:[NSNumber numberWithFloat:_currentState.tx]];
        [data addObject:[NSNumber numberWithFloat:_currentState.ty]];
        switch (_currentState.type) {
            case STATE_TYPE_WALKING:
                [data addObject:@"STATE_TYPE_WALKING"];
                break;
            case STATE_TYPE_TRANSITION:
                [data addObject:@"STATE_TYPE_TRANSITION"];
                break;
        }
    }
    NSString *type = @"Navigation";
    switch (_navState) {
        case NAV_STATE_WALKING:
            type = @"Walking";
            break;
        case NAV_STATE_TURNING:
            type = @"Turning";;
            break;
        case NAV_STATE_INIT:
            type = @"Starting";
            break;
        case NAV_STATE_IDLE:
            type = @"Idle";
        break;
    }
    [NavLog logArray:data withType:type];
}

@end
