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
    return NO;
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
    
    NSMutableArray *domainList = [[NSMutableArray alloc] init];
    [domainList addObject:dormain];
    _netDiagnoService = [[LDNetDiagnoService alloc] initWithAppName:appName appVersion:appVersion userId:userID domainList:domainList didEndBlock:^(NSString * _Nonnull allLogInfo) {
        
    }];
    _netDiagnoService.delegate = self;
    if (!_isRunning) {
        _logInfo = @"";
        _isRunning = !_isRunning;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [_netDiagnoService startNetDiagnosis];
        });
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bridge enqueueJSCall:@"RCTDeviceEventEmitter"
                            method:@"emit"
                              args:@[DIAGNOSIS_EVENT, ret]
                        completion:NULL];
    });
}

- (void)netDiagnosisDidStarted {
    // 诊断开始
    _isRunning = YES;
    NSDictionary *ret = @{@"code": @1, @"message":@"诊断开始", @"data":@""};
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bridge enqueueJSCall:@"RCTDeviceEventEmitter"
                            method:@"emit"
                              args:@[DIAGNOSIS_EVENT, ret]
                        completion:NULL];
    });
}

- (void)netDiagnosisStepInfo:(NSString *)stepInfo {
    // 诊断中
    _logInfo = [_logInfo stringByAppendingString: stepInfo];
    
    NSDictionary *ret = @{@"code": @2, @"message":@"诊断中", @"data":_logInfo};
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bridge enqueueJSCall:@"RCTDeviceEventEmitter"
                            method:@"emit"
                              args:@[DIAGNOSIS_EVENT, ret]
                        completion:NULL];
    });
}

@end
