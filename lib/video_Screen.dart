
// video_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';

import 'camera_utils.dart';
import 'video_model.dart';
import 'video_player_widget.dart';

class VideoScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  VideoScreen({required this.cameras});

  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late CameraController _cameraController;
  bool isRecording = false;
  bool isPaused = false;
  bool isFrontCamera = false;
  List<VideoModel> recordedVideos = [];
  List<VideoModel> uploadedVideos = [];
  List<VideoModel> allVideos = [];
  int currentVideoIndex = 0;
  late VideoPlayerController _videoPlayerController;
  Stopwatch _stopwatch = Stopwatch();
  DateTime? _startTime;
  Timer? _timer;

  bool showCamera = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    CameraUtils.initializeCamera(widget.cameras, _onCameraInitialized);
    _loadVideos();
  }

  void _onCameraInitialized(CameraController controller) {
    setState(() {
      _cameraController = controller;
    });
  }

  Future<void> _loadVideos() async {
    final Set<VideoModel> uniqueVideos = {...recordedVideos, ...uploadedVideos};
    allVideos = uniqueVideos.toList();
    allVideos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {});
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      print("No cameras available");
      return;
    }

    _cameraController = CameraController(cameras[0], ResolutionPreset.high);

    _cameraController.addListener(() {
      if (isRecording) {
        setState(() {});
      }
    });

    try {
      await _cameraController.initialize();
      print("Camera Initialized Successfully");
    } catch (error) {
      print("Error Initializing Camera: $error");
    }
  }

  Future<void> _startRecording() async {
    _stopwatch.start();
    _startTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {});
    });

    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String videoPath =
        '${appDirectory.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    await _cameraController.startVideoRecording();
    setState(() {
      isRecording = true;
      isPaused = false;
      showCamera = true;
    });
  }

  Future<void> _pauseRecording() async {
    await _cameraController.pauseVideoRecording();
    setState(() {
      isPaused = true;
    });
  }

  Future<void> _resumeRecording() async {
    await _cameraController.resumeVideoRecording();
    setState(() {
      isPaused = false;
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _stopwatch.stop();
    final XFile videoFile = await _cameraController.stopVideoRecording();
    setState(() {
      isRecording = false;
      showCamera = false;
      recordedVideos.add(VideoModel(path: videoFile.path));
      allVideos = [...recordedVideos, ...uploadedVideos];
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Video Recorded Successfully'),
          content: Text('Video has been saved.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration() {
    if (_startTime != null) {
      final duration = DateTime.now().difference(_startTime!);
      final minutes = duration.inMinutes;
      final remainingSeconds = duration.inSeconds % 60;

      if (minutes == 0) {
        return '$remainingSeconds seconds';
      } else {
        return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} minutes';
      }
    }

    return '0 seconds';
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;
      final File pickedFile = File(filePath);

      if (pickedFile.path.toLowerCase().endsWith('.mp4')) {
        setState(() {
          uploadedVideos.add(VideoModel(path: filePath));
          allVideos = [...recordedVideos, ...uploadedVideos];
        });
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Invalid File Type'),
              content: Text('Please select a valid video file.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    final CameraDescription newCamera =
        isFrontCamera ? widget.cameras[0] : widget.cameras[1];
    if (_cameraController != null) {
      await _cameraController.dispose();
    }
    _cameraController = CameraController(newCamera, ResolutionPreset.high);
    try {
      await _cameraController.initialize();
      setState(() {
        isFrontCamera = !isFrontCamera;
      });

      Fluttertoast.showToast(
          msg: isFrontCamera
              ? "Switched to Front Camera"
              : "Switched to Back Camera",
          backgroundColor: Colors.green);
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      notchMargin: 4,
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                if (isRecording) {
                  _stopRecording();
                } else {
                  _startRecording();
                }
              },
              child: Text(isRecording ? 'Stop Recording' : 'Record Video'),
            ),
            ElevatedButton(
              onPressed: _pickVideo,
              child: const Text('Upload from Device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showCamera)
          Container(
            // height: 500,
            // width: 500,
            height: MediaQuery.of(context).size.height * 0.6,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_cameraController),
                if (isRecording)
                  Positioned(
                    bottom: 10,
                    child: Column(
                      children: [
                        Text(
                          isPaused ? 'Recording Paused' : 'Recording...',
                          style: TextStyle(
                            color: isPaused
                                ? Color.fromARGB(255, 220, 58, 33)
                                : Color.fromARGB(255, 155, 231, 4),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        // ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(3, 15, 250, 1), // Light red background color
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_formatDuration()}',
                            style: const TextStyle(
                              color: Color.fromARGB(
                                  255, 228, 229, 223), // Red text color
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 10,
                  child: Text(
                    isFrontCamera ? 'Front Camera' : 'Back Camera',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ClipOval(
              child: Material(
                color: isRecording
                    ? Colors.blue.shade400
                    : Colors.blue, // Adjust the shade as needed
                child: IconButton(
                  icon: Icon(
                    isRecording ? Icons.pause : Icons.fiber_manual_record,
                    color: Colors.white, // Specify your desired icon color
                  ),
                  onPressed: isRecording
                      ? isPaused
                          ? _resumeRecording
                          : _pauseRecording
                      : _startRecording,
                  tooltip: isRecording ? 'Pause Recording' : 'Start Recording',
                ),
              ),
            ),
            ClipOval(
              child: Material(
                color: Colors.red, // Specify your desired background color
                child: IconButton(
                  icon: const Icon(
                    Icons.stop,
                    color: Colors.white, // Specify your desired icon color
                  ),
                  onPressed: isRecording ? _stopRecording : null,
                  tooltip: 'Stop Recording',
                ),
              ),
            ),
            ClipOval(
              child: Material(
                color: Colors.blue, // Specify your desired background color
                child: IconButton(
                  icon: Icon(
                    Icons.file_upload,
                    color: Colors.white, // Specify your desired icon color
                  ),
                  onPressed: isRecording ? null : _pickVideo,
                  tooltip: 'Upload Video',
                ),
              ),
            ),
            ClipOval(
              child: Material(
                color: Colors.blue, // Specify your desired background color
                child: IconButton(
                  icon: Icon(
                    Icons.switch_camera,
                    color: Colors.white, // Specify your desired icon color
                  ),
                  onPressed: isRecording ? null : _switchCamera,
                  tooltip: 'Switch Camera',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Center(
            child: Text('Video Recording App ',
                style: TextStyle(color: Colors.white))),
        backgroundColor: Colors.blue, // Set app bar background color
        actions: [
          if (allVideos.isNotEmpty)
            IconButton(
              color: Color.fromARGB(255, 244, 244, 246),
              icon: Icon(Icons.list),
              onPressed: () => _showRecordedVideos(),
              tooltip: 'Show Recorded Videos',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildCameraWidget(),
          Expanded(
            child: ListView.builder(
              itemCount: allVideos.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Color.fromARGB(255, 234, 237, 240),
                  elevation: 3,
                  margin: EdgeInsets.all(10),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _playVideo(index),
                        child: Container(
                          width: double.infinity,
                          color: Color.fromARGB(255, 172, 219, 242),
                          child: _buildVideoItem(index),
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Likes ❤️ ${allVideos[index].likes}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 187, 0, 239)),
                        ),
                        trailing: ClipOval(
                          child: Material(
                            color: allVideos[index].isLiked
                                ? Colors.red
                                : Color.fromARGB(255, 33, 33, 243),
                            child: IconButton(
                              icon: Icon(
                                allVideos[index].isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: Colors.white,
                              ),
                              onPressed: () => _likeVideo(index),
                              tooltip: 'Like Video',
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Future<void> _playVideo(int index) async {
    if (_videoPlayerController != null) {
      await _videoPlayerController.dispose();
    }
    _videoPlayerController = VideoPlayerController.file(
      File(allVideos[index].path),
    );

    await _videoPlayerController.initialize();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayer(_videoPlayerController),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _videoPlayerController.pause();
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoItem(int index) {
    final File videoFile = File(allVideos[index].path);

    if (videoFile.path.toLowerCase().endsWith('.mp4')) {
      return VideoPlayerWidget(videoFile);
    } else {
      return Text('Invalid file type');
    }
  }

  void _likeVideo(int index) {
    setState(() {
      allVideos[index].isLiked = !allVideos[index].isLiked;
      if (allVideos[index].isLiked) {
        allVideos[index].likes++;
      } else {
        allVideos[index].likes--;
      }
    });
  }

  Future<void> _showReplyDialog(int index) async {
    // Remaining code for showing a reply dialog...
  }

  Future<void> _showRecordedVideos() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Recorded Videos'),
          content: Column(
            children: [
              for (int i = 0; i < allVideos.length; i++)
                ListTile(
                  title: Text('Video ${i + 1}'),
                  onTap: () {
                    Navigator.pop(context);
                    _playVideo(i);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _videoPlayerController?.dispose();
    _timer?.cancel();
    super.dispose();
  }
}
