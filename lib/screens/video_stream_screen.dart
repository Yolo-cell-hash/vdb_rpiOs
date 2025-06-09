import 'dart:io';
import 'dart:typed_data';
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
import 'package:vdp_poc_new/utils/websocket_util.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

class VideoStreamScreen extends StatefulWidget {
  const VideoStreamScreen({super.key});

  @override
  _VideoStreamScreenState createState() => _VideoStreamScreenState();
}

class _VideoStreamScreenState extends State<VideoStreamScreen> {
  dynamic data;
  BleUtil bleUtil = BleUtil();
  final macAddress = 'DC:54:75:C1:9C:52';
  String unlockCmd =
      '2eeNc7rXbowymsXQeYllqPx2QjbkyZ+8g4LzSCSym6W+JlSk4AH6vu9LVkr7BHzvJI8dryirJUGjgbeIxO4pxGEX++69abJMkaR8TnJcoN8=';
  bool isStremVisible = false;
  bool spinner = false;
  String counterValue = '0';
  bool isDisconnectVisible = false;
  bool isConnectVisible = true;
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();

  @override
  void dispose() {
    webSocketSingleton.dispose();
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ip = Provider.of<LoaderProvider>(context).ip;
    return ModalProgressHUD(
      inAsyncCall: spinner,
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
              SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Visibility(
                    visible: isConnectVisible,
                    child: HomeScreenFuncButton(
                      btnLabel: 'Connect',
                      iconData: Icons.wifi,
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
                              webSocketSingleton.dispose();
                              webSocketSingleton.close();
                              if (webSocketSingleton.channel == null) {
                                await webSocketSingleton.connect(ip);
                                webSocketSingleton.channel?.sink
                                    .add('Send Feed');
                                setState(() {
                                  isStremVisible = true;
                                  isDisconnectVisible = true;
                                  isConnectVisible = false;
                                });
                              }
                            },
                            onCancelBtnTap: () {
                              Navigator.pop(context);
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
                  Visibility(
                    visible: isDisconnectVisible,
                    child: HomeScreenFuncButton(
                      btnLabel: 'Disconnect',
                      iconData: Icons.wifi_off,
                      callBack: () {
                        try {
                          QuickAlert.show(
                            context: context,
                            type: QuickAlertType.confirm,
                            title: 'Alert',
                            text: 'Do you want to close the feed ?',
                            confirmBtnColor: Colors.green,
                            confirmBtnText: 'Yes',
                            cancelBtnText: 'No',
                            onConfirmBtnTap: () {
                              Navigator.pop(context);
                              webSocketSingleton.channel?.sink
                                  .add('Close Feed');
                              webSocketSingleton.dispose();
                              webSocketSingleton.close();
                              print('Channel is ${webSocketSingleton.channel}');
                              setState(() {
                                isStremVisible = false;
                                isConnectVisible = true;
                                isDisconnectVisible = false;
                              });
                            },
                            onCancelBtnTap: () {
                              Navigator.pop(context);
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
                  )
                ],
              ),
              SizedBox(
                height: 20,
              ),
              Visibility(
                visible: isStremVisible,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.lightBlueAccent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      border: Border.all(color: Colors.blueAccent),
                    ),
                    child: StreamBuilder(
                      stream: webSocketSingleton.stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          data = snapshot.data;
                          Uint8List uint8List = Uint8List.fromList(data);
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blueAccent),
                            ),
                            child: RepaintBoundary(
                              child: InteractiveViewer(
                                child: Image.memory(
                                  uint8List,
                                  gaplessPlayback: true,
                                  fit: BoxFit.cover, // fit screen
                                ),
                              ),
                            ),
                          );
                        } else {
                          return CircularProgressIndicator(
                            color: Colors.white,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 30.0,
              ),
              Visibility(
                visible: isStremVisible,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    HomeScreenFuncButton(
                      btnLabel: 'Unlock',
                      iconData: Icons.door_front_door,
                      callBack: () async {
                        setState(() {
                          spinner = true;
                        });
                        try {
                          await bleUtil.connectToDevice(macAddress);

                          final device = BluetoothDevice(
                              remoteId: DeviceIdentifier(macAddress));
                          if (await bleUtil.connectToDevice(macAddress)) {
                            await bleUtil.sendData(device, unlockCmd);
                          }

                          setState(() {
                            spinner = false;
                          });

                          Future.delayed(const Duration(seconds: 7), () async {
                            await bleUtil.disconnectFromDevice(macAddress);
                          });
                        } catch (e) {
                          setState(() {
                            spinner = false;
                          });

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
                            final file = await File('${tempDir.path}/image.jpg')
                                .create();
                            await file.writeAsBytes(uint8List);
                            final result =
                            await ImageGallerySaverPlus.saveFile(file.path);
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
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
