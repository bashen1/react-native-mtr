//
//  LDNetDiagnoService.h
//  LDNetDiagnoServieDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef void(^LDNetDiagnoServiceDidEndBlock)(NSString *allLogInfo);

/**
 * @protocol 监控网络诊断的过程信息
 *
 */
@protocol LDNetDiagnoServiceDelegate <NSObject>
/**
 * 告诉调用者诊断开始
 */
- (void)netDiagnosisDidStarted;


/**
 * 逐步返回监控信息，
 * 如果需要实时显示诊断数据，实现此接口方法
 */
- (void)netDiagnosisStepInfo:(NSString *)stepInfo;


/**
 * 因为监控过程是一个异步过程，当监控结束后告诉调用者；
 * 在监控结束的时候，对监控字符串进行处理
 */
- (void)netDiagnosisDidEnd:(NSString *)allLogInfo;

@end


/**
 * @class 网络诊断服务
 * 通过对指定域名进行ping诊断和traceRoute诊断收集诊断日志
 */
@interface LDNetDiagnoService : NSObject {
}
@property (nonatomic, weak, readwrite)
    id<LDNetDiagnoServiceDelegate> delegate;      //向调用者输出诊断信息接口
@property (nonatomic, retain) NSString *dormain;  //接口域名

/// 域名列表
@property (nonatomic, strong) NSMutableArray<NSString *> *domainList;


/// 初始化网络诊断服务
/// @param appName app 名称
/// @param appVersion app 版本
/// @param userId 用户 ID
/// @param domainList 域名列表
- (instancetype)initWithAppName:(nonnull NSString *)appName
                     appVersion:(nonnull NSString *)appVersion
                         userId:(nonnull NSString *)userId
                     domainList:(nonnull NSMutableArray <NSString *> *)domainList
                     didEndBlock:(LDNetDiagnoServiceDidEndBlock)didEndBlock;



/**
 * 开始诊断网络
 */
- (void)startNetDiagnosis;


/**
 * 停止诊断网络
 */
- (void)stopNetDialogsis;


/**
 停止诊断网络并返回所有的 log
 */
- (NSString *)stopNetDialogsisAndReturnTotalLog;

/**
 * 打印整体loginInfo；
 */
- (void)printLogInfo;
NS_ASSUME_NONNULL_END
@end
