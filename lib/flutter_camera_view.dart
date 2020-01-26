import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum CameraFacing {
  front,
  back,
}

enum CameraFlash {
  on,
  off,
  torch,
  auto,
}

enum CameraFilter {
  NoFilter,
  AutoFix,
  BlackAndWhite,
  Brightness,
  Contrast,
  CrossProcess,
  Documentary,
  Duotone,
  FillLight,
  Gamma,
  Grain,
  GrayScale,
  Hue,
  InvertColors,
  Lomoish,
  Posterize,
  Saturation,
  Sepia,
  Sharpness,
  Temperature,
  Tint,
  Vignette,
}

enum VideoQuality {
  UltraHd,
  FullHd,
  Hd,
  Low,
  VeryLow,
}

class AndroidCameraController {
  static const _channelName = 'android_camera_view_channel';
  final _channel = MethodChannel(_channelName, JSONMethodCodec());

  Function(String, String) onCameraError;

  CameraFacing facing;
  bool isRecording = false;
  bool isOpened = false;
  CameraFlash flash = CameraFlash.off;
  double zoom = 0;

  AndroidCameraController({
    this.facing = CameraFacing.front,
    this.onCameraError,
  }) {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future<bool> startRecording(
    File file, {
    VideoQuality videoQuality = VideoQuality.FullHd,
    Duration maxDuration,
    bool snapshot = false,
    int snapshotMaxWidth,
    int snapshotMaxHeight,
  }) async {
    assert(file != null);
    var result = await _channel
        .invokeMethod(snapshot ? 'takeSnapshot' : 'startRecording', {
      'file': file.path,
      'videoSize': _getVideoSize(videoQuality),
      'maxDuration': maxDuration?.inMilliseconds,
      'maxWidth': snapshotMaxWidth,
      'maxHeight': snapshotMaxHeight,
    });
    if (result == true) {
      isRecording = true;
    }
    return result;
  }

  Future<bool> stopRecording() async {
    final result = await _channel.invokeMethod('stopRecording');
    if (result == true) {
      isRecording = false;
    }
    return result;
  }

  Future<bool> startPreview() {
    return _channel.invokeMethod('startPreview');
  }

  Future<bool> stopPreview() {
    return _channel.invokeMethod('stopPreview');
  }

  Future<bool> setFacing(CameraFacing facing) async {
    final result = await _channel.invokeMethod('setFacing', {
      'facing': facing == CameraFacing.back ? 'BACK' : 'FRONT',
    });
    if (result == true) {
      this.facing = facing;
    }
    return result;
  }

  Future<bool> setFlash(CameraFlash flash) async {
    final str = flash.toString();
    final fstr = str.substring(str.indexOf('.') + 1);
    final result = await _channel.invokeMethod('setFlash', {
      'flash': fstr.toUpperCase(),
    });
    if (result == true) {
      this.flash = flash;
    }
    return result;
  }

  Future<void> setZoom(double zoom) {
    _channel.invokeMethod("setZoom", {
      'zoom': zoom,
    });
    this.zoom = zoom;
    return null;
  }

  Future<void> setFilters(List<CameraFilter> filters) {
    _channel.invokeMethod("setFilters", {
      'filters': filters.map((f) => _filterToString(f)).toList(),
    });
    return null;
  }

  Future<bool> toggleFacing() {
    var newFacing =
        CameraFacing.front == facing ? CameraFacing.back : CameraFacing.front;
    return setFacing(newFacing);
  }

  Future<dynamic> _methodCallHandler(MethodCall call) {
    print(
      "CameraViewController:onMethodCall(method: ${call.method}, arguments: ${call.arguments})",
    );
    final args = call.arguments;
    if (call.method == 'onCameraError') {
      if (onCameraError != null) {
        onCameraError(args['message'], args['stacktrace']);
      }
    } else if (call.method == 'onCameraOpened') {
      isOpened = true;
    } else if (call.method == 'onCameraClosed') {
      isOpened = false;
    } else if (call.method == 'onVideoRecordingStart') {
      isRecording = true;
    } else if (call.method == 'onVideoRecordingEnd') {
      isRecording = false;
    }
    return null;
  }

  _getVideoSize(VideoQuality q) {
    if (q == VideoQuality.FullHd) {
      return '1080p';
    } else if (q == VideoQuality.UltraHd) {
      return '1260p';
    } else if (q == VideoQuality.Hd) {
      return '720p';
    } else if (q == VideoQuality.Low) {
      return '480p';
    }
    return '1080p';
  }

  _filterToString(CameraFilter filter) {
    final strFilter = filter.toString();
    return strFilter.substring(strFilter.indexOf(".") + 1);
  }
}

class CameraView extends StatefulWidget {
  final AndroidCameraController controller;
  CameraView({
    Key key,
    this.controller,
  })  : assert(Platform.isAndroid, 'This plugin olny supports Androd.'),
        assert(controller != null),
        super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'android_camera_view',
      creationParamsCodec: JSONMessageCodec(),
      creationParams: {
        'facing':
            widget.controller.facing == CameraFacing.back ? 'BACK' : 'FRONT',
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.stopPreview();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.startPreview();
    } else {
      widget.controller.stopPreview();
    }
  }
}
