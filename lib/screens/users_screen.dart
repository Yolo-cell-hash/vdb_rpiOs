import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/widgets/config_tiles.dart';
import 'package:intl/intl.dart';
import 'package:vdp_poc_new/widgets/home_screen_func_button.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/widgets/add_user_widget.dart';
import 'package:vdp_poc_new/widgets/delete_user_widget.dart';

import '../widgets/verify_user_widget.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();
  BleUtil bleUtil = BleUtil();
  StreamSubscription? streamSubscription;
  bool addUserClicked = false;
  bool deleteUserClicked = false;
  bool verifyUserClicked = false;
  bool viewUserClicked = false;
  bool showAdd = true;
  bool showDel = true;
  bool showVerify = true;
  bool showView = true;
  bool isStreamSubscribed = false; // to avoid multiple subscriptions

  @override
  void initState() {
    super.initState();
    streamSubscription = webSocketSingleton.stream?.listen((data) {
      // handle data
    });
  }

  @override
  void dispose() {
    streamSubscription?.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final ip = Provider.of<LoaderProvider>(context, listen: false).ip;
    final isLoading = Provider.of<LoaderProvider>(context).isLoading;
    final macAddress =
        Provider.of<LoaderProvider>(context, listen: false).macAddress;
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
              'User Management',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 25.0,
              vertical: 25.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Visibility(
                    visible: showAdd,
                    child: Column(
                      children: [
                        ConfigTiles(
                          tileIcon: Icons.add,
                          title: 'Add Users',
                          subtitle: 'Some subtitle',
                          voidCallbackFunc: () {
                            print('Hello World');
                            setState(() {
                              addUserClicked = !addUserClicked;
                              showDel = !showDel;
                              showView = !showView;
                              showVerify = !showVerify;
                            });

                          },
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: showDel,
                    child: Column(
                      children: [
                        ConfigTiles(
                          tileIcon: Icons.delete,
                          title: 'Delete Users',
                          subtitle: 'Some subtitle',
                          voidCallbackFunc: () {
                            setState(() {
                              deleteUserClicked = !deleteUserClicked;
                              showView = !showView;
                              showVerify = !showVerify;
                              showAdd = !showAdd;
                            });
                          },
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: showVerify,
                    child: Column(
                      children: [
                        ConfigTiles(
                          tileIcon: Icons.remove_red_eye_rounded,
                          title: 'Verify Users',
                          subtitle: 'Some subtitle',
                          voidCallbackFunc: () {
                            setState(() {
                              showAdd = !showAdd;
                              showView = !showView;
                              showDel = !showDel;
                              verifyUserClicked = !verifyUserClicked;
                            });
                          },
                        ),
                        SizedBox(height: 20.0),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: showView,
                    child: Column(
                      children: [
                        ConfigTiles(
                          tileIcon: Icons.people_alt,
                          title: 'View Users',
                          subtitle: 'Some subtitle',
                          voidCallbackFunc: () {
                            setState(() {
                              showVerify = !showVerify;
                              showDel = !showDel;
                              showAdd = !showAdd;
                              viewUserClicked = !viewUserClicked;
                            });
                            if (webSocketSingleton.channel != null) {
                              print('Sent: View Users');
                            } else {
                              print('Channel is not connected');
                            }
                          },
                        ),
                        SizedBox(height: 20.0),
                      ],
                    ),
                  ),
                  Visibility(visible: addUserClicked, child: AddUserWidget()),
                  Visibility(visible: deleteUserClicked, child: DeleteUserWidget()),
                  Visibility(visible: verifyUserClicked, child: VerifyUserWidget()),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
