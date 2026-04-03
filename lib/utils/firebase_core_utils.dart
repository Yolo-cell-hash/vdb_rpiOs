import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'loader_provider.dart';

class FbUtils {
  late DatabaseReference _dbRef1;
  StreamSubscription<DatabaseEvent>? _dbSubscription, _dbSubscription1;
  dynamic dbResponse1;
  late FirebaseApp firebaseApp;
  late FirebaseDatabase database;
  late String ipType;
  late bool wifiState;


  FbUtils() {
    firebaseApp = Firebase.app();
    database = FirebaseDatabase.instanceFor(
      app: firebaseApp,
      databaseURL:
          'https://vdb-poc-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );
  }

  // C:/Users/jayrk/AndroidStudioProjects/vdp_poc_new/lib/utils/firebase_core_utils.dart

  Future<Map<String, dynamic>> backgroundListen(
      Future<FirebaseApp> initialization, BuildContext context, String fbPath,
      ) async {
    final completer = Completer<Map<String, dynamic>>();
    initialization.then((firebaseApp) {
      FirebaseDatabase database = FirebaseDatabase.instanceFor(
        app: firebaseApp,
        databaseURL:
        'https://vdb-poc-default-rtdb.asia-southeast1.firebasedatabase.app/',
      );
      _dbRef1 = database.ref(fbPath);

      _dbSubscription = _dbRef1.onValue.listen(
            (DatabaseEvent event) {
          if (event.snapshot.exists) {
            dbResponse1 = event.snapshot.value;
            final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
            if (dbResponse1 is Map) {
              loaderProvider.setWifiState(dbResponse1['wifi_state']);
            }

            print("Data updated: ${event.snapshot.value}");

            if (!completer.isCompleted) {
              if (dbResponse1 is Map) {
                completer.complete(Map<String, dynamic>.from(dbResponse1));
              } else {
                completer.complete({});
              }
            }
          } else {
            dbResponse1 = null;
            print("No data at path");
            if (!completer.isCompleted) {
              completer.complete({});
            }
          }
        },
        onError: (error) {
          print("Error listening to database: $error");
          // And check here
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
    });
    return completer.future;
  }

  Future<void> handler(RemoteMessage message) async {
    print('Title : ${message.notification!.title}');
    print('Title : ${message.notification!.body}');
  }

  Future<void> fbPushNotification() async {
    final firebaseMessaging = FirebaseMessaging.instance;
    await firebaseMessaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage(handler);
  }

  Future<String?> readIpType(String fbPath) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref('$fbPath/ip_type');
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        ipType = snapshot.value as String;
        return ipType;
      }
      return null;
    } catch (e) {
      print("Error reading IP Type: $e");
      return null;
    }
  }

  Future<bool> readWifiState(String fbPath) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref('$fbPath/wifi_state');
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        wifiState = snapshot.value as bool;
        print('Wifi State - $wifiState');
        return wifiState;
      }else{
        print('Wifi State - $wifiState');
        return false;
      }
    } catch (e) {
      print("Error reading WiFi State - $e");
      return false;
    }
  }

  Future<void> getNotifPermission() async {
    var status = await Permission.notification.status;
    if (status.isDenied) {
      Permission.notification.request();
    }
    if (await Permission.location.isRestricted) {
      Permission.notification.request();
    }
  }

  /// Cancel the background database subscription.
  void cancelBackgroundListen() {
    _dbSubscription?.cancel();
    _dbSubscription = null;
  }
}
