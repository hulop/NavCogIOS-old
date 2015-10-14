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

#import "KDTreeLocalization.h"
#import <opencv2/opencv.hpp>
#import <unordered_map>
#import <CoreLocation/CoreLocation.h>
#import <algorithm>

#define KNN_NUM 5
#define TREE_NUM 5
#define SMOOTHING_WEIGHT 0.6
#define JUMPING_BOUND 3

using namespace std;

@interface KDTreeLocalization ()

@property (nonatomic) vector<float> preFeatVec;
@property (nonatomic) vector<float> featVec;
@property (nonatomic) vector<int> indices;
@property (nonatomic) vector<float> dists;
@property (nonatomic) cv::Mat featMap;
@property (nonatomic) cv::Mat posMap;
@property (nonatomic) cv::flann::Index kdTree;
@property (nonatomic) NavPoint currentLocation;
@property (nonatomic) unordered_map<int, int> beaconIndexMap;
@property (nonatomic) int sampleNum;
@property (nonatomic) int beaconNum;
@property (nonatomic) Boolean bStart;
@property (nonatomic) struct NavPoint prePoint;

@end

@implementation KDTreeLocalization

- (instancetype)init
{
    self = [super init];
    if (self) {
        for (int i = 0; i < _beaconNum; i++) {
            _featVec[i] = -100;
        }
        for (int i = 0; i < _beaconNum; i++) {
            _preFeatVec[i] = -100;
        }
        _bStart = false;
    }
    return self;
}

// when you restart navigation for another path
// you need to clean the history knowledge
- (void)initializaState {
    for (int i = 0; i < _beaconNum; i++) {
        _featVec[i] = -100;
    }
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = -100;
    }
    _bStart = false;
}

- (void)initializeWithFile:(NSString *)filename {
    _bStart = false;
    NSArray *split = [filename componentsSeparatedByString:@"."];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:(NSString *)split[0] ofType:(NSString *)split[1]];
    [self initializeWithAbsolutePath:filePath];
}

- (void)initializeWithAbsolutePath:(NSString *)filePath {
    _sampleNum = [self getDataNumOfFeatureFile:[filePath UTF8String]];
    
    FILE *fp = fopen([filePath UTF8String], "r");
    fscanf(fp, "MinorID of %d Beacon Used : ", &_beaconNum);
    for (int i = 0; i < _beaconNum; i++) {
        int beaconID;
        fscanf(fp, "%d,", &beaconID);
        _beaconIndexMap[beaconID] = i;
    }
    
    _indices.resize(KNN_NUM);
    _dists.resize(KNN_NUM);
    _featVec.resize(_beaconNum);
    _preFeatVec.resize(_beaconNum);
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = -100;
    }
    _featMap.create(_sampleNum, _beaconNum, CV_32F);
    _posMap.create(_sampleNum, 2, CV_32F);
    for (int i = 0; i < _sampleNum; i++) {
        float x, y;
        int validBeaconNum;
        fscanf(fp, "%f,%f,%d,", &x, &y, &validBeaconNum);
        _posMap.at<float>(i,0) = x;
        _posMap.at<float>(i,1) = y;
        for (int j = 0; j < _beaconNum; j++) {
            _featMap.at<float>(i, j) = -100.0;
        }
        for (int j = 0; j < validBeaconNum; j++) {
            int minorID, rssi, indx;
            fscanf(fp, "65535,%d,%d,", &minorID, &rssi);
            indx = _beaconIndexMap[minorID];
            _featMap.at<float>(i, indx) = rssi;
        }
    }
    
    _kdTree.build(_featMap, cv::flann::KDTreeIndexParams(TREE_NUM));
    fclose(fp);
}

- (void)initializeWithDataString:(NSString *)dataStr {
    _bStart = false;
    const char *p = [dataStr UTF8String];
    int nr = 0;
    _sampleNum = [self getDataNumOfDataString:p];
    sscanf(p, "MinorID of %d Beacon Used : %n", &_beaconNum, &nr);
    p += nr;
    for (int i = 0; i < _beaconNum; i++) {
        int beaconID;
        sscanf(p, "%d,%n", &beaconID, &nr);
        p += nr;
        _beaconIndexMap[beaconID] = i;
    }
    
    _indices.resize(KNN_NUM);
    _dists.resize(KNN_NUM);
    _featVec.resize(_beaconNum);
    _preFeatVec.resize(_beaconNum);
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = -100;
    }
    _featMap.create(_sampleNum, _beaconNum, CV_32F);
    _posMap.create(_sampleNum, 2, CV_32F);
    for (int i = 0; i < _sampleNum; i++) {
        float x, y;
        int validBeaconNum;
        sscanf(p, "%f,%f,%d,%n", &x, &y, &validBeaconNum, &nr);
        p += nr;
        _posMap.at<float>(i,0) = x;
        _posMap.at<float>(i,1) = y;
        for (int j = 0; j < _beaconNum; j++) {
            _featMap.at<float>(i, j) = -100.0;
        }
        for (int j = 0; j < validBeaconNum; j++) {
            int majorID, minorID, rssi, indx;
            sscanf(p, "%d,%d,%d,%n", &majorID, &minorID, &rssi, &nr);
            p += nr;
            indx = _beaconIndexMap[minorID];
            _featMap.at<float>(i, indx) = rssi;
        }
    }
    
    _kdTree.build(_featMap, cv::flann::KDTreeIndexParams(TREE_NUM));
}

- (struct NavPoint)localizeWithBeacons:(NSArray *)beacons {
    for (int i = 0; i < _beaconNum; i++) {
        _featVec[i] = -100;
    }
    for (CLBeacon *beacon in beacons) {
        if (_beaconIndexMap.find(beacon.minor.intValue) != _beaconIndexMap.end()) {
            _featVec[_beaconIndexMap[beacon.minor.intValue]] = (beacon.rssi == 0 ? -100 : beacon.rssi);
        }
    }
    
    for (int i = 0; i < _beaconNum; i++) {
        if (_preFeatVec[i] > -90) {
            _featVec[i] = (_featVec[i] < -99 ? _preFeatVec[i] : _featVec[i]);
        }
    }
    
    if (_bStart) {
        for (int i = 0; i < _beaconNum; i++) {
            _featVec[i] = _featVec[i] * SMOOTHING_WEIGHT + _preFeatVec[i] * (1 - SMOOTHING_WEIGHT);
        }
    }
    
    _kdTree.knnSearch(_featVec, _indices, _dists, KNN_NUM);
    struct NavPoint result;
    result.knndist = _dists[0];
    result.x = 0;
    result.y = 0;
    float distSum = 0;
    for (int i = 0; i < KNN_NUM; i++) {
        result.x += _posMap.at<float>(_indices[i], 0) / (_dists[i] + 1e-20);
        result.y += _posMap.at<float>(_indices[i], 1) / (_dists[i] + 1e-20);
        distSum += 1 / (_dists[i] + 1e-20);
    }
    result.x /= (distSum + 1e-20);
    result.y /= (distSum + 1e-20);
    
    for (int i = 0; i < _beaconNum; i++) {
        _preFeatVec[i] = _featVec[i];
    }
    
    if (_bStart) {
        if (result.x - _prePoint.x > JUMPING_BOUND) {
            result.x = _prePoint.x + JUMPING_BOUND;
        } else if (result.x - _prePoint.x < -JUMPING_BOUND) {
            result.x = _prePoint.x - JUMPING_BOUND;
        }
        
        if (result.y - _prePoint.y > JUMPING_BOUND) {
            result.y = _prePoint.y + JUMPING_BOUND;
        } else if (result.y - _prePoint.y < -JUMPING_BOUND) {
            result.y = _prePoint.y - JUMPING_BOUND;
        }
        
        result.x = result.x * SMOOTHING_WEIGHT + _prePoint.x * (1 - SMOOTHING_WEIGHT);
        result.y = result.y * SMOOTHING_WEIGHT + _prePoint.y * (1 - SMOOTHING_WEIGHT);
        
        _prePoint.x = result.x;
        _prePoint.y = result.y;
    } else {
        _prePoint.x = result.x;
        _prePoint.y = result.y;
    }
    
    _bStart = true;
    result.x *= 3;
    result.y *= 3;
    return result;
}

- (int)getDataNumOfFeatureFile:(const char *)path {
    FILE *fp = fopen(path, "r");
    char line[1024];
    int lineCnt = 0;
    while (fgets(line, 1024, fp) != NULL) {
        lineCnt++;
    }
    fclose(fp);
    return lineCnt - 1;
}

- (int)getDataNumOfDataString:(const char *)dataStr {
    int count = 0;
    const char* p = dataStr;
    while (*p != '\0') {
        p = strchr(p, '\n');
        p++;
        count++;
    }
    return count - 1;
}

- (int)shiftOverNextChar:(char)c count:(int)n inString:(const char*)str {
    int s = 0;
    for (int i = 0; i < n; i++) {
        while (str[s] != c) {
            s++;
        }
        s++;
    }
    return s;
}

@end
