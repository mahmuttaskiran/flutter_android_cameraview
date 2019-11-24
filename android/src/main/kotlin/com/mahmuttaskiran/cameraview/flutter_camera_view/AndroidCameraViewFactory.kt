package com.mahmuttaskiran.cameraview.flutter_camera_view

import android.content.Context
import io.flutter.plugin.common.JSONMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

import io.flutter.plugin.common.PluginRegistry.Registrar

class AndroidCameraViewFactory(private val mPluginRegistrar: Registrar) : PlatformViewFactory(JSONMessageCodec.INSTANCE) {

  override fun create(context: Context, i: Int, o: Any): PlatformView {
    return AndroidCameraView(mPluginRegistrar, o)
  }

}