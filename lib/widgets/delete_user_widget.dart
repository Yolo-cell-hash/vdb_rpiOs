import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';
import 'package:quickalert/quickalert.dart';


class DeleteUserWidget extends StatefulWidget {
  const DeleteUserWidget({super.key});

  @override
  State<DeleteUserWidget> createState() => _DeleteUserWidgetState();
}

class _DeleteUserWidgetState extends State<DeleteUserWidget> {
  @override

  late String name;
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();

  Widget build(BuildContext context) {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    final streamState = Provider.of<LoaderProvider>(context);

    return Column(
      children: [
        TextField(
          onChanged: (value) {
            name = value;
          },
          decoration: InputDecoration(
            hintText: 'Enter User Name',
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              loaderProvider.showLoader();
            });
            try {
              if (webSocketSingleton.channel != null) {
                webSocketSingleton.channel?.sink
                    .add('Deleted User - $name');
                print('Sent: Delete User $name');
              } else {
                print('Channel is not connected');
              }

              if (!streamState.isStreamSubscribed) {
                streamState.setStreamSubscribed(true);
                webSocketSingleton.stream?.listen((data) {
                  // print('Received: $data');

                  if (data.toString().contains(''
                      ''
                      'User $name deleted successfully')) {
                    setState(() {
                      loaderProvider.hideLoader();

                      String currentTime =
                      DateFormat('yyyy-MM-dd HH:mm')
                          .format(DateTime.now());
                      // Provider.of<LogState>(context,
                      //     listen: false)
                      //     .addLog(
                      //     'User $name deleted successfully',
                      //     currentTime,
                      //     2);

                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.success,
                        title: 'User Deleted',
                        text: 'User $name deleted successfully',
                        confirmBtnColor: Colors.green,
                      );
                    });
                  } else {
                    setState(() {
                      loaderProvider.hideLoader();
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.error,
                        title: 'Error',
                        text: 'User not found',
                        confirmBtnColor:
                        const Color(0xFFE30A17),
                      );
                    });
                  }
                });
              }
            } catch (e) {
              QuickAlert.show(
                context: context,
                type: QuickAlertType.success,
                title: 'User Deleted',
                text: e.toString(),
                confirmBtnColor: const Color(0xFFE30A17),
              );
            }
          },
          child: Container(
            width: double.infinity,
            height: 50,
            margin: const EdgeInsets.only(top: 25, bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              'Delete User',
              style:
              TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
