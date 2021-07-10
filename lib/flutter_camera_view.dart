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

enum CameraState { preparing, ready, error }

class CameraValue {
  final bool isTakingPicture;
  final bool isRecordingVideo;
  final CameraState state;

  final CameraFacing facing;
  final CameraFlash flash;
  final double zoom;
  final ResolutionPreset resolutionPreset;

  const CameraValue({
    this.isTakingPicture = false,
    this.isRecordingVideo = false,
    this.state = CameraState.preparing,
    this.facing = CameraFacing.back,
    this.flash = CameraFlash.off,
    this.zoom = 0,
    this.resolutionPreset = ResolutionPreset.FHD,
  });

  CameraValue copyWith({
    bool? isTakingPicture,
    bool? isRecordingVideo,
    CameraState? state,
    CameraFacing? facing,
    CameraFlash? flash,
    double? zoom,
    ResolutionPreset? resolutionPreset,
  }) {
    return CameraValue(
      isTakingPicture: isTakingPicture ?? this.isTakingPicture,
      isRecordingVideo: isRecordingVideo ?? this.isRecordingVideo,
      state: state ?? this.state,
      facing: facing ?? this.facing,
      flash: flash ?? this.flash,
      zoom: zoom ?? this.zoom,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
    );
  }

  String toString() {
    return '''isTakingPicture = $isTakingPicture, 
      isRecordingVideo = $isRecordingVideo, 
      state = $state,
      facing = $facing,
      flash = $flash,
      zoom = $zoom,
      resolutionPreset = ${resolutionPreset.size}''';
  }
}

class FlutterCameraController extends ValueNotifier<CameraValue> {
  static const _channelName = 'flutter_camera_view_channel';
  final _channel = MethodChannel(_channelName, JSONMethodCodec());

  Function(String, String)? onCameraError;

  Completer<bool>? _videoRecordingCompleter;

  FlutterCameraController({
    CameraFacing facing = CameraFacing.back,
    ResolutionPreset resolutionPreset = ResolutionPreset.FHD,
    required this.onCameraError,
  }) : super(CameraValue(facing: facing, resolutionPreset: resolutionPreset)) {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future<T?> _invokeMethod<T>(String method, [dynamic arguments]) {
    try {
      return _channel.invokeMethod<T>(method, arguments);
    } catch (error) {
      if (value.state == CameraState.preparing) {
        value = value.copyWith(
          state: CameraState.error,
        );
      }
      rethrow;
    }
  }

  void initialized() {
    if (value.state != CameraState.ready) {
      throw CameraException('not_initialized', 'Camera is not initialized');
    }
  }

  Future<bool> startRecording(
    File file, {
    bool storeThumbnail = true,
    Directory? thumbnailPath,
  }) async {
    try {
      var result = await _invokeMethod('startRecording', {
        'file': file.path,
        'storeThumbnail': storeThumbnail,
        'thumbnailPath': thumbnailPath,
      });
      if (result == true) {
        value = value.copyWith(
          isRecordingVideo: true,
        );
      }
      return result;
    } on PlatformException catch (error, stacktrace) {
      value = value.copyWith(
        isRecordingVideo: false,
      );
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> takePicture(File file) async {
    value = value.copyWith(
      isTakingPicture: true,
    );
    try {
      var result = await _invokeMethod('takePicture', {
        'file': file.path,
      });
      if (result == true) {
        value = value.copyWith(
          isTakingPicture: false,
        );
      }
      return result;
    } on PlatformException catch (error, stacktrace) {
      value = value.copyWith(
        isTakingPicture: false,
      );
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> stopRecording() async {
    try {
      final result = await _invokeMethod('stopRecording');
      if (result == true) {
        value = value.copyWith(
          isRecordingVideo: true,
        );
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

  Future<bool> startPreview() async {
    try {
      final bool result = await _invokeMethod('startPreview');
      value = value.copyWith(
        state: CameraState.ready,
      );
      return Future.value(result);
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> stopPreview() async {
    try {
      final bool result = await _invokeMethod('stopPreview');
      value = value.copyWith(
        state: CameraState.preparing,
      );
      return Future.value(result);
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<bool> setFacing(CameraFacing facing) async {
    try {
      final result = await _invokeMethod('setFacing', {
        'facing': facing == CameraFacing.back ? 'BACK' : 'FRONT',
      });
      if (result == true) {
        value = value.copyWith(
          facing: facing,
        );
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
      final result = await _invokeMethod('setFlash', {
        'flash': fstr.toUpperCase(),
      });
      if (result == true) {
        value = value.copyWith(
          flash: flash,
        );
      }
      return result;
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
    return Future.value(false);
  }

  Future<void> setZoom(double zoom) async {
    try {
      await _invokeMethod("setZoom", {
        'zoom': zoom,
      });

      value = value.copyWith(
        zoom: zoom,
      );
    } on PlatformException catch (error, stacktrace) {
      print(error);
      print(stacktrace);
    }
  }

  Future<bool> toggleFacing() {
    var newFacing = CameraFacing.front == value.facing
        ? CameraFacing.back
        : CameraFacing.front;
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

      if (value.state == CameraState.preparing) {
        value = value.copyWith(
          state: CameraState.error,
        );
      }
    } else if (call.method == 'onCameraOpened') {
      value = value.copyWith(
        state: CameraState.ready,
      );
    } else if (call.method == 'onCameraClosed') {
      value = value.copyWith(
        state: CameraState.preparing,
      );
    } else if (call.method == 'onVideoRecordingStart') {
      value = value.copyWith(
        isRecordingVideo: true,
      );
    } else if (call.method == 'onVideoRecordingEnd') {
      value = value.copyWith(
        isRecordingVideo: false,
      );
    } else if (call.method == 'onVideoTaken') {
      if (_videoRecordingCompleter != null) {
        _videoRecordingCompleter!.complete(true);
        _videoRecordingCompleter = null;
      }
      value = value.copyWith(
        isRecordingVideo: false,
      );
    }
    return Future.value();
  }

  @override
  Future<void> dispose() async {
    try {
      _invokeMethod("dispose");
    } catch (e) {}
    super.dispose();
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
          'facing': widget.controller.value.facing == CameraFacing.back
              ? 'BACK'
              : 'FRONT',
          'resolutionPreset': widget.controller.value.resolutionPreset.size,
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'flutter_camera_view',
        creationParamsCodec: JSONMessageCodec(),
        creationParams: {
          'facing': widget.controller.value.facing == CameraFacing.back
              ? 'BACK'
              : 'FRONT',
          'resolutionPreset': widget.controller.value.resolutionPreset.size,
        },
      );
    }

    throw UnsupportedError('Unsupported platform view.');
  }
}

class CameraException implements Exception {
  final String? message;
  final String? title;
  const CameraException([this.title, this.message]);
}
