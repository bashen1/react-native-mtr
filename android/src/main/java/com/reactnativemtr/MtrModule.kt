package com.reactnativemtr

import android.widget.Toast
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter


class MtrModule(private var reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(
  reactContext
) {
  override fun getName(): String {
    return "Mtr"
  }

  private var netDiagnoService: LDNetDiagnoService? = null
  var callback: Callback? = null

  @get:ReactMethod(isBlockingSynchronousMethod = true)
  var isRunningSync = false

  @ReactMethod
  fun onFinish(callback: Callback?) {
    this.callback = callback
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun isRunning(): Boolean {
    return netDiagnoService?.isCancelled()!!
  }

  @ReactMethod
  fun stopNetDiagnosis() {
    isRunningSync = false
    netDiagnoService?.stopNetDialogsis()
//    Toast.makeText(reactContext, "结束", Toast.LENGTH_SHORT).show()
  }

  @ReactMethod
  fun startNetDiagnosis(params: ReadableMap) {
    if (isRunningSync) return
    isRunningSync = true
    start(params)
  }

  @ReactMethod
  fun addListener(eventName: String?) {
  }

  @ReactMethod
  fun removeListeners(count: Int?) {
  }

  var str = ""
  private fun getResult(code: Int, message: String, data: String): WritableMap {
    val params = Arguments.createMap()
    params.putInt("code", code)
    params.putString("message", message)
    params.putString("data", data)
    return params
  }

  private fun sendEvent(reactContext: ReactContext, params: WritableMap?) {
    reactContext.getJSModule(RCTDeviceEventEmitter::class.java).emit("DiagnosisEvent", params)
  }

  fun start(params: ReadableMap) {
    var theAppCode = params.getString("theAppCode")
    if ("" == theAppCode) theAppCode = "theAppCode"
    var appName = params.getString("appName")
    if ("" == appName) appName = "appName"
    var appVersion = params.getString("appVersion")
    if ("" == appVersion) appVersion = DeviceUtils.getVersion(
      reactApplicationContext
    )
    var userID = params.getString("userID")
    if ("" == userID) userID = DeviceUtils.getAndroidID(
      reactApplicationContext
    )
    val deviceID = params.getString("deviceID")
    val domain = params.getString("dormain")
//    Toast.makeText(reactContext, domain, Toast.LENGTH_SHORT).show()
    str = ""
    sendEvent(reactContext, getResult(1, "诊断开始", str))
    netDiagnoService = LDNetDiagnoService(
      reactContext,
      theAppCode,
      appName,
      appVersion,
      userID,
      deviceID,
      domain,
      "carriname",
      "ISOCountyCode",
      "MobilCountryCode",
      "MobileNetCode",
      false,
      object : LDNetDiagnoListener {
        override fun OnNetDiagnoFinished(log: String) {
          if (callback != null) callback!!.invoke(log)
          isRunningSync = false
          str = log
          sendEvent(reactContext, getResult(0, "诊断结束", str))
        }

        override fun OnNetDiagnoUpdated(log: String) {
          str += log
          sendEvent(reactContext, getResult(2, "诊断中", str))
        }
      }
    )
    // 设置是否使用JNIC 完成traceroute
    netDiagnoService!!.setIfUseJNICTrace(true)
    //netDiagnoService.setIfUseJNICConn(true);
    netDiagnoService!!.execute()
  }


}
