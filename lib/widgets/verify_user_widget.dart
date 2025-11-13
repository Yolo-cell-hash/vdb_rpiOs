import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'dart:typed_data';
import 'package:vdp_poc_new/utils/janus_webrtc_client.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';

class VerifyUserWidget extends StatefulWidget {
  const VerifyUserWidget({super.key});

  @override
  State<VerifyUserWidget> createState() => _VerifyUserWidgetState();
}

class _VerifyUserWidgetState extends State<VerifyUserWidget> {
  @override
  dynamic data;
  late JanusWebRTCClient _client;
  bool _connected = false;
  late String ip;
  String _status = 'Disconnected';
  FbUtils fbUtils = FbUtils();
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
        FirebaseDatabase database = fbUtils.database;
        DatabaseReference verifyUser = database.ref('/dev_env/verifyUsers');
        await verifyUser.set(true);

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
        _watchStream();
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
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    FirebaseDatabase database = fbUtils.database;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        if (_connected)
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
                child: RTCVideoView(
                  _remoteRenderer,
                  filterQuality: FilterQuality.high,
                  mirror: false,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
        if(_connected)
          GestureDetector(
            onTap: () async{
              loaderProvider.showLoader();

              try{
                DatabaseReference confirm = database.ref('/dev_env/confirm');
                await confirm.set(true);
                DatabaseReference feed = database.ref('/dev_env/sendFeed');
                await feed.set(false);

                DatabaseReference ack = database.ref(
                  '/dev_env/ack',
                );

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

                loaderProvider.hideLoader();
              }catch(e){
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
                'Verify User',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          )
      ],
    );
  }
}
