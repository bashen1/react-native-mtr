# react-native-mtr

[![npm version](https://badge.fury.io/js/react-native-mtr.svg)](https://badge.fury.io/js/react-native-mtr)

此项目基于[LDNetDiagnoService_IOS](https://github.com/Lede-Inc/LDNetDiagnoService_IOS)，

## 安装

```sh
npm install react-native-mtr
```

## 使用

```js
import MtrModule from 'react-native-mtr';

//开始诊断
MtrModule.startNetDiagnosis({
  theAppCode: '', //应用Code(可选，可为空)
  appName: '', //应用名称(可选，可为空)
  appVersion: '', //App版本(可选，可为空)
  userID: '', //用户ID（邮箱）(可选，可为空)
  dormain: '', //测试域名，必填
})

//停止诊断
MtrModule.stopNetDiagnosis();

//添加监听
MtrModule.addListener(() => {});

//移除监听
MtrModule.removeListener();

//是否诊断中
MtrModule.isRunningSync();
```

## License

MIT
