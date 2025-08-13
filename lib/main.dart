import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vdp_poc_new/screens/video_stream_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.data}');

  // Initialize notifications with response handler for background
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: handleNotificationResponse,
  );

  // Create notification channel for background
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'stream_channel',
    'Stream Notifications',
    description: 'Channel for stream notifications',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Show notification with actions
  if (message.data['action'] == 'stream_request') {
    await _showActionNotification(
        message.data['title'] ?? 'Stream Request',
        message.data['body'] ?? 'Accept to view stream'
    );
  }
}

@pragma('vm:entry-point')
void handleNotificationResponse(NotificationResponse response) {
  print('=== NOTIFICATION RESPONSE HANDLER ===');
  print('Action ID: ${response.actionId}');
  print('Notification ID: ${response.id}');

  if (response.actionId == 'ACCEPT') {
    print('ACCEPT button clicked - Setting flags');
    MyApp.streamAccepted = true;
    MyApp.shouldNavigateToStream = true;

    // Try immediate navigation
    final context = MyApp.navigatorKey.currentContext;
    if (context != null) {
      print('Navigating immediately to VideoStreamScreen');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const VideoStreamScreen(),
        ),

            (route) => false,
      );
    } else {
      print('Context not available, will navigate when app resumes');
    }

    // Cancel notification
    flutterLocalNotificationsPlugin.cancel(0);

  } else if (response.actionId == 'DECLINE') {
    print('DECLINE button clicked');
    flutterLocalNotificationsPlugin.cancel(0);
  }
}

@pragma('vm:entry-point')
Future<void> _showActionNotification(String title, String body) async {
  print('Creating notification with actions: $title - $body');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'stream_channel',
    'Stream Notifications',
    importance: Importance.max,
    priority: Priority.high,
    color: Color(0xFF2196F3),
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction('ACCEPT', 'Accept', titleColor: Color(0xFF4CAF50)),
      AndroidNotificationAction('DECLINE', 'Decline', titleColor: Color(0xFFE53E3E)),
    ],
  );
  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    details,
  );

  print('Notification with actions shown successfully');
}

Future<void> _initLocalNotifications() async {
  print('Initializing local notifications...');

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  bool? initialized = await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: handleNotificationResponse,
  );

  print('Local notifications initialized: $initialized');

  // Create notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'stream_channel',
    'Stream Notifications',
    description: 'Channel for stream notifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  print('Notification channel created');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initLocalNotifications();

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

  static bool streamAccepted = false;
  static bool shouldNavigateToStream = false;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late Future<FirebaseApp> _initialization;
  FbUtils fbUtils = FbUtils();
  late DatabaseReference _dbRef1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    fbUtils.fbPushNotification();
    fbUtils.getNotifPermission();
    _initialization = Firebase.initializeApp();
    getToken('abcdef');
    getDatafromDB(_initialization);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.data}');
      if (message.data['action'] == 'stream_request') {
        _showActionNotification(
            message.data['title'] ?? 'Stream Request',
            message.data['body'] ?? 'Accept to view stream'
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPendingNavigation();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App lifecycle state changed to: $state');
    if (state == AppLifecycleState.resumed) {
      print('App resumed - checking for pending navigation');
      _checkForPendingNavigation();
    }
  }

  void _checkForPendingNavigation() {
    print('Checking for pending navigation: ${MyApp.shouldNavigateToStream}');
    if (MyApp.shouldNavigateToStream) {
      MyApp.shouldNavigateToStream = false;
      final context = MyApp.navigatorKey.currentContext;
      if (context != null) {
        print('Navigating to VideoStreamScreen');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const VideoStreamScreen(),
          ),
              (route) => false,
        );
      } else {
        print('Context still null, will retry in 500ms');
        Future.delayed(Duration(milliseconds: 500), () {
          _checkForPendingNavigation();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> getToken(String accessToken) async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      try {
        await _dbRef1.set(token);
        print('FCM Token: $token successfully written to database');
      } catch (e) {
        print('Error writing FCM token to database: $e');
      }
    }
  }

  Future<void> getDatafromDB(Future<FirebaseApp> initialization) async {
    Map<String, dynamic> data = await fbUtils.backgroundListen(initialization);
    Provider.of<LoaderProvider>(context, listen: false).setFcmToken(data['fcm_token']);
    Provider.of<LoaderProvider>(context, listen: false).setIp(data['ipv6']);
  }

  @override
  Widget build(BuildContext context) {
    FirebaseDatabase database = fbUtils.database;
    _dbRef1 = database.ref("/poc_pings/fcm_token");

    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}