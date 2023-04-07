#import "Mtr.h"

//监听
#define DIAGNOSIS_EVENT                 @"DiagnosisEvent"

@implementation Mtr

LDNetDiagnoService *_netDiagnoService = nil;
BOOL _isRunning;
NSString *_logInfo;

- (NSArray<NSString *> *)supportedEvents
{
    return @[DIAGNOSIS_EVENT];
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

+ (BOOL) requiresMainQueueSetup {
    return YES;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(startNetDiagnosis:(NSDictionary *)param resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    NSString *theAppCode = @"";
    NSString *appName = @"";
    NSString *appVersion = @"";
    NSString *userID = @"";
    NSString *dormain = @"";
    
    if ((NSString *)param[@"theAppCode"] != nil) {
        theAppCode = (NSString *)param[@"theAppCode"];
    }
    if ((NSString *)param[@"appName"] != nil) {
        appName = (NSString *)param[@"appName"];
    }
    if ((NSString *)param[@"appVersion"] != nil) {
        appVersion = (NSString *)param[@"appVersion"];
    }
    if ((NSString *)param[@"userID"] != nil) {
        userID = (NSString *)param[@"userID"];
    }
    if ((NSString *)param[@"dormain"] != nil) {
        dormain = (NSString *)param[@"dormain"];
    }
    
    if (_netDiagnoService == nil) {
        _netDiagnoService = [[LDNetDiagnoService alloc] initWithAppCode:theAppCode
                                                                appName:appName
                                                             appVersion:appVersion
                                                                 userID:userID
                                                               deviceID:nil
                                                                dormain:@""
                                                            carrierName:nil
                                                         ISOCountryCode:nil
                                                      MobileCountryCode:nil
                                                          MobileNetCode:nil];
        _netDiagnoService.delegate = self;
    }
    _netDiagnoService.dormain = dormain;
    if (!_isRunning) {
        _logInfo = @"";
        _isRunning = !_isRunning;
        [_netDiagnoService startNetDiagnosis];
        
        NSDictionary *ret = @{@"code": @1, @"message":@"开始诊断"};
        resolve(ret);
        
    } else {
        NSDictionary *ret = @{@"code": @-1, @"message":@"诊断中"};
        resolve(ret);
    }
}

RCT_EXPORT_METHOD(stopNetDiagnosis:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [_netDiagnoService stopNetDialogsis];
    _isRunning = NO;
    NSDictionary *ret = @{@"code": @1, @"message":@"结束诊断"};
    resolve(ret);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(isRunningSync) {
    if (_isRunning == YES) {
        return @YES;
    } else {
        return @NO;
    }
}

#pragma mark - LDNetDiagnoService
- (void)netDiagnosisDidEnd:(NSString *)allLogInfo {
    // 诊断结束
    _isRunning = NO;
    NSDictionary *ret = @{@"code": @0, @"message":@"结束诊断", @"data": allLogInfo};
    [self.bridge enqueueJSCall:@"RCTDeviceEventEmitter"
                        method:@"emit"
                          args:@[DIAGNOSIS_EVENT, ret]
                    completion:NULL];
}

- (void)netDiagnosisDidStarted {
    // 诊断开始
    _isRunning = YES;
    NSDictionary *ret = @{@"code": @1, @"message":@"诊断开始", @"data":@""};
    [self.bridge enqueueJSCall:@"RCTDeviceEventEmitter"
                        method:@"emit"
                          args:@[DIAGNOSIS_EVENT, ret]
                    completion:NULL];
}

- (void)netDiagnosisStepInfo:(NSString *)stepInfo {
    // 诊断中
    _logInfo = [_logInfo stringByAppendingString: stepInfo];
    
    NSDictionary *ret = @{@"code": @2, @"message":@"诊断中", @"data":_logInfo};
    [self.bridge enqueueJSCall:@"RCTDeviceEventEmitter"
                        method:@"emit"
                          args:@[DIAGNOSIS_EVENT, ret]
                    completion:NULL];
    
}

@end
