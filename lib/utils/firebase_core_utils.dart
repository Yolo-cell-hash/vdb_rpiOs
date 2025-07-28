import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class FbUtils{

  late DatabaseReference _dbRef1;
  StreamSubscription<DatabaseEvent>? _dbSubscription,_dbSubscription1;
  dynamic dbResponse1;
  late FirebaseApp firebaseApp;
  late FirebaseDatabase database;


  FbUtils() {
    firebaseApp = Firebase.app();
    database = FirebaseDatabase.instanceFor(
      app: firebaseApp,
      databaseURL: 'https://vdb-poc-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );
  }

  // Future<void> backgroundListen(Future<FirebaseApp> initialization)async {
  //   initialization.then((firebaseApp) {
  //     // Ensure Firebase is initialized
  //     FirebaseDatabase database = FirebaseDatabase.instanceFor(
  //       app: firebaseApp,
  //       databaseURL:
  //       'https://vdb-poc-default-rtdb.asia-southeast1.firebasedatabase.app/',
  //     );
  //     _dbRef1 = database.ref("poc_pings");
  //
  //     _dbSubscription = _dbRef1.onValue.listen(
  //           (DatabaseEvent event) {
  //             if (event.snapshot.exists) {
  //               dbResponse1 = event.snapshot.value;
  //               print("Data updated: ${event.snapshot.value}");
  //             } else {
  //               dbResponse1 = null;
  //               print("No data at path");
  //             }
  //       },
  //       onError: (error) {
  //         print("Error listening to database: $error");
  //       },
  //     );
  //   });
  // }

  Future<Map<String, dynamic>> backgroundListen(Future<FirebaseApp> initialization) async {
    final completer = Completer<Map<String, dynamic>>();
    initialization.then((firebaseApp) {
      FirebaseDatabase database = FirebaseDatabase.instanceFor(
        app: firebaseApp,
        databaseURL: 'https://vdb-poc-default-rtdb.asia-southeast1.firebasedatabase.app/',
      );
      _dbRef1 = database.ref("poc_pings");

      _dbSubscription = _dbRef1.onValue.listen(
            (DatabaseEvent event) {
          if (event.snapshot.exists) {
            dbResponse1 = event.snapshot.value;
            print("Data updated: ${event.snapshot.value}");
            // Cast to Map<String, dynamic> if possible
            if (dbResponse1 is Map) {
              completer.complete(Map<String, dynamic>.from(dbResponse1));
            } else {
              completer.complete({});
            }
          } else {
            dbResponse1 = null;
            print("No data at path");
            completer.complete({});
          }
        },
        onError: (error) {
          print("Error listening to database: $error");
          completer.completeError(error);
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

  Future<void> getNotifPermission()async{
    var status = await Permission.notification.status;
    if (status.isDenied) {
      Permission.notification.request();
    }
    if (await Permission.location.isRestricted) {
      Permission.notification.request();
    }
  }

}