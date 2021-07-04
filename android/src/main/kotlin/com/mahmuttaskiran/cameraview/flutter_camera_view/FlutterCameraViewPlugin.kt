package com.mahmuttaskiran.cameraview.flutter_camera_view

import io.flutter.plugin.common.PluginRegistry.Registrar

class FlutterCameraViewPlugin {
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      registrar.platformViewRegistry().registerViewFactory("flutter_camera_view",AndroidCameraViewFactory(registrar))
    }
  }
}
