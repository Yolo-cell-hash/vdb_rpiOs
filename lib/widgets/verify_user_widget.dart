import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';
import 'package:quickalert/quickalert.dart';
import 'dart:typed_data';


class VerifyUserWidget extends StatefulWidget {
  const VerifyUserWidget({super.key});

  @override
  State<VerifyUserWidget> createState() => _VerifyUserWidgetState();
}

class _VerifyUserWidgetState extends State<VerifyUserWidget> {
  @override

  WebSocketSingleton webSocketSingleton = WebSocketSingleton();
  dynamic data;

  Widget build(BuildContext context) {
    return Center(
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
          // stream: onConfirmClick == false
          //     ? webSocketSingleton.stream
          //     : null,
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
    );
  }
}
