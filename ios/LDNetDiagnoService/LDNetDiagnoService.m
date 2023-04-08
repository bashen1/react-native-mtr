//
//  LDNetDiagnoService.m
//  LDNetDiagnoServieDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "LDNetDiagnoService.h"
#import "LDNetPing.h"
#import "LDNetTraceRoute.h"
#import "LDNetGetAddress.h"
#import "LDNetTimer.h"
#import "LDNetConnect.h"
#import <react-native-netinfo/RNCConnectionStateWatcher.h>
#import <libkern/OSAtomic.h>
static NSString *const kPingOpenServerIP = @"";
static NSString *const kCheckOutIPURL = @"";

@interface LDNetDiagnoService () <LDNetPingDelegate, LDNetTraceRouteDelegate,
                                  LDNetConnectDelegate, RNCConnectionStateWatcherDelegate> {
    NSString *_appCode;  //客户端标记
    NSString *_appName;
    NSString *_appVersion;
    NSString *_UID;       //用户ID
    NSString *_deviceID;  //客户端机器ID，如果不传入会默认取API提供的机器ID
    NSString *_carrierName;
    NSString *_ISOCountryCode;
    NSString *_MobileCountryCode;
    NSString *_MobileNetCode;

    NETWORK_TYPE _curNetType;
    NSString *_localIp;
    NSString *_gatewayIp;
    NSArray *_dnsServers;
    NSArray *_hostAddress;

    NSMutableString *_logInfo;  //记录网络诊断log日志
//    BOOL _isRunning;
    BOOL _connectSuccess;  //记录连接是否成功
    LDNetPing *_netPinger;
    LDNetTraceRoute *_traceRouter;
    LDNetConnect *_netConnect;
    
    volatile uint32_t _IsRunning;
}



/**
 完成检测任务的域名计数器
 */
@property (nonatomic, assign) NSInteger finishDomainCount;
@property (nonatomic, copy) LDNetDiagnoServiceDidEndBlock didEndBlock;
@property (nonatomic, strong) RNCConnectionStateWatcher *connectionStateWatcher;
@end

@implementation LDNetDiagnoService
#pragma mark - public method
/**
 初始化网络诊断服务
 */
- (instancetype)initWithAppName:(NSString *)appName appVersion:(NSString *)appVersion userId:(NSString *)userId domainList:(NSMutableArray<NSString *> *)domainList didEndBlock:(nonnull LDNetDiagnoServiceDidEndBlock)didEndBlock
{
    if (self = [super init]) {
        _appName = appName;
        _appVersion = appVersion;
        _UID = userId;
        _domainList = domainList;
        
        _logInfo = [[NSMutableString alloc] initWithCapacity:512 * domainList.count];
//        _isRunning = NO;
        
        _finishDomainCount = 0;
        
        // 初始化网络状态监测
        _connectionStateWatcher = [[RNCConnectionStateWatcher alloc] initWithDelegate:self];
        
        // 在初始化方法中加入 _traceRouter 的初始化以实现一个 _traceRouter 对应多个 domain 的场景
        _traceRouter = [[LDNetTraceRoute alloc] initWithMaxTTL:TRACEROUTE_MAX_TTL
                                                       timeout:TRACEROUTE_TIMEOUT
                                                   maxAttempts:TRACEROUTE_ATTEMPTS
                                                          port:TRACEROUTE_PORT];
        _traceRouter.delegate = self;
        
        // 在初始化方法中加入 _netPinger 的初始化以实现一个 _traceRouter 对应多个 domain 的场景
        _netPinger = [[LDNetPing alloc] init];
        _netPinger.delegate = self;
        
        _didEndBlock = didEndBlock;
    }
    return self;
}

- (void)dealloc
{
  self.connectionStateWatcher = nil;
}

/**
 开始网络测试
 */
- (void)startNetDiagnosis
{
    // 如果域名列表为空，直接返回
    if (!self.domainList || self.domainList.count == 0) return;
    
    // 设置 _isRunning 标志位为 YES
//    _isRunning = YES;
    [self setIsRunning:YES];
    
    // 设置 logInfo
    [_logInfo setString:@""];
    
    // 通知代理开始诊断
    [self recordStepInfo:@"Diagnosis Start..."];
    
    // 记录 App 当前版本信息
    [self recordCurrentAppVersion];
    
    // 记录本地网络环境
    [self recordLocalNetEnvironment];
    
    // 遍历 domainList 中所有的域名，进行检测
    __weak typeof(self) weakSelf = self;
    [self.domainList enumerateObjectsUsingBlock:^(NSString * _Nonnull domain, NSUInteger idx, BOOL * _Nonnull stop) {
        __strong typeof(self) strongSelf = weakSelf;
        if (domain.length > 0) {
            [strongSelf doNetDiagnosis:domain];
        }
    }];
}


/// 对单个域名进行网络测试
/// @param domain 域名
- (void)doNetDiagnosis:(NSString *)domain
{
    // 未联网不进行任何检测
    if (_curNetType == 0) {
        [self recordStepInfo:@"\nThe current host is not connected to the Internet, please check the network！"];
        return;
    }
    
    // Ping
    if (_netPinger) {
        [self pingDialogsisWithHost:domain];
    }
    
    // traceroute
    [self recordStepInfo:@"\nStart Traceroute..."];
    if (_traceRouter) {
//        [NSThread detachNewThreadSelector:@selector(doTraceRoute:)
//                                         toTarget:_traceRouter
//                                       withObject:domain];
        
        // 已经是子线程，没必要再创建子线程
        // 而且会导致 self.hostAddress 在不同的线程设置为nil，导致LDSimplePing.sendPingWithData中assert self.hostAddress报错
        [_traceRouter doTraceRoute:domain];
    }
}


/**
 * 停止诊断网络, 清空诊断状态
 */
- (void)stopNetDialogsis
{
    if ([self isRunning]) {
        if (_netConnect != nil) {
            [_netConnect stopConnect];
            _netConnect = nil;
        }

        if (_netPinger != nil) {
            [_netPinger stopPing];
            _netPinger = nil;
        }

        if (_traceRouter != nil) {
            [_traceRouter setIsRunning:NO];
            // 下面这行代码会导致正在执行中的 traceRouter 对象被释放掉，进而在内部的 while 循环中访问 self.delegate 时，由于 self 已经是野指针了，所以会直接 crash 掉
            // 在业务方调用 stopNetDialogsis 后会将当前对象置为 nil
//            _traceRouter = nil;
        }

        [self setIsRunning:NO];
        self.finishDomainCount = 0;
    }
}

/**
 停止诊断网络并返回所有的 log
 */
- (NSString *)stopNetDialogsisAndReturnTotalLog
{
    [self stopNetDialogsis];
    return _logInfo;
}


/**
 * 打印整体loginInfo；
 */
- (void)printLogInfo
{
    NSLog(@"\n%@\n", _logInfo);
}


#pragma mark -
#pragma mark - private method
/// 记录 App 当前版本信息
- (void)recordCurrentAppVersion
{
    NSDictionary *dicBundle = [[NSBundle mainBundle] infoDictionary];
    
    if (!_appName || [_appName isEqualToString:@""]) {
        _appName = [dicBundle objectForKey:@"CFBundleDisplayName"];
    }
    
    [self recordStepInfo:[NSString stringWithFormat:@"App Name: %@", _appName]];
    
    if (!_appVersion || [_appVersion isEqualToString:@""]) {
        _appVersion = [dicBundle objectForKey:@"CFBundleShortVersionString"];
    }
    [self recordStepInfo:[NSString stringWithFormat:@"App Version: %@", _appVersion]];
    [self recordStepInfo:[NSString stringWithFormat:@"User Id: %@", _UID]];
    
    //输出机器信息
    UIDevice *device = [UIDevice currentDevice];
    [self recordStepInfo:[NSString stringWithFormat:@"Device Type: %@", [device systemName]]];
    [self recordStepInfo:[NSString stringWithFormat:@"Device System Version: %@", [device systemVersion]]];
}

/*!
 *  @brief  获取本地网络环境信息
 */
- (void)recordLocalNetEnvironment
{
    //判断是否联网以及获取网络类型
    NSArray *typeArr = [NSArray arrayWithObjects:@"2G", @"3G", @"4G", @"5G", @"wifi", nil];
    _curNetType = [self getNetworkConnectionType];
    if (_curNetType == 0) {
        [self recordStepInfo:[NSString stringWithFormat:@"Is currently online: offline"]];
    } else {
        [self recordStepInfo:[NSString stringWithFormat:@"Is currently online: online"]];
        if (_curNetType > 0 && _curNetType < 6) {
            [self
                recordStepInfo:[NSString stringWithFormat:@"Current network type: %@",
                                                          [typeArr objectAtIndex:_curNetType - 1]]];
        }
    }

    //本地ip信息
    _localIp = [LDNetGetAddress deviceIPAdress];
    [self recordStepInfo:[NSString stringWithFormat:@"Local IP: %@", _localIp]];

    if (_curNetType == NETWORK_TYPE_WIFI) {
        _gatewayIp = [LDNetGetAddress getGatewayIPAddress];
        [self recordStepInfo:[NSString stringWithFormat:@"Local Gateway: %@", _gatewayIp]];
    } else {
        _gatewayIp = @"";
    }


    _dnsServers = [NSArray arrayWithArray:[LDNetGetAddress outPutDNSServers]];
    [self recordStepInfo:[NSString stringWithFormat:@"Local DNS: %@",
                                                    [_dnsServers componentsJoinedByString:@", "]]];
}

/**
 * 构建ping列表并进行ping诊断
 */
- (void)pingDialogsisWithHost:(NSString *)host
{
    //诊断ping信息, 同步过程
    NSMutableArray *pingAdd = [[NSMutableArray alloc] init];
    NSMutableArray *pingInfo = [[NSMutableArray alloc] init];
    
    [self recordStepInfo:@"\nStart ping..."];
    [_netPinger runWithHostName:host normalPing:YES];
    
//    if (pingLocal) {
//        [pingAdd addObject:@"127.0.0.1"];
//        [pingInfo addObject:@"Local"];
//        [pingAdd addObject:_localIp];
//        [pingInfo addObject:@"Local IP"];
//        if (_gatewayIp && ![_gatewayIp isEqualToString:@""]) {
//            [pingAdd addObject:_gatewayIp];
//            [pingInfo addObject:@"Local Gateway"];
//        }
//        if ([_dnsServers count] > 0) {
//            [pingAdd addObject:[_dnsServers objectAtIndex:0]];
//            [pingInfo addObject:@"DNS Server"];
//        }
//    }

    

//    for (int i = 0; i < [pingAdd count]; i++) {
//        [self recordStepInfo:[NSString stringWithFormat:@"ping: %@ %@ ...",
//                                                        [pingInfo objectAtIndex:i],
//                                                        [pingAdd objectAtIndex:i]]];
//        if ([[pingAdd objectAtIndex:i] isEqualToString:kPingOpenServerIP]) {
//            [_netPinger runWithHostName:[pingAdd objectAtIndex:i] normalPing:YES];
//        } else {
//            [_netPinger runWithHostName:[pingAdd objectAtIndex:i] normalPing:YES];
//        }
//    }
}


#pragma mark -
#pragma mark - netPingDelegate

- (void)appendPingLog:(NSString *)pingLog
{
    [self recordStepInfo:pingLog];
}

- (void)netPingDidEnd
{
    // net
}

#pragma mark - traceRouteDelegate
- (void)appendRouteLog:(NSString *)routeLog
{
    [self recordStepInfo:routeLog];
}

- (void)traceRouteDidEnd
{
    self.finishDomainCount++;
    
    if (self.finishDomainCount == self.domainList.count) {
        // 设置 _isRunning 标志位为 NO
//        _isRunning = NO;
        [self setIsRunning:NO];
        
        // 通知代理诊断结束
        [self recordStepInfo:@"Diagnosis End..."];
        
        if (self.didEndBlock) {
            self.didEndBlock(_logInfo);
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(netDiagnosisDidEnd:)]) {
            [self.delegate netDiagnosisDidEnd:_logInfo];
        }
    }
}

#pragma mark - connectDelegate
- (void)appendSocketLog:(NSString *)socketLog
{
    [self recordStepInfo:socketLog];
}

- (void)connectDidEnd:(BOOL)success
{
    if (success) {
        _connectSuccess = YES;
    }
}


#pragma mark - common method
/**
 * 如果调用者实现了stepInfo接口，输出信息
 */
- (void)recordStepInfo:(NSString *)stepInfo
{
    if (stepInfo == nil) stepInfo = @"";
    [_logInfo appendString:stepInfo];
    [_logInfo appendString:@"\n"];

    if (self.delegate && [self.delegate respondsToSelector:@selector(netDiagnosisStepInfo:)]) {
        [self.delegate netDiagnosisStepInfo:[NSString stringWithFormat:@"%@\n", stepInfo]];
    }
}


/**
 * 获取deviceID
 */
- (NSString *)uniqueAppInstanceIdentifier
{
    NSString *app_uuid = @"";
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
    app_uuid = [NSString stringWithString:(__bridge NSString *)uuidString];
    CFRelease(uuidString);
    CFRelease(uuidRef);
    return app_uuid;
}

#pragma mark - RNCConnectionStateWatcherDelegate
- (void)connectionStateWatcher:(RNCConnectionStateWatcher *)connectionStateWatcher didUpdateState:(RNCConnectionState *)state
{
    _curNetType = [self resolveConnectionState:state];
}

- (NETWORK_TYPE)resolveConnectionState:(RNCConnectionState *)state
{
    NETWORK_TYPE resultType = NETWORK_TYPE_NONE;
    
    if ([state.type isEqualToString:RNCConnectionTypeNone]) {
        resultType = NETWORK_TYPE_NONE;
    }
    
    if ([state.type isEqualToString:RNCConnectionTypeWifi] || [state.type isEqualToString:RNCConnectionTypeEthernet]) {
        resultType = NETWORK_TYPE_WIFI;
    }
    
    if ([state.type isEqualToString:RNCCellularGeneration2g] ) {
        resultType = NETWORK_TYPE_2G;
    }
    
    if ([state.type isEqualToString:RNCCellularGeneration3g] ) {
        resultType = NETWORK_TYPE_3G;
    }
    
    if ([state.type isEqualToString:RNCCellularGeneration4g] ) {
        resultType = NETWORK_TYPE_4G;
    }
    
    return resultType;
}

- (NETWORK_TYPE)getNetworkConnectionType
{
    return [self resolveConnectionState:self.connectionStateWatcher.currentState];
}

#pragma mark - Thread Safe
- (BOOL)isRunning {
    return _IsRunning != 0;
}

- (void)setIsRunning:(BOOL)allowed {
    if (allowed) {
        OSAtomicOr32Barrier(1, & _IsRunning); //Atomic bitwise OR of two 32-bit values with barrier
    } else {
        OSAtomicAnd32Barrier(0, & _IsRunning); //Atomic bitwise AND of two 32-bit values with barrier.
    }
}

@end
