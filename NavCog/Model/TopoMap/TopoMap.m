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

#import "NavMinHeap.h"
#import "TopoMap.h"
#import "NavLog.h"
#import "NavCogFuncViewController.h"
#import <CoreFoundation/CoreFoundation.h>

@implementation NavLocation

@end

@interface TopoMap ()

@property (strong, nonatomic) NSMutableDictionary *layers;
@property (strong, nonatomic) NSMutableDictionary *nodeNameNodeIDDict;
@property (strong, nonatomic) NSMutableDictionary *nodeNameLayerIDDict;
@property (strong, nonatomic) NSString *uuidString;
@property (strong, nonatomic) NSString *majoridString;
@property (strong, nonatomic) NavNode *tmpNode;
@property (strong, nonatomic) NavLayer *tmpNodeParentLayer;
@property (strong, nonatomic) NavEdge *tmpNodeParentEdge;

@end

@implementation TopoMap

- (NSString *)getUUIDString {
    return _uuidString;
}

- (NSString *)getMajorIDString {
    return _majoridString;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _layers = [[NSMutableDictionary alloc] init];
        _nodeNameNodeIDDict = [[NSMutableDictionary alloc] init];
        _nodeNameLayerIDDict = [[NSMutableDictionary alloc] init];
        _tmpNode = nil;
    }
    return self;
}

- (NSString *)initializaWithFile:(NSString *)filePath {
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:nil];
    NSDictionary *mapDataJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    NSDictionary *layersJson = (NSDictionary *)[mapDataJson objectForKey:@"layers"];
    _uuidString = [mapDataJson objectForKey:@"lastUUID"];
    _majoridString = [mapDataJson objectForKey:@"lastMajorID"];
    for (NSString *zIndex in [layersJson allKeys]) {
        NSDictionary *layerJson = [layersJson objectForKey:zIndex];
        NavLayer *layer = [[NavLayer alloc] init];
        layer.zIndex = [layerJson objectForKey:@"z"];
        
        // load node information
        NSDictionary *nodesJson = [layerJson objectForKey:@"nodes"];
        for (NSString *nodeID in [nodesJson allKeys]) {
            NSDictionary *nodeJson = [nodesJson objectForKey:nodeID];
            NavNode *node = [[NavNode alloc] init];
            node.nodeID = [nodeJson objectForKey:@"id"];
            node.name = [nodeJson objectForKey:@"name"];
            node.type = ((NSNumber *)[nodeJson objectForKey:@"type"]).intValue;
            node.buildingName = [nodeJson objectForKey:@"building"];
            node.floor = ((NSNumber *)[nodeJson objectForKey:@"floor"]).intValue;
            node.layerZIndex = zIndex;
            node.lat = ((NSNumber *)[nodeJson objectForKey:@"lat"]).floatValue;
            node.lng = ((NSNumber *)[nodeJson objectForKey:@"lng"]).floatValue;
            [node.infoFromEdges addEntriesFromDictionary:[nodeJson objectForKey:@"infoFromEdges"]];
            node.transitInfo = [nodeJson objectForKey:@"transitInfo"];
            node.transitKnnDistThres = ((NSNumber *)[nodeJson objectForKey:@"knnDistThres"]).floatValue;
            node.transitPosThres = ((NSNumber *)[nodeJson objectForKey:@"posDistThres"]).floatValue;
            node.transitKnnDistThres = MAX(1.0, node.transitKnnDistThres);
            node.transitPosThres = MAX(10, node.transitPosThres);
            node.parentLayer = layer;
            [_nodeNameNodeIDDict setObject:node.nodeID forKey:node.name];
            [_nodeNameLayerIDDict setObject:zIndex forKey:node.name];
            [layer.nodes setObject:node forKey:node.nodeID];
        }
        
        // load edge information
        NSDictionary *edgesJson = [layerJson objectForKey:@"edges"];
        for (NSString *edgeID in [edgesJson allKeys]) {
            NSDictionary *edgeJson = [edgesJson objectForKey:edgeID];
            NavEdge *edge = [[NavEdge alloc] init];
            edge.edgeID = [edgeJson objectForKey:@"id"];
            edge.type = ((NSNumber *)[edgeJson objectForKey:@"type"]).intValue;
            edge.len = ((NSNumber *)[edgeJson objectForKey:@"len"]).intValue;
            edge.ori1 = ((NSNumber *)[edgeJson objectForKey:@"oriFromNode1"]).floatValue;
            edge.ori2 = ((NSNumber *)[edgeJson objectForKey:@"oriFromNode2"]).floatValue;
            edge.minKnnDist = ((NSNumber *)[edgeJson objectForKey:@"minKnnDist"]).floatValue;
            edge.maxKnnDist = ((NSNumber *)[edgeJson objectForKey:@"maxKnnDist"]).floatValue;
            edge.nodeID1 = [edgeJson objectForKey:@"node1"];
            edge.node1 = [layer.nodes objectForKey:edge.nodeID1];
            edge.nodeID2 = [edgeJson objectForKey:@"node2"];
            edge.node2 = [layer.nodes objectForKey:edge.nodeID2];
            [edge setLocalizationWithDataString:[edgeJson objectForKey:@"dataFile"]];
            edge.info1 = [edgeJson objectForKey:@"infoFromNode1"];
            edge.info2 = [edgeJson objectForKey:@"infoFromNode2"];
            edge.parentLayer = layer;
            [layer.edges setObject:edge forKey:edge.edgeID];
        }
        
        // get neighbor information from all nodes and edges
        for (NSString *nodeID in layer.nodes) {
            NavNode *node = [layer.nodes objectForKey:nodeID];
            for (NSString *edgeID in node.infoFromEdges) {
                NavEdge *edge = [layer.edges objectForKey:edgeID];
                NavNeighbor *neighbor = [[NavNeighbor alloc] init];
                neighbor.edge = edge;
                if (node != edge.node1) {
                    neighbor.node = edge.node1;
                } else {
                    neighbor.node = edge.node2;
                }
                [node.neighbors addObject:neighbor];
            }
        }
        
        [_layers setObject:layer forKey:layer.zIndex];
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSArray *)findShortestPathFromCurrentLocation:(NavLocation *)curLocation toNodeWithName:(NSString *)toNodeName{
    NavEdge *curEdge = [self getEdgeFromLayer:curLocation.layerID withEdgeID:curLocation.edgeID];
    NavLayer *curLayer = [_layers objectForKey:curLocation.layerID];
    
    // if your current location reach one of the ends of current edge
    // then just do the same, not touching the topo map
    if ([curEdge checkValidEndNodeAtLocation:curLocation] != nil) {
        NavNode *node = [curEdge checkValidEndNodeAtLocation:curLocation];
        return [self findShortestPathFromNode:node toNodeWithName:toNodeName];
    } else {
        // use a tmp node to split the edge into two
        NavNode *tmpNode = [[NavNode alloc] init];
        _tmpNode = tmpNode;
        _tmpNodeParentLayer = curLayer;
        _tmpNodeParentEdge = curEdge;
        tmpNode.nodeID = @"tmp_node";
        tmpNode.type = NODE_TYPE_NORMAL;
        tmpNode.layerZIndex = curLocation.layerID;
        tmpNode.buildingName = curEdge.node1.buildingName;
        tmpNode.floor = curEdge.node1.floor;
        
        float slat = curEdge.node1.lat;
        float slng = curEdge.node1.lng;
        float tlat = curEdge.node2.lat;
        float tlng = curEdge.node2.lng;
        float sy = [curEdge.node1 getYInEdgeWithID:curEdge.edgeID];
        float ty = [curEdge.node2 getYInEdgeWithID:curEdge.edgeID];
        float ratio = (curLocation.yInEdge - sy) / (ty - sy);
        ratio = ratio < 0 ? 0 : ratio;
        ratio = ratio > 1 ? 1 : ratio;
        tmpNode.lat = slat + ratio * (tlat - slat);
        tmpNode.lng = slng + ratio * (tlng - slng);
        tmpNode.parentLayer = curLayer;
        
        // the dynamic topo map looks lik this
        //          tmp edge 1              tmp edge 2
        // (node1)--------------(tmp node)--------------(node2)
        //      \_________________________________________/
        //                   current edge
        // new two edges
        NavEdge *tmpEdge1 = [curEdge clone];
        tmpEdge1.edgeID = @"tmp_edge_1";
        tmpEdge1.node2 = tmpNode;
        tmpEdge1.nodeID2 = tmpNode.nodeID;
        tmpEdge1.len = curLocation.yInEdge - sy;
        NavEdge *tmpEdge2 = [curEdge clone];
        tmpEdge2.edgeID = @"tmp_edge_2";
        tmpEdge2.node1 = tmpNode;
        tmpEdge2.nodeID1 = tmpNode.nodeID;
        tmpEdge2.len = ty - curLocation.yInEdge;
        
        // add info from edges to tmp node
        NSDictionary *infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge1.edgeID andXInEdge:curLocation.xInEdge andYInEdge:curLocation.yInEdge];
        [tmpNode.infoFromEdges setObject:infoDict forKey:tmpEdge1.edgeID];
        infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge2.edgeID andXInEdge:curLocation.xInEdge andYInEdge:curLocation.yInEdge];
        [tmpNode.infoFromEdges setObject:infoDict forKey:tmpEdge2.edgeID];
        
        // add neighbor information
        NavNeighbor *nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge1;
        nb.node = curEdge.node1;
        [tmpNode.neighbors addObject:nb];
        nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge2;
        nb.node = curEdge.node2;
        [tmpNode.neighbors addObject:nb];
        
        // add neighbor information to node1 and node2 of curEdge
        nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge1;
        nb.node = tmpNode;
        [curEdge.node1.neighbors addObject:nb];
        nb = [[NavNeighbor alloc] init];
        nb.edge = tmpEdge2;
        nb.node = tmpNode;
        
        // add info from tmp edges for node1 and node2
        infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge1.edgeID andXInEdge:[curEdge.node1 getXInEdgeWithID:curEdge.edgeID] andYInEdge:[curEdge.node1 getYInEdgeWithID:curEdge.edgeID]];
        [curEdge.node1.infoFromEdges setObject:infoDict forKey:tmpEdge1.edgeID];
        infoDict = [self getNodeInfoDictFromEdgeWithID:tmpEdge2.edgeID andXInEdge:[curEdge.node2 getXInEdgeWithID:curEdge.edgeID] andYInEdge:[curEdge.node2 getYInEdgeWithID:curEdge.edgeID]];
        [curEdge.node2.infoFromEdges setObject:infoDict forKey:tmpEdge2.edgeID];
        
        [curLayer.nodes setObject:tmpNode forKey:tmpNode.nodeID];
        [curLayer.edges setObject:tmpEdge1 forKey:tmpEdge1.edgeID];
        [curLayer.edges setObject:tmpEdge2 forKey:tmpEdge2.edgeID];
        return [self findShortestPathFromNode:tmpNode toNodeWithName:toNodeName];
    }
}

- (void)cleanTmpNodeAndEdges {
    [NavLog stopLog];
    [_tmpNodeParentLayer.nodes removeObjectForKey:@"tmp_node"];
    [_tmpNodeParentLayer.edges removeObjectForKey:@"tmp_edge_1"];
    [_tmpNodeParentLayer.edges removeObjectForKey:@"tmp_edge_2"];
    [_tmpNodeParentEdge.node1.infoFromEdges removeObjectForKey:@"tmp_edge_1"];
    [_tmpNodeParentEdge.node2.infoFromEdges removeObjectForKey:@"tmp_edge_2"];
    for (NavNeighbor *nb in _tmpNodeParentEdge.node1.neighbors) {
        if ([nb.node.nodeID isEqualToString:@"tmp_node"]) {
            [_tmpNodeParentEdge.node1.neighbors removeLastObject];
        }
    }
    for (NavNeighbor *nb in _tmpNodeParentEdge.node2.neighbors) {
        if ([nb.node.nodeID isEqualToString:@"tmp_node"]) {
            [_tmpNodeParentEdge.node2.neighbors removeLastObject];
        }
    }
}

- (NSDictionary *)getNodeInfoDictFromEdgeWithID:(NSString *)edgeID andXInEdge:(float)x andYInEdge:(float)y {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:edgeID forKey:@"edgeID"];
    [dict setObject:[NSNumber numberWithFloat:x] forKey:@"x"];
    [dict setObject:[NSNumber numberWithFloat:y] forKey:@"y"];
    return dict;
}

// return all POI node names
- (NSArray *)getAllLocationNamesOnMap {
    NSMutableArray *allNames = [[NSMutableArray alloc] init];
    for (NavLayer *layer in [_layers allValues]) {
        for (NavNode *node in [layer.nodes allValues]) {
            if (node.type == NODE_TYPE_DESTINATION) {
                [allNames addObject:node.name];
            }
        }
    }
    return allNames;
}

// search a shortest path
- (NSArray *)findShortestPathFromNode:(NavNode *)startNode toNodeWithName:(NSString *)toName {
    // get start node and end node of the path
    NavNode *endNode = [self getNodeWithID:[_nodeNameNodeIDDict objectForKey:toName] fromLayerWithID:[_nodeNameLayerIDDict objectForKey:toName]];
    if (startNode == nil || endNode == nil) {
        return nil;
    }
    
    // visited nodes and nodes have been reachable from start node
    NSMutableSet *visitedNodes = [[NSMutableSet alloc] init];
    NSMutableSet *reachableNodes = [[NSMutableSet alloc] init];
    
    // initialize the Min-Heap, maximum size is number of nodes
    NavMinHeap *heap = [[NavMinHeap alloc] init];
    [heap initHeapWithSize:(int)[[_nodeNameNodeIDDict allKeys] count]];
    
    // initial the search from start node, start the search from start node's neighbors
    startNode.distFromStartNode = 0;
    startNode.preNodeInPath = nil;
    [reachableNodes addObject:startNode];
    [heap offer:startNode];
    
    // search for end node, O((N+E)*log(N)), N is total number of nodes, E is total number of edges
    while ([heap getSize] > 0) {
        NavNode *node = [heap poll];
        [visitedNodes addObject:node];
        [reachableNodes removeObject:node];
        for (NavNeighbor *neighbor in node.neighbors) {
            NavNode *nbNode = neighbor.node;
            if ([visitedNodes containsObject:nbNode]) {
                continue;
            }
            if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                int newDist = node.distFromStartNode + neighbor.edge.len;
                if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                    nbNode.preNodeInPath = node;
                    nbNode.preEdgeInPath = neighbor.edge;
                    [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                }
            } else {
                nbNode.distFromStartNode = node.distFromStartNode + neighbor.edge.len;
                nbNode.preNodeInPath = node;
                nbNode.preEdgeInPath = neighbor.edge;
                if ([nbNode.name isEqualToString:endNode.name]) {
                    return [self traceBackForPathFromNode:nbNode];
                }
                [heap offer:nbNode];
                [reachableNodes addObject:nbNode];
            }
        }
        
        for (NSString *layerID in node.transitInfo) {
            NSDictionary *transitJson = [node.transitInfo objectForKey:layerID];
            Boolean transitEnabled = ((NSNumber *)[transitJson objectForKey:@"enabled"]).boolValue;
            if (transitEnabled) {
                NavNode *nbNode = [self getNodeWithID:[transitJson objectForKey:@"node"] fromLayerWithID:layerID];
                if (![visitedNodes containsObject:nbNode]) {
                    if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                        int newDist = node.distFromStartNode;
                        if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                            nbNode.preNodeInPath = node;
                            nbNode.preEdgeInPath = nil;
                            [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                        }
                    } else {
                        nbNode.distFromStartNode = node.distFromStartNode;
                        nbNode.preNodeInPath = node;
                        nbNode.preEdgeInPath = nil;
                        if ([nbNode.name isEqualToString:endNode.name]) {
                            return [self traceBackForPathFromNode:nbNode];
                        }
                        [heap offer:nbNode];
                        [reachableNodes addObject:nbNode];
                    }
                }
            }
        }
    }
    
    return nil;
}

// search a shortest path
- (NSArray *)findShortestPathFromNodeWithName:(NSString *)fromName toNodeWithName:(NSString *)toName {
    // get start node and end node of the path
    NavNode *startNode = [self getNodeWithID:[_nodeNameNodeIDDict objectForKey:fromName] fromLayerWithID:[_nodeNameLayerIDDict objectForKey:fromName]];
    NavNode *endNode = [self getNodeWithID:[_nodeNameNodeIDDict objectForKey:toName] fromLayerWithID:[_nodeNameLayerIDDict objectForKey:toName]];
    if (startNode == nil || endNode == nil) {
        return nil;
    }
    
    // visited nodes and nodes have been reachable from start node
    NSMutableSet *visitedNodes = [[NSMutableSet alloc] init];
    NSMutableSet *reachableNodes = [[NSMutableSet alloc] init];
    
    // initialize the Min-Heap, maximum size is number of nodes
    NavMinHeap *heap = [[NavMinHeap alloc] init];
    [heap initHeapWithSize:(int)[[_nodeNameNodeIDDict allKeys] count]];
    
    // initial the search from start node, start the search from start node's neighbors
    startNode.distFromStartNode = 0;
    startNode.preNodeInPath = nil;
    [reachableNodes addObject:startNode];
    [heap offer:startNode];
    
    // search for end node, O((N+E)*log(N)), N is total number of nodes, E is total number of edges
    while ([heap getSize] > 0) {
        NavNode *node = [heap poll];
        [visitedNodes addObject:node];
        [reachableNodes removeObject:node];
        for (NavNeighbor *neighbor in node.neighbors) {
            NavNode *nbNode = neighbor.node;
            if ([visitedNodes containsObject:nbNode]) {
                continue;
            }
            if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                int newDist = node.distFromStartNode + neighbor.edge.len;
                if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                    nbNode.preNodeInPath = node;
                    nbNode.preEdgeInPath = neighbor.edge;
                    [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                }
            } else {
                nbNode.distFromStartNode = node.distFromStartNode + neighbor.edge.len;
                nbNode.preNodeInPath = node;
                nbNode.preEdgeInPath = neighbor.edge;
                if ([nbNode.name isEqualToString:endNode.name]) {
                    return [self traceBackForPathFromNode:nbNode];
                }
                [heap offer:nbNode];
                [reachableNodes addObject:nbNode];
            }
        }
        
        for (NSString *layerID in node.transitInfo) {
            NSDictionary *transitJson = [node.transitInfo objectForKey:layerID];
            Boolean transitEnabled = ((NSNumber *)[transitJson objectForKey:@"enabled"]).boolValue;
            if (transitEnabled) {
                NavNode *nbNode = [self getNodeWithID:[transitJson objectForKey:@"node"] fromLayerWithID:layerID];
                if (![visitedNodes containsObject:nbNode]) {
                    if ([reachableNodes containsObject:nbNode]) { // if the node has been reached
                        int newDist = node.distFromStartNode;
                        if (newDist < nbNode.distFromStartNode) { // sift up the node if its distance is less than before
                            nbNode.preNodeInPath = node;
                            nbNode.preEdgeInPath = nil;
                            [heap siftAndUpdateNode:nbNode withNewDist:newDist]; // nbNode.distFromStartNode will be updated to newDist
                        }
                    } else {
                        nbNode.distFromStartNode = node.distFromStartNode;
                        nbNode.preNodeInPath = node;
                        nbNode.preEdgeInPath = nil;
                        if ([nbNode.name isEqualToString:endNode.name]) {
                            return [self traceBackForPathFromNode:nbNode];
                        }
                        [heap offer:nbNode];
                        [reachableNodes addObject:nbNode];
                    }
                }
            }
        }
    }
    
    return nil;
}

- (NSArray *)traceBackForPathFromNode:(NavNode *)node {
    NSMutableArray *pathNodes = [[NSMutableArray alloc] init];
    [pathNodes addObject:node];
    NavNode *preNode = node.preNodeInPath;
    while (preNode != nil) {
        [pathNodes addObject:preNode];
        preNode = preNode.preNodeInPath;
    }
    return pathNodes;
}

- (NavNode *)getNodeWithID:(NSString *)nodeID fromLayerWithID:(NSString *)layerID {
    if ([_layers objectForKey:layerID] == nil) {
        return nil;
    }
    NavLayer *layer = [_layers objectForKey:layerID];
    
    if ([layer.nodes objectForKey:nodeID] == nil) {
        return nil;
    }
    
    return [layer.nodes objectForKey:nodeID];
}

// get current location on the map
// check which layer and which edge you're in
// find a edge in which we get a minimum normalized KNN Distance
- (NavLocation *)getCurrentLocationOnMapUsingBeacons:(NSArray *)beacons withInit:(Boolean)init {
    NSMutableArray *edges = [[NSMutableArray alloc] init];
    for (NSString *layerID in _layers) {
        NavLayer *layer = [_layers objectForKey:layerID];
        for (NSString *edgeID in layer.edges) {
            [edges addObject:[layer.edges objectForKey:edgeID]];
        }
    }
    NavLocation *location = [self getLocationInEdges:edges withBeacons:beacons withKNNThreshold:1.0 withInit:init];

    if ([NavLog isLogging] == YES) {
        if (location.edgeID == nil) {
            [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:@"updateRedDot(null)"];
        } else {
            NavEdge *edge = [self getEdgeFromLayer:location.layerID withEdgeID:location.edgeID];
            NavNode *node1 = edge.node1, *node2 = edge.node2;
            NSDictionary* info1 = [node1.infoFromEdges objectForKey:edge.edgeID];
            NSDictionary* info2 = [node2.infoFromEdges objectForKey:edge.edgeID];
            float cy = location.yInEdge;
            float slat = node1.lat;
            float slng = node1.lng;
            float tlat = node2.lat;
            float tlng = node2.lng;
            float sy = ((NSNumber *)[info1 objectForKey:@"y"]).floatValue;
            float ty = ((NSNumber *)[info2 objectForKey:@"y"]).floatValue;
            float ratio = (cy - sy) / (ty - sy);
            float lat = slat + ratio * (tlat - slat);
            float lng = slng + ratio * (tlng - slng);
            NSString *cmd = [NSString stringWithFormat:@"updateRedDot({lat:%f, lng:%f})", lat, lng];
            [[NavCogFuncViewController sharedNavCogFuntionViewController] runCmdWithString:cmd];
        }
    }
    return location;
}

- (NavLocation *)getLocationInEdges:(NSArray *)edges withBeacons:(NSArray *)beacons withKNNThreshold:(float)minKnnDist withInit:(Boolean)init {
    NavLocation *location = [[NavLocation alloc] init];
    float lastKnnDist = 0;
    for (NavEdge *edge in edges) {
        if (init) {
            [edge initLocalization];
        }
        struct NavPoint pos = [edge getCurrentPositionInEdgeUsingBeacons:beacons];
        float dist = (pos.knndist - edge.minKnnDist) / (edge.maxKnnDist - edge.minKnnDist);
        // Log search information for edge
        NSMutableArray *data = [[NSMutableArray alloc] init];
        [data addObject:[NSNumber numberWithFloat:dist]];
        [data addObject:edge.parentLayer.zIndex];
        [data addObject:edge.edgeID];
        [data addObject:[NSNumber numberWithFloat:pos.x]];
        [data addObject:[NSNumber numberWithFloat:pos.y]];
        [data addObject:[NSNumber numberWithFloat:pos.knndist]];
        [NavLog logArray:data withType:@"SearchingCurrentLocation"];
        // if distance is less than threshold, set new location
        if (dist < minKnnDist) {
            minKnnDist = dist;
            lastKnnDist = pos.knndist;
            location.layerID = edge.parentLayer.zIndex;
            location.edgeID = edge.edgeID;
            location.xInEdge = pos.x;
            location.yInEdge = pos.y;
            [data addObject:@"OK"];
        }
    } // end for
    // Log info if location found
    if (location.edgeID == NULL) {
        location.edgeID = nil;
        NSLog(@"NoCurrentLocation");
    } else {
        NSMutableArray *data = [[NSMutableArray alloc] init];
        [data addObject:[NSNumber numberWithFloat:minKnnDist]];
        [data addObject:location.layerID];
        [data addObject:location.edgeID];
        [data addObject:[NSNumber numberWithFloat:location.xInEdge]];
        [data addObject:[NSNumber numberWithFloat:location.yInEdge]];
        [data addObject:[NSNumber numberWithFloat:lastKnnDist]];
        [NavLog logArray:data withType:@"FoundCurrentLocation"];
    }
    return location;
}

- (NavNode *)getNodeFromLayer:(NSString *)layerID withNodeID:(NSString *)nodeID {
    NavLayer *layer = [_layers objectForKey:layerID];
    return [layer.nodes objectForKey:nodeID];
}

- (NavEdge *)getEdgeFromLayer:(NSString *)layerID withEdgeID:(NSString *)edgeID {
    NavLayer *layer = [_layers objectForKey:layerID];
    return [layer.edges objectForKey:edgeID];
}

@end
