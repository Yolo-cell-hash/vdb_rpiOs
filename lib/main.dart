import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/screens/home_screen.dart';
import 'package:vdp_poc_new/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:provider/provider.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoaderProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  late Future<FirebaseApp> _initialization;
  FbUtils fbUtils = FbUtils();
  late DatabaseReference _dbRef1;


  Future<void> getToken(String accessToken) async {

    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      try {
        await _dbRef1.set(token);
        print('FCM Token: $token successfully written to database at /poc_pings/fcmDeviceToken');
      } catch (e) {
        print('Error writing FCM token to database: $e');
      }
    } else {
      print('Failed to get FCM token.');
    }
  }

  Future<void> getDatafromDB(Future<FirebaseApp> initialization)async{
    Map<String, dynamic> data = await fbUtils.backgroundListen(initialization);
    print('--------------------------------$data---------------------------------------');

    Provider.of<LoaderProvider>(context, listen: false).setFcmToken(data['fcm_token']);
    Provider.of<LoaderProvider>(context, listen: false).setIp(data['ipv6']);
  }

  @override
  void initState() {
    fbUtils.fbPushNotification();
    fbUtils.getNotifPermission();
    _initialization = Firebase.initializeApp();
    getToken('abcdef');
    getDatafromDB(_initialization);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    FirebaseDatabase database = fbUtils.database;
    _dbRef1 = database.ref("/poc_pings/fcm_token");

    return MaterialApp(
      home: SplashScreen(),
    );
  }
}

