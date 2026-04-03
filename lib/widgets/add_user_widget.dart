import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/janus_webrtc_client.dart';

class AddUserWidget extends StatefulWidget {
  const AddUserWidget({super.key});

  @override
  State<AddUserWidget> createState() => _AddUserWidgetState();
}

class _AddUserWidgetState extends State<AddUserWidget> {
  late String name;
  late String ip;
  late int streamId;
  String _status = 'Disconnected';
  bool _connected = false;
  bool isStreamStarted = false;
  FbUtils fbUtils = FbUtils();
  late JanusWebRTCClient _client;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  void _watchStream() async {
    await _client.watchStream(streamId);
    print(
      'Wacth Stream Called -------------------------------------------',
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
        streamId = Provider.of<LoaderProvider>(context,listen: false).streamId;
        _client = JanusWebRTCClient('ws://$ip:8188');
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
    String fb_path = Provider.of<LoaderProvider>(context, listen: false).firebasePath;

    FirebaseDatabase database = fbUtils.database;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
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
      child: Column(
        children: [
          Visibility(
            visible: !isStreamStarted,
            child: TextField(
              onChanged: (value) {
                name = value;
              },
              decoration: InputDecoration(hintText: 'Enter User Name'),
            ),
          ),
          Visibility(
            visible: !isStreamStarted,
            child: GestureDetector(
              onTap: () {
                QuickAlert.show(
                  context: context,
                  type: QuickAlertType.confirm,
                  title: 'Add User',
                  text: 'Are you sure you want to add user with name - $name ?',
                  confirmBtnColor: Colors.green,
                  confirmBtnText: 'Yes',
                  cancelBtnText: 'No',
                  onConfirmBtnTap: () async {
                    final loaderProvider = Provider.of<LoaderProvider>(
                      context,
                      listen: false,
                    );
                    Navigator.pop(context);
                    loaderProvider.showLoader();
                    try {
                      DatabaseReference sendFeedState = database.ref(
                        '/${fb_path}/sendFeed',
                      );
                      try {
                        await sendFeedState.set(true);
                        if (kDebugMode) {
                          print(
                          'User response updated to true in Firebase at /updates/userResponse',
                        );
                        }
                        setState(() {
                          isStreamStarted = true;
                        });
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error updating user response to true: $e');
                        }
                      }
                      _watchStream();
                      loaderProvider.hideLoader();
                    } catch (e) {
                      print(e);
                      loaderProvider.hideLoader();
                    }
                  },
                  onCancelBtnTap: () {
                    Navigator.pop(context);
                  },
                );
              },
              child: Container(
                margin: const EdgeInsets.only(top: 25, bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                child: Text(
                  'Confirm Name',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_connected && isStreamStarted)
            Container(
              margin: EdgeInsets.all(0.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 5),
              ),
              child: SizedBox(
                width: 350,
                height: 275,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: RTCVideoView(_remoteRenderer),
                ),
              ),
            ),

          if (_connected && isStreamStarted)
            GestureDetector(
              onTap: () async {
                final loaderProvider = Provider.of<LoaderProvider>(
                  context,
                  listen: false,
                );
                loaderProvider.showLoader();
                try {
                  DatabaseReference userResponseFieldRef = database.ref(
                    '/${fb_path}/addUsers',
                  );

                  DatabaseReference showFeedField = database.ref(
                    '/${fb_path}/sendFeed',
                  );

                  DatabaseReference confirmClick = database.ref(
                    '/${fb_path}/confirm',
                  );

                  DatabaseReference ack = database.ref(
                    '/${fb_path}/ack',
                  );

                  await userResponseFieldRef.set(name);
                  await showFeedField.set(false);
                  await confirmClick.set(true);

                  final DatabaseEvent event = await ack.onValue.skip(1).first;
                  final DataSnapshot snapshot = event.snapshot;

                  if (snapshot.exists) {
                    var data = snapshot.value.toString();
                    if(data.isNotEmpty && data.contains('Success')){
                      loaderProvider.hideLoader();
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.success,
                        title: 'Success',
                        text: data.toString(),
                        confirmBtnText: 'OK',
                        onConfirmBtnTap: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      );
                    }else if(data.isNotEmpty && data.contains('Error')){
                      loaderProvider.hideLoader();
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.error,
                        title: 'Error',
                        text: data.toString(),
                        confirmBtnText: 'OK',
                        onConfirmBtnTap: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      );
                    }
                  } else {
                    print('No valid ACK received.');
                  }

                  print(
                    'User response updated to true in Firebase at /updates/addUsers',
                  );
                  loaderProvider.hideLoader();

                } catch (e) {
                  loaderProvider.hideLoader();
                  print(e);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(top: 25, bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                child: Text(
                  'Add User',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
