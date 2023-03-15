import { NativeModules } from 'react-native';

type MtrType = {
  multiply(a: number, b: number): Promise<number>;
};

const { Mtr } = NativeModules;

export default Mtr as MtrType;
