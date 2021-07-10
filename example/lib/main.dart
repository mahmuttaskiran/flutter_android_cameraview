import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter_camera_view/flutter_camera_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                Map<Permission, PermissionStatus> statuses = await [
                  Permission.camera,
                  Permission.microphone,
                  Permission.storage,
                ].request();
                if (!statuses.values.contains(PermissionStatus.denied)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        return CameraViewPage();
                      },
                    ),
                  );
                }
              },
              child: Center(
                child: Text('open camera'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CameraViewPage extends StatefulWidget {
  @override
  _CameraViewPageState createState() => _CameraViewPageState();
}

class _CameraViewPageState extends State<CameraViewPage> {
  final FlutterCameraController controller = FlutterCameraController(
    facing: CameraFacing.back,
    resolutionPreset: ResolutionPreset.UHD,
    onCameraError: (e, st) {},
  );
  String? path;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          CameraView(
            controller: controller,
          ),
          ValueListenableBuilder(
            key: ValueKey(controller.value.state),
            valueListenable: controller,
            builder: (context, CameraValue value, child) {
              if (value.state == CameraState.ready) {
                return Container();
              } else if (value.state == CameraState.preparing) {
                return Container(
                  color: Colors.black,
                );
              }
              return Container(
                color: Colors.blue,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildControlButtons(),
          )
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        if (null != path && !controller.value.isRecordingVideo)
          IconButton(
            icon: Icon(
              Icons.image,
              color: Colors.white,
            ),
            onPressed: () {
              if (p.extension(path!) == '.jpg') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return ImageScreen(
                        file: File(path!),
                      );
                    },
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return VideoPlayerScreen(
                        file: File(path!),
                      );
                    },
                  ),
                );
              }
            },
          ),
        if (!controller.value.isRecordingVideo)
          IconButton(
            icon: Icon(
              Icons.switch_camera,
              color: Colors.white,
            ),
            onPressed: () async {
              await controller.toggleFacing();
              setState(() {});
            },
          ),
        if (!controller.value.isRecordingVideo)
          FloatingActionButton(
            backgroundColor: Colors.green,
            child: Icon(Icons.camera),
            onPressed: () async {
              Directory? directory;
              if (Platform.isIOS) {
                directory = await getApplicationDocumentsDirectory();
              } else {
                directory = await getExternalStorageDirectory();
              }
              path =
                  '${directory!.path}/imagefile_${Random().nextInt(100000)}.jpg';
              await controller.takePicture(File(path!));
              setState(() {});
            },
          ),
        FloatingActionButton(
          backgroundColor: Colors.red,
          child: Icon(
              controller.value.isRecordingVideo ? Icons.stop : Icons.videocam),
          onPressed: () async {
            if (controller.value.isRecordingVideo) {
              await controller.stopRecording();
              print('videoRecordingEnd: $path');
            } else {
              Directory? directory;
              if (Platform.isIOS) {
                directory = await getApplicationDocumentsDirectory();
              } else {
                directory = await getExternalStorageDirectory();
              }
              path =
                  '${directory!.path}/videofile_${Random().nextInt(100000)}.mp4';
              final isRecording = await controller.startRecording(
                File(path!),
                storeThumbnail: true,
              );
              print("startRecordButton: isRecording: $isRecording");
            }
            setState(() {});
          },
        ),
        if (!controller.value.isRecordingVideo &&
            controller.value.facing == CameraFacing.back)
          IconButton(
            icon: Icon(
              controller.value.flash == CameraFlash.off
                  ? Icons.flash_off
                  : Icons.flash_on,
              color: Colors.white,
            ),
            onPressed: () async {
              if (controller.value.flash == CameraFlash.on) {
                controller.setFlash(CameraFlash.off);
              } else {
                controller.setFlash(CameraFlash.off);
              }
              setState(() {});
            },
          ),
      ],
    );
  }
}

class ImageScreen extends StatelessWidget {
  const ImageScreen({Key? key, this.file}) : super(key: key);

  final File? file;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Image.file(file!),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final File? file;

  VideoPlayerScreen({this.file, Key? key}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  Future<void>? _initializeVideoPlayerFuture;

  @override
  void initState() {
    // Create an store the VideoPlayerController. The VideoPlayerController
    // offers several different constructors to play videos from assets, files,
    // or the internet.
    print('fileInformation: ${widget.file}');
    print('fileSize: ${widget.file!.lengthSync()}');
    _controller = VideoPlayerController.file(
      widget.file!,
    );
    _initializeVideoPlayerFuture = _controller.initialize();
    super.initState();
  }

  @override
  void dispose() {
    print("isDisposeCalled?true");
    // Ensure disposing of the VideoPlayerController to free up resources.
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // if (_controller.value.isInitialized) {
        //   _controller.setLooping(true);
        //   _controller.play();
        // }
      },
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            _controller.setLooping(true);
            _controller.play();
            // If the VideoPlayerController has finished initialization, use
            // the data it provides to limit the aspect ratio of the VideoPlayer.
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              // Use the VideoPlayer widget to display the video.
              child: VideoPlayer(_controller),
            );
          } else {
            // If the VideoPlayerController is still initializing, show a
            // loading spinner.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
