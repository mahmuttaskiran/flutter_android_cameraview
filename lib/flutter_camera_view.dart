import 'dart:async';
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

  Function(String, String)? onCameraError;

  CameraFacing facing;
  bool isRecording = false;
  bool isOpened = false;
  CameraFlash flash = CameraFlash.off;
  double zoom = 0;

  Completer<bool>? _videoRecordingCompleter;
  Function? onVideoRecordingEnd;
  Function? onVideoTaken;
  Function? onVideoRecordingStart;

  AndroidCameraController({
    this.facing = CameraFacing.front,
    required this.onCameraError,
  }) {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future<bool> startRecording(
    File file, {
    VideoQuality videoQuality = VideoQuality.FullHd,
    Duration? maxDuration,
    bool snapshot = false,
    int? snapshotMaxWidth,
    int? snapshotMaxHeight,
  }) async {
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
    if (_videoRecordingCompleter == null) {
      _videoRecordingCompleter = Completer<bool>();
    }
    return _videoRecordingCompleter!.future;
  }

  Future<bool> startPreview() {
    try {
      final result = _channel.invokeMethod('startPreview');
      return result as Future<bool>;
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> stopPreview() {
    try {
      final result = _channel.invokeMethod('stopPreview');
      return result as Future<bool>;
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> setFacing(CameraFacing facing) async {
    try {
      final result = await _channel.invokeMethod('setFacing', {
        'facing': facing == CameraFacing.back ? 'BACK' : 'FRONT',
      });
      if (result == true) {
        this.facing = facing;
      }
      return result;
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> setFlash(CameraFlash flash) async {
    try {
      final str = flash.toString();
      final fstr = str.substring(str.indexOf('.') + 1);
      final result = await _channel.invokeMethod('setFlash', {
        'flash': fstr.toUpperCase(),
      });
      if (result == true) {
        this.flash = flash;
      }
      return result;
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future setZoom(double zoom) {
    try {
      _channel.invokeMethod("setZoom", {
        'zoom': zoom,
      });
      this.zoom = zoom;
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value();
  }

  Future<void> setFilters(List<CameraFilter> filters) {
    try {
      _channel.invokeMethod("setFilters", {
        'filters': filters.map((f) => _filterToString(f)).toList(),
      });
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value();
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
        onCameraError!(args['message'], args['stacktrace']);
      }
      if (_videoRecordingCompleter != null) {
        _videoRecordingCompleter!.complete(false);
      }
    } else if (call.method == 'onCameraOpened') {
      isOpened = true;
    } else if (call.method == 'onCameraClosed') {
      isOpened = false;
    } else if (call.method == 'onVideoRecordingStart') {
      isRecording = true;
      if (onVideoRecordingStart != null) onVideoRecordingStart!();
    } else if (call.method == 'onVideoRecordingEnd') {
      isRecording = false;
      if (onVideoRecordingEnd != null) onVideoRecordingEnd!();
    } else if (call.method == 'onVideoTaken') {
      if (_videoRecordingCompleter != null) {
        _videoRecordingCompleter!.complete(true);
        _videoRecordingCompleter = null;
      }
      if (onVideoTaken != null) onVideoTaken!();
      isRecording = false;
    }
    return Future.value();
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

  Future dispose() async {
    await _channel.invokeMethod("dispose");
    return null;
  }
}

class CameraView extends StatefulWidget {
  final AndroidCameraController controller;

  CameraView({
    Key? key,
    required this.controller,
  })   : assert(Platform.isAndroid, 'This plugin olny supports Androd.'),
        super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  @override
  void initState() {
    super.initState();
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
}
