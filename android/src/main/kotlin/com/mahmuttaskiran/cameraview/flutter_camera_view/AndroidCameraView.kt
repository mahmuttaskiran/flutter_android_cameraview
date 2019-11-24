package com.mahmuttaskiran.cameraview.flutter_camera_view

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.util.Log
import android.view.View
import androidx.core.content.ContextCompat
import com.otaliastudios.cameraview.*
import com.otaliastudios.cameraview.controls.*
import com.otaliastudios.cameraview.filter.Filter
import com.otaliastudios.cameraview.filter.MultiFilter
import com.otaliastudios.cameraview.filter.NoFilter
import com.otaliastudios.cameraview.filters.*
import com.otaliastudios.cameraview.size.SizeSelector
import com.otaliastudios.cameraview.size.SizeSelectors
import io.flutter.plugin.common.JSONMethodCodec
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.platform.PlatformView
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

var DEFAULT_VIDEO_MAX_DURATION = (60 * 1000) * 60

class AndroidCameraView
internal constructor(private val registrar: Registrar, creationParams: Any) : PlatformView, MethodCallHandler, CameraListener() {
  private var cameraView: CameraView
  private var channel: MethodChannel

  init {
    Log.i("AndroidCameraView", "init!")
    cameraView = initView(registrar, creationParams as JSONObject)
    channel = MethodChannel(registrar.messenger(), "android_camera_view_channel", JSONMethodCodec.INSTANCE)
    channel.setMethodCallHandler(this)
  }

  override fun getView(): View {
    Log.i("AndroidCameraView", "getView")
    return cameraView
  }

  override fun dispose(){
    Log.i("AndroidCameraView", "destroy")
    if (cameraView.isOpened) {
      cameraView.removeCameraListener(this)
      cameraView.close()
      cameraView.destroy()
    }
  }

  @SuppressLint("DefaultLocale")
  private fun initView(registrar: Registrar, options: JSONObject): CameraView {
    Log.i("AndroidCameraView", "initView: $options")
    val cameraView = CameraView(registrar.context())
    cameraView.facing = Facing.valueOf(options.optString("facing", "FRONT").toUpperCase())
    cameraView.mode = Mode.VIDEO
    cameraView.engine = Engine.CAMERA2
    cameraView.preview = Preview.GL_SURFACE
    cameraView.addCameraListener(this)
    cameraView.open()
    return cameraView
  }

  override fun onVideoRecordingStart() {
    Log.i("AndroidCameraView", "onVideoRecordingStart:")
    super.onVideoRecordingStart()
    channel.invokeMethod("onVideoRecordingStart", null)
  }

  override fun onVideoRecordingEnd() {
    Log.i("AndroidCameraView", "onVideoRecordingEnd:")
    channel.invokeMethod("onVideoRecordingEnd", null)
  }

  override fun onVideoTaken(result: VideoResult) {
    Log.i("AndroidCameraView", "onVideoTaken:")
    super.onVideoTaken(result)
    val args = JSONObject()
    args.put("height", result.size.height)
    args.put("width", result.size.width)
    args.put("fileSize", result.file.length())
    args.put("file", result.file.absolutePath)
    channel.invokeMethod("onVideoTaken", args)
  }

  override fun onCameraError(exception: CameraException) {
    exception.printStackTrace()
    Log.i("AndroidCameraView", "onCameraError:")
    super.onCameraError(exception)
    val args = JSONObject()
    args.put("message", exception.message)
    args.put("stacktrace", exception.stackTrace.toString())
    channel.invokeMethod("onCameraError", exception.message)
  }

  override fun onCameraOpened(options: CameraOptions) {
    super.onCameraOpened(options)
    channel.invokeMethod("onCameraOpened",null)
  }

  override fun onCameraClosed() {
    super.onCameraClosed()
    channel.invokeMethod("onCameraClosed",null)
  }

  private fun errorIfCameraNotOpened(result: MethodChannel.Result): Boolean {
    if (!cameraView.isOpened) {
      result.error("CameraError", "Camera is not opened.", null)
      return true
    }
    return false
  }

  private fun errorIfTakingVideo(result: MethodChannel.Result): Boolean {
    if (cameraView.isTakingVideo) {
      result.error("CameraError", "Already is recording video.", null)
      return true
    }
    return false
  }

  private fun errorIfTakingPicture(result: MethodChannel.Result): Boolean {
    if (cameraView.isTakingPicture) {
      result.error("CameraError", "Already is taking picture.", null)
      return true
    }
    return false
  }

  private fun errorIf(condition: Boolean, result: MethodChannel.Result, error: String): Boolean {
    if (condition) {
      result.error("CameraError", error, null)
      return true
    }
    return false
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    Log.i("AndroidCameraView", "onMethodCall: ${call.method} ${call.arguments}")
    val jsonArgs: JSONObject = if (call.arguments != null) {
      call.arguments as JSONObject
    } else {
      JSONObject()
    }
    when (call.method) {
      "startRecording" -> {
        if (errorIfCameraNotOpened(result)) return
        if (errorIfTakingVideo(result)) return
        if (errorIfTakingPicture(result)) return
        val fileInStr = jsonArgs.getString("file")
        val videoSizeInStr = jsonArgs.optString("videoSize", "2160p")
        val maxDuration = jsonArgs.optInt("maxDuration", DEFAULT_VIDEO_MAX_DURATION)
        val file = File(fileInStr)
        if (file.exists()) {
          result.error("CameraError", "${file.path} already exists.", null)
          return
        }
        cameraView.setVideoSize(SizeUtils.getSizeSelector(videoSizeInStr))
        cameraView.takeVideo(file, maxDuration)
        return result.success(true)
      }
      "takeSnapshot" -> {
        if (errorIfCameraNotOpened(result)) return
        if (errorIfTakingVideo(result)) return
        if (errorIfTakingPicture(result)) return
        val fileInStr = jsonArgs.getString("file")
        val maxDuration = jsonArgs.optInt("maxDuration", DEFAULT_VIDEO_MAX_DURATION)
        val file = File(fileInStr)
        if (file.exists()) {
          result.error("CameraError", "${file.path} already exists.", null)
          return
        }
        val maxWidth = jsonArgs.optInt("maxWidth", 0)
        val maxHeight = jsonArgs.optInt("maxHeight", 0)
        if (maxWidth != 0) {
          cameraView.setSnapshotMaxHeight(maxWidth)
        }
        if (maxHeight != 0) {
          cameraView.setSnapshotMaxHeight(maxHeight)
        }
        cameraView.takeVideoSnapshot(file, maxDuration)
        return result.success(true)
      }
      "startPreview" -> {
        if (!cameraView.isOpened) {
          cameraView.open()
        }
        return result.success(true)
      }
      "stopPreview"-> {
        if (cameraView.isOpened) {
          cameraView.close()
        }
        return result.success(true)
      }
      "stopRecording" -> {
        if (errorIfCameraNotOpened(result)) return
        cameraView.stopVideo()
        return result.success(true)
      }
      "isPermissionsGranted" -> {
        result.success(ContextCompat.checkSelfPermission(registrar.context(), Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED && ContextCompat.checkSelfPermission(registrar.context(), Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED)
      }
      "setFacing" -> {
        if (errorIfCameraNotOpened(result)) return
        if (errorIfTakingPicture(result)) return
        if (errorIfTakingVideo(result)) return
        val facingInStr = jsonArgs.getString("facing")
        if (errorIf(facingInStr == null, result, "set facing!")) return
        val facing: Facing = Facing.valueOf(facingInStr)
        cameraView.facing = facing
        cameraView.zoom
        result.success(true)
      }
      "setFlash" -> {
        if (errorIfCameraNotOpened(result)) return
        if (errorIfTakingPicture(result)) return
        if (errorIfTakingVideo(result)) return
        val flashInStr = jsonArgs.getString("flash")
        if (errorIf(flashInStr == null, result, "set flash!")) return
        val flash: Flash = Flash.valueOf(flashInStr)
        cameraView.flash = flash
        result.success(true)
      }
      "setZoom" -> {
        if (errorIfCameraNotOpened(result)) return
        cameraView.zoom = jsonArgs.optDouble("zoom", 0.0).toFloat()
      }
      "setFilters" -> {
        if (errorIfCameraNotOpened(result)) return
        val filter = getFilters(jsonArgs.optJSONArray("filters"))
        cameraView.setExperimental(true)
        cameraView.filter = filter
      }
    }
  }

  private fun getFilters(arr: JSONArray?) : Filter {
    if (arr == null || arr.length() == 0) {
      return NoFilter()
    }
    val filters = MultiFilter()
    for (i: Int in 0 until arr.length()) {
      val filter = arr.getString(i)
      if (filter == null || filter.isEmpty()) continue
      filters.addFilter(getFilter(filter))
    }
    return filters
  }

  private fun getFilter(filter: String): Filter {
    return when (filter) {
      "AutoFix" -> AutoFixFilter()
      "BlackAndWhite" -> BlackAndWhiteFilter()
      "Brightness" -> BrightnessFilter()
      "Contrast"-> ContrastFilter()
      "CrossProcess"-> CrossProcessFilter()
      "Documentary"-> DocumentaryFilter()
      "Duotone"-> DuotoneFilter()
      "FillLight"-> FillLightFilter()
      "Gamma"-> GammaFilter()
      "Grain"-> GrainFilter()
      "GrayScale"-> GrayscaleFilter()
      "Hue"-> HueFilter()
      "InvertColors"-> InvertColorsFilter()
      "Lomoish"-> LomoishFilter()
      "Posterize"-> PosterizeFilter()
      "Saturation"-> SaturationFilter()
      "Sepia"-> SepiaFilter()
      "Sharpness"-> SharpnessFilter()
      "Temperature"-> TemperatureFilter()
      "Tint"-> TintFilter()
      "Vignette"-> VignetteFilter()
      "NoFilter" -> NoFilter()
      else -> NoFilter()
    }
  }
}

class SizeUtils {
  companion object {
    private fun andMin(minWidth: Int, minHeight: Int): SizeSelector {
      val mw = SizeSelectors.minWidth(minWidth)
      val mh = SizeSelectors.minHeight(minHeight)
      return SizeSelectors.and(mw, mh)
    }

    private fun andMax(maxWidth: Int, maxHeight: Int): SizeSelector {
      val mw = SizeSelectors.maxWidth(maxWidth)
      val mh = SizeSelectors.maxHeight(maxHeight)
      return SizeSelectors.and(mw, mh)
    }

    fun getSizeSelector(sizeInStr: String): SizeSelector {
      return when (sizeInStr) {
        "2160p" -> SizeSelectors.or(andMin(3840,2160), SizeSelectors.biggest())
        "1080p" -> SizeSelectors.or(andMin(1920, 1080), andMax(3840, 2060))
        "720p" -> SizeSelectors.or(andMin(1280, 720), andMax(1920, 1080))
        "480p" -> SizeSelectors.or(andMin(720, 480), andMax(1280, 720))
        else -> SizeSelectors.biggest()
      }
    }
  }
}