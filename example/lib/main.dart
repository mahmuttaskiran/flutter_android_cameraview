import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_camera_view/flutter_camera_view.dart';
import 'package:path_provider/path_provider.dart';
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
            return FlatButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) {
                      return CameraViewPage();
                    },
                  ),
                );
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
  final controller = CameraController();
  String path;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          CameraView(
            controller: controller,
          ),
          PageView.builder(
            itemCount: CameraFilter.values.length,
            itemBuilder: (c, i) {
              return Container();
            },
            scrollDirection: Axis.horizontal,
            onPageChanged: (index) {
              var filter = CameraFilter.values[index];
              controller.setFilters([filter]);
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
        if (null != path && !controller.isRecording)
          IconButton(
            icon: Icon(
              Icons.image,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return VideoPlayerScreen(
                      file: File(path),
                    );
                  },
                ),
              );
            },
          ),
        IconButton(
          icon: Icon(
            Icons.switch_camera,
            color: Colors.white,
          ),
          onPressed: () {
            controller.toggleFacing();
          },
        ),
        FloatingActionButton(
          backgroundColor: Colors.red,
          child: Icon(controller.isRecording ? Icons.stop : Icons.videocam),
          onPressed: () async {
            if (controller.isRecording) {
              await controller.stopRecording();
              print('videoRecordingEnd: $path');
            } else {
              final directory = await getApplicationDocumentsDirectory();
              path =
                  '${directory.path}/videofile_${Random().nextInt(100000)}.mp4';
              final isRecording = await controller.startRecording(
                File(path),
                snapshot: true,
              );
              print("startRecordButton: isRecording: $isRecording");
            }
            setState(() {});
          },
        ),
        IconButton(
          icon: Icon(
            controller.flash == CameraFlash.torch
                ? Icons.flash_off
                : Icons.flash_on,
            color: Colors.white,
          ),
          onPressed: () async {
            if (controller.flash == CameraFlash.torch) {
              controller.setFlash(CameraFlash.off);
            } else {
              controller.setFlash(CameraFlash.torch);
            }
            setState(() {});
          },
        ),
      ],
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final File file;
  VideoPlayerScreen({this.file, Key key}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController _controller;
  Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    // Create an store the VideoPlayerController. The VideoPlayerController
    // offers several different constructors to play videos from assets, files,
    // or the internet.
    print('fileInformation: ${widget.file}');
    print('fileSize: ${widget.file.lengthSync()}');
    _controller = VideoPlayerController.file(
      widget.file,
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
        if (_controller.value.initialized) {
          _controller.setLooping(true);
          _controller.play();
        }
      },
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
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
