import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

enum ResolutionPreset {
  /// 2160p (3840x2160)
  UHD,

  /// 1080p (1920x1080)
  FHD,

  /// 720p (1280x720)
  HD,

  /// 540p (960x540)
  QHD,

  /// 480p (640x480 on iOS, 720x480 on Android)
  LOW,
}

extension ExtensionResolutionPreset on ResolutionPreset {
  String get size {
    String string;
    switch (this) {
      case ResolutionPreset.UHD:
        string = '1260p';
        break;
      case ResolutionPreset.FHD:
        string = '1080p';
        break;
      case ResolutionPreset.HD:
        string = '720p';
        break;
      case ResolutionPreset.QHD:
        string = '540p';
        break;
      case ResolutionPreset.LOW:
        string = '480p';
        break;
      default:
        string = '1080p';
    }
    return string;
  }
}

class FlutterCameraController {
  static const _channelName = 'flutter_camera_view_channel';
  final _channel = MethodChannel(_channelName, JSONMethodCodec());
  final ResolutionPreset resolutionPreset;

  Function(String, String)? onCameraError;

  CameraFacing facing;
  bool isTakingPicture = false;
  bool isRecording = false;
  bool isOpened = false;
  CameraFlash flash = CameraFlash.off;
  double zoom = 0;

  Completer<bool>? _videoRecordingCompleter;

  FlutterCameraController({
    this.facing = CameraFacing.back,
    this.resolutionPreset = ResolutionPreset.FHD,
    required this.onCameraError,
  }) {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future<bool> startRecording(
    File file, {
    Duration? maxDuration,
  }) async {
    try {
      var result = await _channel.invokeMethod('startRecording', {
        'file': file.path,
        'maxDuration': maxDuration?.inMilliseconds,
      });
      if (result == true) {
        isRecording = true;
      }
      return result;
    } on PlatformException catch (error, stacktrace) {
      isRecording = false;
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> takePicture(File file) async {
    isTakingPicture = true;
    try {
      var result = await _channel.invokeMethod('takePicture', {
        'file': file.path,
      });
      if (result == true) {
        isTakingPicture = false;
      }
      return result;
    } on PlatformException catch (error, stacktrace) {
      isTakingPicture = false;
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> stopRecording() async {
    try {
      final result = await _channel.invokeMethod('stopRecording');
      if (result == true) {
        isRecording = false;
      }
      if (_videoRecordingCompleter == null) {
        _videoRecordingCompleter = Completer<bool>();
      }
      return _videoRecordingCompleter!.future;
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
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
    } else if (call.method == 'onVideoRecordingEnd') {
      isRecording = false;
    } else if (call.method == 'onVideoTaken') {
      if (_videoRecordingCompleter != null) {
        _videoRecordingCompleter!.complete(true);
        _videoRecordingCompleter = null;
      }
      isRecording = false;
    }
    return Future.value();
  }

  Future dispose() async {
    await _channel.invokeMethod("dispose");
    return null;
  }
}

class CameraView extends StatefulWidget {
  final FlutterCameraController controller;

  CameraView({
    Key? key,
    required this.controller,
  }) : super(key: key);

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
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'flutter_camera_view',
        creationParamsCodec: JSONMessageCodec(),
        creationParams: {
          'facing':
              widget.controller.facing == CameraFacing.back ? 'BACK' : 'FRONT',
          'resolutionPreset': widget.controller.resolutionPreset.size,
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'flutter_camera_view',
        creationParamsCodec: JSONMessageCodec(),
        creationParams: {
          'facing':
              widget.controller.facing == CameraFacing.back ? 'BACK' : 'FRONT',
          'resolutionPreset': widget.controller.resolutionPreset.size,
        },
      );
    }

    throw UnsupportedError('Unsupported platform view.');
  }
}
