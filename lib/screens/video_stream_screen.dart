import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/janus_webrtc_client.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoStreamScreen extends StatefulWidget {
  const VideoStreamScreen({super.key});

  @override
  _VideoStreamScreenState createState() => _VideoStreamScreenState();
}

class _VideoStreamScreenState extends State<VideoStreamScreen> {
  dynamic data;
  late String ip;
  BleUtil bleUtil = BleUtil();
  bool isStremVisible = false;
  bool isStreamStarted = false;
  String counterValue = '0';
  bool isDisconnectVisible = false;
  bool isConnectVisible = true;
  FbUtils fbUtils = FbUtils();

  bool _connected = false;
  String _status = 'Disconnected';
  late JanusWebRTCClient _client;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  void _connect() async {
    try {
      await _client.connect();
      await _client.attachToStreamingPlugin();
      await _client.keepAlive();

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
    final streamId = 11;
    await _client.watchStream(streamId);
    print(
      'Wacth Stream Called ---------------------------------------------------------------',
    );
  }

  Future<void> connectOnPageInit() async {
    try {
      await _client.connect();
      await _client.attachToStreamingPlugin();
      await _client.keepAlive();
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
    final streamId = 1;
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
      final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
      loaderProvider.showLoader();
      try {
        ip = Provider.of<LoaderProvider>(context, listen: false).ip;
        _client = JanusWebRTCClient('ws://[$ip]:8188');
        await connectOnPageInit();
        _client.messages.listen((message) {
          setState(() {
            _status = message;
          });
        });
        _client.remoteStream.listen((stream) {
          _remoteRenderer.srcObject = stream;
        });
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
    _client.disconnect();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final macAddress = Provider.of<LoaderProvider>(context).macAddress;
    FirebaseDatabase database = fbUtils.database;

    return Consumer<LoaderProvider>(
      builder: (context,loaderProvider,child){
        return ModalProgressHUD(
          inAsyncCall: loaderProvider.isLoading,
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
                    DatabaseReference userResponseFieldRef = database
                        .ref('/poc_pings/sendFeed');
                    try {
                      await userResponseFieldRef.set(false);
                      print(
                        'User response updated to true in Firebase at /updates/userResponse',
                      );
                    } catch (e) {
                      print(
                        'Error updating user response to true: $e',
                      );
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
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Text(
                      'Main Door',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(height: 30,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Visibility(
                        visible: isConnectVisible,
                        child: HomeScreenFuncButton(
                          btnLabel: 'Watch Feed',
                          iconData: Icons.video_call,
                          callBack: () {
                            try {
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.confirm,
                                title: 'Alert',
                                text: 'Do you want to view the stream on $ip ?',
                                confirmBtnColor: Colors.green,
                                confirmBtnText: 'Yes',
                                cancelBtnText: 'No',
                                onConfirmBtnTap: () async {
                                  Navigator.pop(context);
                                  _watchStream();

                                  DatabaseReference userResponseFieldRef = database
                                      .ref('/poc_pings/sendFeed');
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
                                  DatabaseReference userResponseFieldRef = database
                                      .ref('/poc_pings/sendFeed');

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
                    ],
                  ),
                  SizedBox(height: 30,),
                  if (_connected && isStreamStarted)
                    Container(
                      margin: EdgeInsets.all(0.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 5),
                      ),
                      child: SizedBox(
                        width: 350,
                        height: 250,
                        child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: RTCVideoView(_remoteRenderer)),
                      ),
                    ),
                  SizedBox(height: 30,),

                  Visibility(
                    visible: isStreamStarted,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        HomeScreenFuncButton(
                          btnLabel: 'Unlock',
                          iconData: Icons.door_front_door,
                          callBack: () async {
                              loaderProvider.showLoader();
                            DatabaseReference userResponseFieldRef = database
                                .ref('/poc_pings/unlockDoor');
                            try {
                                await userResponseFieldRef.set(true);
                                print(
                                  'User response updated to true in Firebase at /updates/openDoor',
                                );
                                loaderProvider.hideLoader();
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
                              if (data != null) {
                                print(data);
                                Uint8List uint8List = Uint8List.fromList(data);
                                final tempDir = await getTemporaryDirectory();
                                final file =
                                await File(
                                  '${tempDir.path}/image.jpg',
                                ).create();
                                await file.writeAsBytes(uint8List);
                                final result = await ImageGallerySaverPlus.saveFile(
                                  file.path,
                                );
                                if (result['isSuccess']) {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.success,
                                    title: 'Success',
                                    text: 'Image Saved Successfully',
                                    confirmBtnColor: Colors.green,
                                  );
                                } else {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: "Failed to save the image",
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              } else {
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Oops...',
                                  text: 'No Image to save',
                                  confirmBtnColor: const Color(0xFFE30A17),
                                );
                              }
                            } catch (e) {
                              print('Error: $e');
                            }
                          },
                        ),
                        HomeScreenFuncButton(
                          btnLabel: 'Record',
                          iconData: Icons.emergency_recording,
                          callBack: () {
                            print('Started Recording');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

    );
  }
}
