package com.lucky1213.flutter_camera_view

import io.flutter.plugin.common.PluginRegistry.Registrar

class FlutterCameraViewPlugin {
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      registrar.platformViewRegistry().registerViewFactory("flutter_camera_view",
        AndroidCameraViewFactory(registrar)
      )
    }
  }
}
