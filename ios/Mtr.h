#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "LDNetDiagnoService.h"

@interface Mtr : RCTEventEmitter <RCTBridgeModule, LDNetDiagnoServiceDelegate>

@end
