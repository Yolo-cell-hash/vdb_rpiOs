import 'package:firebase_database/firebase_database.dart';
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
  String _status = 'Disconnected';
  bool _connected = false;
  bool isStreamStarted = false;
  FbUtils fbUtils = FbUtils();
  late JanusWebRTCClient _client;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

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

  Widget build(BuildContext context) {
    String ip = Provider.of<LoaderProvider>(context, listen: false).ip;
    FirebaseDatabase database = fbUtils.database;

    return Column(
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
                    DatabaseReference userResponseFieldRef = database.ref(
                      '/poc_pings/sendFeed',
                    );
                    try {
                      await userResponseFieldRef.set(true);
                      print(
                        'User response updated to true in Firebase at /updates/userResponse',
                      );
                      setState(() {
                        isStreamStarted = true;
                      });
                    } catch (e) {
                      print('Error updating user response to true: $e');
                    }

                    ////------------------------------------ ISSUE WITH INIT CONNECTION
                    // _client = JanusWebRTCClient('ws://[$ip]:8188');
                    // await connectOnPageInit();
                    // await Future.delayed(const Duration(seconds: 2));

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
              height: 250,
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
                  '/poc_pings/addUsers',
                );

                DatabaseReference showFeedField = database.ref(
                  '/poc_pings/sendFeed',
                );

                DatabaseReference confirmClick = database.ref(
                  '/poc_pings/confirm',
                );

                DatabaseReference currentUsers = database.ref(
                  '/poc_pings/currentUsers',
                );

                await userResponseFieldRef.set('$name');
                await showFeedField.set(false);
                await confirmClick.set(true);

                final DataSnapshot snapshot = await currentUsers.get();
                if (snapshot.exists) {
                  var data = snapshot.value.toString();
                  if(data.isNotEmpty && data.contains(name)){
                    loaderProvider.hideLoader();
                    QuickAlert.show(
                      context: context,
                      type: QuickAlertType.success,
                      title: 'Success',
                      text: 'User $name added successfully!',
                      confirmBtnText: 'OK',
                      onConfirmBtnTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    );
                  }else{
                    loaderProvider.hideLoader();
                    QuickAlert.show(
                      context: context,
                      type: QuickAlertType.error,
                      title: 'Error',
                      text: 'User $name could not be added!',
                      confirmBtnText: 'OK',
                      onConfirmBtnTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    );
                  }
                } else {
                  print('No users found in currentUsers.');
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
    );
  }
}
