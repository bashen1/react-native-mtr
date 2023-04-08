import {NativeModules, DeviceEventEmitter} from 'react-native';

interface Params {
  /**
   * 应用Code
   */
  theAppCode?: string;
  /**
   * 应用名称
   */
  appName?: string;
  /**
   * App版本
   */
  appVersion?: string;
  /**
   * 用户ID（邮箱）
   */
  userID?: string;
  /**
   * 测试域名
   */
  dormain: string;
}

type MtrType = {
  /**
   * 开始诊断
   * @param param 
   */
  startNetDiagnosis(param: Params): Promise<any>;
  /**
   * 停止诊断
   */
  stopNetDiagnosis(): Promise<any>;
  /**
   * 添加监听
   * @param handle 
   */
  addListener(handle: any): void;
  /**
   * 移除监听
   */
  removeListener(): void;
  /**
   * 是否诊断中
   */
  isRunningSync(): boolean;
};

const DIAGNOSIS_EVENT = 'DiagnosisEvent';

const {Mtr} = NativeModules;

class MtrModule {
  static listener: any; //网络监听
  /**
   * 开始诊断
   * @param param 
   */
  static startNetDiagnosis = async (param: Params) => {
    return await Mtr.startNetDiagnosis(param);
  }

  /**
   * 结束诊断
   * @returns 
   */
  static stopNetDiagnosis = async () => {
    return await Mtr.stopNetDiagnosis();
  }

  /**
   * 添加监听
   * @param callback 
   */
  static addListener = (callback: any) => {
    MtrModule.listener = DeviceEventEmitter.addListener(DIAGNOSIS_EVENT, message => {
      callback(message)
    });
  }

  /**
   * 移除监听
   */
  static removeListener = () => {
    MtrModule.listener?.remove?.();
  }

  /**
   * 是否诊断中
   * @returns 
   */
  static isRunningSync = (): boolean => {
    return Mtr.isRunningSync();
  }
}

export default MtrModule as MtrType;
