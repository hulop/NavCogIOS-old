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
#import <CoreFoundation/CoreFoundation.h>

@implementation NavLocation

@end

@interface TopoMap ()

@property (strong, nonatomic) NSMutableDictionary *layers;
@property (strong, nonatomic) NSMutableDictionary *nodeNameNodeIDDict;
@property (strong, nonatomic) NSMutableDictionary *nodeNameLayerIDDict;
@property (strong, nonatomic) NSString *uuidString;
@property (strong, nonatomic) NSString *majoridString;

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
            node.infoFromEdges = [nodeJson objectForKey:@"infoFromEdges"];
            node.transitInfo = [nodeJson objectForKey:@"transitInfo"];
            node.transitKnnDistThres = ((NSNumber *)[nodeJson objectForKey:@"knnDistThres"]).floatValue;
            node.transitPosThres = ((NSNumber *)[nodeJson objectForKey:@"posDistThres"]).floatValue;
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
            if ([edge.edgeID isEqualToString:@"16"]) {
                NSLog(@"hello");
            }
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
- (NavLocation *)getCurrentLocationOnMapUsingBeacons:(NSArray *)beacons {
    NavLocation *location = [[NavLocation alloc] init];
    float minKnnDist = 1;
    
    for (NSString *layerID in _layers) {
        NavLayer *layer = [_layers objectForKey:layerID];
        for (NSString *edgeID in layer.edges) {
            NavEdge *edge = [layer.edges objectForKey:edgeID];
            [edge initLocalization];
            struct NavPoint pos = [edge getCurrentPositionInEdgeUsingBeacons:beacons];
            float dist = (pos.knndist - edge.minKnnDist) / (edge.maxKnnDist - edge.minKnnDist);
            dist = dist < 0 ? 0 : dist;
            dist = dist > 1 ? 1 : dist;
            if (dist < minKnnDist) {
                minKnnDist = dist;
                location.layerID = layerID;
                location.edgeID = edgeID;
            }
        }
    }
    return location;
}


@end
