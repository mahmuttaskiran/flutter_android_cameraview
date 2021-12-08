package com.mahmuttaskiran.cameraview.flutter_camera_view

import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.embedding.engine.plugins.FlutterPlugin

class FlutterCameraViewPlugin: FlutterPlugin {
  override fun onAttachedToEngine(binding FlutterPlugin.FlutterPluginBinding) {
    binding.platformViewRegistry().registerViewFactory("android_camera_view", AndroidCameraViewFactory())
  }

  override fun onDetachedFromEngine(binding FlutterPlugin.FlutterPluginBinding) = Unit
}
