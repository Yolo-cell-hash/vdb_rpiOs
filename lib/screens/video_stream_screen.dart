import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:vdp_poc_new/widgets/home_screen_func_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/janus_webrtc_client.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vdp_poc_new/widgets/full_screen_video_view.dart';
import 'package:vdp_poc_new/utils/web_api_brain.dart';

class VideoStreamScreen extends StatefulWidget {
  const VideoStreamScreen({super.key});

  @override
  _VideoStreamScreenState createState() => _VideoStreamScreenState();
}

class _VideoStreamScreenState extends State<VideoStreamScreen> {
  late String ip;
  late String? ipType;
  String? _recordedFilePath;
  BleUtil bleUtil = BleUtil();
  bool isStremVisible = false;
  bool isStreamStarted = false;
  String counterValue = '0';
  bool isDisconnectVisible = false;
  bool isConnectVisible = true;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  FbUtils fbUtils = FbUtils();
  WebApi webApi = WebApi();
  GlobalKey _repaintBoundaryKey = GlobalKey();

  bool _connected = false;
  String _status = 'Disconnected';
  late JanusWebRTCClient _client;

  MediaRecorder? _mediaRecorder;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _showControls = false;
  Timer? _hideControlsTimer;

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _connect() async {
    try {
      await _client.connect();
      await _client.attachToStreamingPlugin();
      // await _client.keepAlive();

      setState(() {
        _connected = true;
        _status = 'Connected to Janus Streaming';
      });
      await _client.listStreams();
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
      });
    }
  }

  void _watchStream() async {
    final streamId = 7;                              //////STREAM ID HERE, CHANGES HERE !!!
    await _client.watchStream(streamId);
    print(
      'Wacth Stream Called ---------------------------------------------------------------',
    );
  }

  Future<void> connectOnPageInit() async {
    try {
      await _client.connect();
      await _client.attachToStreamingPlugin();
      // await _client.keepAlive();
      setState(() {
        _connected = true;
        _status = 'Connected to Janus Streaming';
      });
      await _client.listStreams();
    } catch (e) {
      print(e);
      setState(() {
        _status = 'Connection failed: $e';
      });
    }
  }

  void _startStream() async {
    final streamId = 7;
    if (streamId != null) {
      await _client.startStream(streamId);
    }
  }

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void initState() {
    super.initState();
    _initRenderers();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loaderProvider = Provider.of<LoaderProvider>(
        context,
        listen: false,
      );
      loaderProvider.showLoader();
      try {
        ip = Provider.of<LoaderProvider>(context, listen: false).ip;

        ipType = (await fbUtils.readIpType()).toString();

        print('IP TYPE IS ---------- $ipType');

        if(ipType == "IPv6"){
          _client = JanusWebRTCClient('ws://[$ip]:8188');
          await connectOnPageInit();
          _client.messages.listen((message) {
            if (mounted) {
              setState(() {
                _status = message;
              });
            }
          });
          _client.remoteStream.listen((stream) {
            if (mounted) {
              setState(() {
                _remoteRenderer.srcObject = stream;
              });
            }
          });
        } else if(ipType == "IPv4"){
          _client = JanusWebRTCClient('ws://$ip:8188');
          await connectOnPageInit();
          _client.messages.listen((message) {
            if (mounted) {
              setState(() {
                _status = message;
              });
            }
          });
          _client.remoteStream.listen((stream) {
            if (mounted) {
              setState(() {
                _remoteRenderer.srcObject = stream;
              });
            }
          });
        } else {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Oops...',
            text: 'IP Type is neither IPv4 nor IPv6',
            confirmBtnColor: const Color(0xFFE30A17),
          );
        }


      } finally {
        loaderProvider.hideLoader();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No connection logic here
  }

  @override
  void dispose() {
    _mediaRecorder?.stop();
    _recordingTimer?.cancel();
    _client.disconnect();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final macAddress = Provider.of<LoaderProvider>(context).macAddress;
    String fb_path = Provider.of<LoaderProvider>(context, listen: false).firebasePath;
    FirebaseDatabase database = fbUtils.database;

    return Consumer<LoaderProvider>(
      builder: (context, loaderProvider, child) {
        return ModalProgressHUD(
          inAsyncCall: loaderProvider.isLoading,
          child: PopScope(
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) {
                loaderProvider.showLoader();
                await _client.disconnect();
                DatabaseReference userResponseFieldRef = database.ref(
                  '/${fb_path}/sendFeed',
                );
                try {
                  await userResponseFieldRef.set(false);
                  loaderProvider.hideLoader();
                } catch (e) {
                  print('Error updating user response to false: $e');
                  loaderProvider.hideLoader();
                }
              }
            },
            child: Scaffold(
              appBar: AppBar(
                toolbarHeight: 90,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.lightBlueAccent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                leading: Builder(
                  builder:
                      (context) => IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _client.disconnect();
                      DatabaseReference userResponseFieldRef = database.ref(
                        '/${fb_path}/sendFeed',
                      );
                      try {
                        await userResponseFieldRef.set(false);
                        print(
                          'User response updated to true in Firebase at /${fb_path}/userResponse',
                        );
                      } catch (e) {
                        print('Error updating user response to true: $e');
                      }
                    },
                  ),
                ),
                title: const Text(
                  'Live Feed',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25.0,
                  vertical: 15.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        'Main Door',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Visibility(
                          visible: isConnectVisible,
                          child: Visibility(
                            visible: isStreamStarted ? false : true,
                            child: HomeScreenFuncButton(
                              btnLabel: 'Watch Feed',
                              iconData: Icons.video_call,
                              callBack: () {
                                try {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.confirm,
                                    title: 'Alert',
                                    text:
                                    'Do you want to view the stream on $ip ?',
                                    confirmBtnColor: Colors.green,
                                    confirmBtnText: 'Yes',
                                    cancelBtnText: 'No',
                                    onConfirmBtnTap: () async {
                                      Navigator.pop(context);
                                      _watchStream();

                                      DatabaseReference userResponseFieldRef =
                                      database.ref('/${fb_path}/sendFeed');
                                      try {
                                        await userResponseFieldRef.set(true);
                                        print(
                                          'User response updated to true in Firebase at /updates/userResponse',
                                        );
                                        setState(() {
                                          isStreamStarted = true;
                                        });
                                      } catch (e) {
                                        print(
                                          'Error updating user response to true: $e',
                                        );
                                      }
                                    },
                                    onCancelBtnTap: () async {
                                      Navigator.pop(context);
                                      DatabaseReference userResponseFieldRef =
                                      database.ref('/${fb_path}/sendFeed');

                                      try {
                                        await userResponseFieldRef.set(true);
                                        print(
                                          'User response updated to true in Firebase at /updates/userResponse',
                                        );
                                      } catch (e) {
                                        print(
                                          'Error updating user response to true: $e',
                                        );
                                      }
                                    },
                                  );
                                } catch (e) {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: 'No Image to save',
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Visibility(
                      visible: isStreamStarted ? false : true,
                      child: SizedBox(height: 30),
                    ),
                    if (_connected && isStreamStarted)
                      Container(
                        margin: EdgeInsets.all(0.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blueAccent,
                            width: 5,
                          ),
                        ),
                        child: SizedBox(
                          width: double.maxFinite,
                          height: MediaQuery.of(context).size.height * 0.35,
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showControls = !_showControls;
                                    });
                                    if (_showControls) {
                                      _hideControlsTimer?.cancel();
                                      _hideControlsTimer = Timer(
                                        Duration(milliseconds: 2500),
                                            () {
                                          if (mounted) {
                                            setState(() {
                                              _showControls = false;
                                            });
                                          }
                                        },
                                      );
                                    }
                                  },
                                  child: RepaintBoundary(
                                    key: _repaintBoundaryKey,
                                    child: RTCVideoView(
                                      _remoteRenderer,
                                      filterQuality: FilterQuality.high,
                                      objectFit:
                                      RTCVideoViewObjectFit
                                          .RTCVideoViewObjectFitCover,
                                      mirror: false,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Flash(
                                    animate: true,
                                    infinite: true,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        Text(
                                          ' Live',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isRecording)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            color: Colors.red,
                                            size: 12,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            _formatDuration(_recordingDuration),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_showControls)
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      color: Colors.black26,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.fullscreen,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => FullScreenVideoView(
                                                renderer: _remoteRenderer,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 30),

                    Visibility(
                      visible: isStreamStarted,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          HomeScreenFuncButton(
                            btnLabel: 'Unlock',
                            iconData: Icons.door_front_door,
                            callBack: () async {
                              // loaderProvider.showLoader();
                              DatabaseReference userResponseFieldRef = database
                                  .ref('/${fb_path}/unlockDoor');
                              try {
                                await userResponseFieldRef.set(true);
                                int value = await webApi.unlockDoor(context);
                              } catch (e) {
                                loaderProvider.hideLoader();

                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Oops...',
                                  text: 'Failed to Unlock Door',
                                  confirmBtnColor: const Color(0xFFE30A17),
                                );
                              }
                            },
                          ),
                          HomeScreenFuncButton(
                            btnLabel: 'Capture',
                            iconData: Icons.camera,
                            callBack: () async {
                              try {
                                // Create a key to identify the video widget
                                final GlobalKey repaintBoundaryKey =
                                GlobalKey();

                                setState(() {
                                  _repaintBoundaryKey = repaintBoundaryKey;
                                });
                                await Future.delayed(
                                  Duration(milliseconds: 100),
                                );

                                // Capture the video frame
                                RenderRepaintBoundary boundary =
                                repaintBoundaryKey.currentContext!
                                    .findRenderObject()
                                as RenderRepaintBoundary;
                                ui.Image image = await boundary.toImage(
                                  pixelRatio: 3.0,
                                );
                                ByteData? byteData = await image.toByteData(
                                  format: ui.ImageByteFormat.png,
                                );
                                Uint8List imageBytes =
                                byteData!.buffer.asUint8List();

                                // Save to gallery
                                final result =
                                await ImageGallerySaverPlus.saveImage(
                                  imageBytes,
                                  quality: 100,
                                  name:
                                  'door_capture_${DateTime.now().millisecondsSinceEpoch}',
                                );

                                // Show success message
                                if (result != null && result['isSuccess']) {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.success,
                                    title: 'Success',
                                    text: 'Image saved to gallery',
                                  );
                                } else {
                                  throw Exception('Failed to save image');
                                }
                              } catch (e) {
                                print('Error: $e');
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Oops...',
                                  text: 'Failed to capture image',
                                  confirmBtnColor: const Color(0xFFE30A17),
                                );
                              }
                            },
                          ),
                          HomeScreenFuncButton(
                            btnLabel: _isRecording ? 'Stop' : 'Record',
                            iconData:
                            _isRecording
                                ? Icons.stop
                                : Icons.emergency_recording,
                            callBack: () async {
                              if (_isRecording) {
                                // Stop recording
                                try {
                                  _recordingTimer?.cancel();

                                  await _mediaRecorder?.stop();
                                  final result =
                                  await ImageGallerySaverPlus.saveFile(
                                    _recordedFilePath!,
                                    name:
                                    'door_recording_${DateTime.now().millisecondsSinceEpoch}',
                                  );

                                  if (result != null && result['isSuccess']) {
                                    QuickAlert.show(
                                      context: context,
                                      type: QuickAlertType.success,
                                      title: 'Success',
                                      text: 'Video saved to gallery',
                                    );
                                  } else {
                                    throw Exception('Failed to save video');
                                  }

                                  setState(() {
                                    _isRecording = false;
                                    _mediaRecorder = null;
                                    _recordingDuration = 0;
                                  });
                                } catch (e) {
                                  print('Error stopping recording: $e');
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: 'Failed to save recording',
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              } else {
                                // Start recording
                                try {
                                  if (_remoteRenderer.srcObject == null) {
                                    throw Exception(
                                      'No video stream to record',
                                    );
                                  }

                                  // Create temp file for recording
                                  Directory tempDir =
                                  await getTemporaryDirectory();
                                  String tempPath =
                                      '${tempDir.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
                                  _recordedFilePath = tempPath;

                                  // Initialize media recorder
                                  _mediaRecorder = MediaRecorder();
                                  final videoTrack =
                                      _remoteRenderer.srcObject!
                                          .getVideoTracks()
                                          .first;

                                  await _mediaRecorder!.start(
                                    tempPath,
                                    videoTrack: videoTrack,
                                  );

                                  // Reset and start the recording timer
                                  setState(() {
                                    _isRecording = true;
                                    _recordingDuration = 0;
                                  });

                                  _recordingTimer = Timer.periodic(
                                    Duration(seconds: 1),
                                        (timer) {
                                      setState(() {
                                        _recordingDuration++;
                                      });
                                    },
                                  );

                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.info,
                                    title: 'Recording',
                                    text: 'Video recording started',
                                    autoCloseDuration: Duration(seconds: 2),
                                  );
                                } catch (e) {
                                  print('Error starting recording: $e');
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: 'Failed to start recording',
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
