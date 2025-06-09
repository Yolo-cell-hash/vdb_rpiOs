import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:vdp_poc_new/widgets/connected_screen_unlock_card.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/widgets/home_screen_func_button.dart';
import 'package:vdp_poc_new/screens/video_stream_screen.dart';
import 'package:vdp_poc_new/screens/settings_screen.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';
// import 'package:vdp_poc_new/screens/add_users_screen.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
// import 'package:vdp_poc_new/widgets/home_screen_logs_widget.dart';
// import 'package:vdp_poc_new/utils/log_state.dart';
import 'package:intl/intl.dart';
// import 'package:vdp_poc_new/screens/incoming_call_screen.dart';
// import 'package:vdp_poc_new/utils/state_mgmt.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';

class ConnectedScreen extends StatefulWidget {
  const ConnectedScreen({super.key});

  @override
  State<ConnectedScreen> createState() => _ConnectedScreenState();
}

class _ConnectedScreenState extends State<ConnectedScreen> {
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();
  BleUtil bleUtil = BleUtil();
  bool isUnlocked = false;
  String unlockCmd =
      '2eeNc7rXbowymsXQeYllqPx2QjbkyZ+8g4LzSCSym6W+JlSk4AH6vu9LVkr7BHzvJI8dryirJUGjgbeIxO4pxGEX++69abJMkaR8TnJcoN8=';

  bool isSwitchOn = false;
  bool positive = false;
  IconData lockIcon = Icons.lock;
  IconData unlockedIcon = Icons.lock_open_rounded;
  Color lockedIconColor = Colors.red;
  Color unlockedIconColor = Colors.green;
  String statusTag = 'Room is Locked';

  void handleUnlock() async {
    final macAddress = Provider.of<LoaderProvider>(context, listen: false).macAddress;
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    setState(() {
      loaderProvider.showLoader();
    });

    try {
      BluetoothDevice device = BluetoothDevice(remoteId: DeviceIdentifier(macAddress));
      await bleUtil.connectToDevice(macAddress);
      if (await bleUtil.connectToDevice(macAddress)) {
        await bleUtil.sendData(device, 'unlockCmd');
      }

      setState(() {
        lockIcon = Icons.lock_open_rounded;
        lockedIconColor = Colors.green;
        loaderProvider.hideLoader();
        statusTag = 'Room is Unlocked';
      });

      Future.delayed(const Duration(seconds: 7), () async {
        await bleUtil.disconnectFromDevice(macAddress);
        setState(() {
          lockIcon = Icons.lock;
          lockedIconColor = Colors.red;
          statusTag = 'Room is Locked';
        });
      });
    } catch (e) {
      setState(() {
        loaderProvider.hideLoader();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final macAddress = Provider.of<LoaderProvider>(context).macAddress;
    final ip = Provider.of<LoaderProvider>(context).ip;
    final spineer = Provider.of<LoaderProvider>(context).isLoading;
    return SafeArea(
      child: ModalProgressHUD(
        inAsyncCall: spineer,
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
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
            ),
            title: const Text(
              'Your Room',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            centerTitle: true,
          ),
          body: FadeIn(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Main Door',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        child: AnimatedToggleSwitch<bool>.dual(
                          current: positive,
                          first: false,
                          second: true,
                          spacing: 10.0,
                          style: const ToggleStyle(
                            borderColor: Colors.transparent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: Offset(0, 1.5),
                              ),
                            ],
                          ),
                          borderWidth: 5.0,
                          height: 55,
                          onChanged: (b) {
                            setState(() => positive = b);
                            if(webSocketSingleton.channel != null){
                              if(b){
                                try {
                                  webSocketSingleton.channel?.sink
                                      .add('Surveillance Mode Enabled');
                                  print('Sent: Surveillance Mode Enabled');
                                } catch (e) {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: e.toString(),
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              }else {
                                try {
                                  webSocketSingleton.channel?.sink
                                      .add('Surveillance Mode Disabled');
                                  print('Sent: Surveillance Mode Disabled');
                                } catch (e) {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: e.toString(),
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              }
                            } else{
                              webSocketSingleton.connect(ip);
                              if (b) {
                                try {
                                  webSocketSingleton.channel?.sink
                                      .add('Surveillance Mode Enabled');
                                  print('Sent: Surveillance Mode Enabled');
                                } catch (e) {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: e.toString(),
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              } else {
                                try {
                                  webSocketSingleton.channel?.sink
                                      .add('Surveillance Mode Disabled');
                                  print('Sent: Surveillance Mode Disabled');
                                } catch (e) {
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Oops...',
                                    text: e.toString(),
                                    confirmBtnColor: const Color(0xFFE30A17),
                                  );
                                }
                              }
                            }
                          },
                          styleBuilder: (b) => ToggleStyle(
                              indicatorColor: b ? Colors.green : Colors.red),
                          iconBuilder: (value) => value
                              ? const Icon(Icons.video_call_rounded)
                              : const Icon(Icons.lock),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  ConnectedScreenUnlockCard(
                    lockIcon: lockIcon,
                    lockedIconColor: lockedIconColor,
                    statusTag: statusTag,
                    onUnlock: handleUnlock,
                  ),
                  SizedBox(
                    height: 15,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      HomeScreenFuncButton(
                        btnLabel: 'Feed',
                        iconData: Icons.camera_alt_rounded,
                        callBack: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const VideoStreamScreen(),
                            ),
                          );
                        },
                      ),
                      HomeScreenFuncButton(
                        btnLabel: 'Users',
                        iconData: Icons.people_alt_rounded,
                        callBack: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => AddUsersScreen(),
                          //   ),
                          // );
                        },
                      ),
                      HomeScreenFuncButton(
                        btnLabel: 'Logs',
                        iconData: Icons.history,
                        callBack: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => HomeScreenLogsWidget(),
                          //   ),
                          // );
                        },
                      ),
                    ],
                  ),
                  StreamBuilder(
                      stream: webSocketSingleton.stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final data = snapshot.data.toString();
                          if (data.contains("incoming call")) {
                            Future.microtask(() {
                              print('Incoming Call');
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (context) => IncomingCallScreen(),
                              //   ),
                              // );
                            });
                          } else if (data.contains('Access Granted')) {
                            String currentTime = DateFormat('yyyy-MM-dd HH:mm')
                                .format(DateTime.now());
                            // Provider.of<LogState>(context, listen: false)
                            //     .addLog(data.toString(), currentTime, 1);
                          }
                        }
                        return Container();
                      }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
