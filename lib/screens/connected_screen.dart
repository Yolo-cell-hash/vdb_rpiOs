import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:vdp_poc_new/widgets/connected_screen_unlock_card.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/widgets/home_screen_func_button.dart';
import 'package:vdp_poc_new/screens/video_stream_screen.dart';
import 'package:vdp_poc_new/screens/users_screen.dart';
import 'package:vdp_poc_new/screens/logs_screen.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:vdp_poc_new/utils/web_api_brain.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';

class ConnectedScreen extends StatefulWidget {
  const ConnectedScreen({super.key});

  @override
  State<ConnectedScreen> createState() => _ConnectedScreenState();
}

class _ConnectedScreenState extends State<ConnectedScreen> {
  bool isUnlocked = false;
  bool isSwitchOn = false;
  bool positive = false;
  IconData lockIcon = Icons.lock;
  IconData unlockedIcon = Icons.lock_open_rounded;
  Color lockedIconColor = Colors.red;
  Color unlockedIconColor = Colors.green;
  String statusTag = 'Room is Locked';
  bool survailanceModeEnabled = false;

  WebApi webApi = WebApi();
  FbUtils fbUtils = FbUtils();

  void handleUnlock() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    loaderProvider.showLoader();

    try {
      int value = await webApi.unlockDoor(context);

      if (value == 200) {
        setState(() {
          lockIcon = Icons.lock_open_rounded;
          lockedIconColor = Colors.green;
          loaderProvider.hideLoader();
          statusTag = 'Room is Unlocked';
        });

        Future.delayed(const Duration(seconds: 7), () async {
          setState(() {
            lockIcon = Icons.lock;
            lockedIconColor = Colors.red;
            statusTag = 'Room is Locked';
          });
        });
      } else {
        setState(() {
          lockIcon = Icons.lock;
          lockedIconColor = Colors.red;
          statusTag = 'Room is Locked';
        });
      }
    } catch (e) {
      loaderProvider.hideLoader();
    }
  }

  @override
  void initState() {
    FbUtils fbUtils = FbUtils();

    webApi.getLockList(context);
    fbUtils.readWifiState();
    super.initState();

    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    DatabaseReference survaillanceRef = fbUtils.database.ref(
      '/dev_env/survailanceModeEnabled',
    );
    survaillanceRef
        .once()
        .then((DatabaseEvent event) {
          if (event.snapshot.exists) {
            bool survaillanceEnabled = event.snapshot.value as bool? ?? false;
            setState(() {
              positive = survaillanceEnabled;
            });

            loaderProvider.setSurvailanceMode(survaillanceEnabled);
          }
        })
        .catchError((error) {
          print('Error fetching surveillance mode: $error');
        });
  }

  @override
  Widget build(BuildContext context) {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    FirebaseDatabase database = fbUtils.database;
    final isLoading = Provider.of<LoaderProvider>(context).isLoading;
    return SafeArea(
      child: ModalProgressHUD(
        inAsyncCall: isLoading,
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
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Main Door',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                          onChanged: (b) async {
                            setState(() => positive = b);

                            DatabaseReference survailanceMode = database.ref(
                              '/dev_env/survailanceModeEnabled',
                            );
                            DatabaseReference ack = database.ref(
                              '/dev_env/ack',
                            );

                            try {
                              // Set up listener for acknowledgment first
                              final ackFuture = ack.onValue.skip(1).first;

                              // Then set the value
                              await survailanceMode.set(b);

                              // Wait for the acknowledgment
                              final DatabaseEvent event = await ackFuture;
                              final DataSnapshot snapshot = event.snapshot;

                              // Process the response
                              if (snapshot.exists) {
                                var data = snapshot.value.toString();
                                if (data.isNotEmpty &&
                                    data.contains('Success')) {
                                  loaderProvider.hideLoader();
                                  loaderProvider.setSurvailanceMode(b);
                                } else if (data.isNotEmpty &&
                                    data.contains('Error')) {
                                  loaderProvider.hideLoader();
                                  // Reset state if there was an error
                                  setState(() => positive = !b);
                                  loaderProvider.setSurvailanceMode(!b);
                                  QuickAlert.show(
                                    context: context,
                                    type: QuickAlertType.error,
                                    title: 'Error',
                                    text: data.toString(),
                                    confirmBtnText: 'OK',
                                  );
                                }
                              } else {
                                loaderProvider.hideLoader();
                                // Reset state if no response
                                setState(() => positive = !b);
                                loaderProvider.setSurvailanceMode(!b);
                                QuickAlert.show(
                                  context: context,
                                  type: QuickAlertType.error,
                                  title: 'Error',
                                  text: 'Status not received from server.',
                                  confirmBtnText: 'OK',
                                );
                              }
                            } catch (e) {
                              loaderProvider.hideLoader();
                              // Reset state if exception
                              setState(() => positive = !b);
                              loaderProvider.setSurvailanceMode(!b);
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.error,
                                title: 'Error',
                                text: 'Failed to set surveillance mode. $e',
                                confirmBtnText: 'OK',
                              );
                            }
                          },
                          styleBuilder:
                              (b) => ToggleStyle(
                                indicatorColor: b ? Colors.green : Colors.red,
                              ),
                          iconBuilder:
                              (value) =>
                                  value
                                      ? const Icon(Icons.video_call_rounded)
                                      : const Icon(Icons.lock),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ConnectedScreenUnlockCard(
                    lockIcon: lockIcon,
                    lockedIconColor: lockedIconColor,
                    statusTag: statusTag,
                    onUnlock: handleUnlock,
                  ),
                  SizedBox(height: 15),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UsersScreen(),
                            ),
                          );
                        },
                      ),
                      HomeScreenFuncButton(
                        btnLabel: 'Logs',
                        iconData: Icons.history,
                        callBack: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LogsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
