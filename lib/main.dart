import 'package:firebase_database/firebase_database.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  import 'package:flutter/material.dart';
  import 'package:vdp_poc_new/screens/splash_screen.dart';
  import 'package:provider/provider.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
  import 'package:flutter_local_notifications/flutter_local_notifications.dart';
  import 'package:vdp_poc_new/utils/loader_provider.dart';
  import 'package:vdp_poc_new/screens/video_stream_screen.dart';
  import 'package:vdp_poc_new/screens/connected_screen.dart';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @pragma('vm:entry-point')
  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();

    // Init plugin on background isolate + channel
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'stream_channel',
      'Stream Notifications',
      description: 'Channel for stream notifications',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Decide destination and show a simple notification (no buttons)
    final wantsConnected =
        message.data['route'] == 'connected' || message.data['action'] == 'connected';

    if (wantsConnected) {
      await _showNotification(
        message.data['title'] ?? 'Open Connected',
        message.data['body'] ?? 'Tap to open Connected',
        payload: 'route=connected',
      );
    } else {
      // default to stream page if action is stream_request
      final isStream = message.data['action'] == 'stream_request' || message.data['route'] == 'stream';
      await _showNotification(
        message.data['title'] ?? (isStream ? 'Stream Request' : 'Notification'),
        message.data['body'] ?? (isStream ? 'Tap to view stream' : 'Tap to open'),
        payload: isStream ? 'route=stream' : null,
      );
    }
  }

  @pragma('vm:entry-point')
  void handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    final notifId = response.id ?? 0;

    // Only the default tap exists (no action buttons)
    if (payload.contains('route=connected')) {
      _navigateToConnected();
    } else if (payload.contains('route=stream')) {
      _navigateToStream();
    }

    flutterLocalNotificationsPlugin.cancel(notifId);
  }

  @pragma('vm:entry-point')
  Future<void> _showNotification(
      String title,
      String body, {
        String? payload,
      }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stream_channel',
      'Stream Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF2196F3),
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
    );

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
        child: const MyApp(),
      ),
    );
  }

  class MyApp extends StatefulWidget {
    const MyApp({super.key});

    static bool shouldNavigateToConnected = false;
    static bool shouldNavigateToStream = false;
    static bool wasBackgroundLaunch = false; // Track if notification came from background
    static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    @override
    State<MyApp> createState() => _MyAppState();
  }

  // Helpers to navigate from handlers
  void _navigateToConnected() {
    final ctx = MyApp.navigatorKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ConnectedScreen()),
            (route) => false,
      );
    } else {
      MyApp.shouldNavigateToConnected = true;
    }
  }

  void _navigateToStream() {
    final ctx = MyApp.navigatorKey.currentContext;
    // Check if app is in foreground using WidgetsBinding.instance.lifecycleState
    final isAppForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (ctx != null) {
      if (isAppForeground) {
        // App is in foreground, navigate to VideoStreamScreen
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => const VideoStreamScreen()));
      } else {
        // App is in background, navigate to ConnectedScreen
        Navigator.of(ctx).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ConnectedScreen()),
          (route) => false,
        );
      }
    } else {
      // App is likely terminated or context not available yet
      // We'll use the flag, but we'll determine the actual route when context becomes available
      MyApp.shouldNavigateToStream = true;
      // Store info that this was a background/terminated launch
      MyApp.wasBackgroundLaunch = true;
    }
  }

  class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
    late Future<FirebaseApp> _initialization;
    final FbUtils fbUtils = FbUtils();
    late DatabaseReference _dbRef1;

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addObserver(this);

      _dbRef1 = fbUtils.database.ref("/dev_env/fcm_token");

      fbUtils.fbPushNotification();
      fbUtils.getNotifPermission();

      _initialization = Future.value(Firebase.app());

      getToken('abcdef');
      getDatafromDB(_initialization);

      // Foreground data messages -> show simple local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final wantsConnected =
            message.data['route'] == 'connected' || message.data['action'] == 'connected';

        if (wantsConnected) {
          _showNotification(
            message.data['title'] ?? 'Open Connected',
            message.data['body'] ?? 'Tap to open Connected',
            payload: 'route=connected',
          );
        } else {
          final isStream = message.data['action'] == 'stream_request' || message.data['route'] == 'stream';
          _showNotification(
            message.data['title'] ?? (isStream ? 'Stream Request' : 'Notification'),
            message.data['body'] ?? (isStream ? 'Tap to view stream' : 'Tap to open'),
            payload: isStream ? 'route=stream' : null,
          );
        }
      });

      // System notification tap (if you ever send notification payloads)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data['route'] == 'connected') {
          _navigateToConnected();
        } else if (message.data['route'] == 'stream') {
          _navigateToStream();
        }
      });

      // Launched from terminated via system FCM notification (notification payload)
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          if (message.data['route'] == 'connected') {
            _navigateToConnected();
          } else if (message.data['route'] == 'stream') {
            _navigateToStream();
          }
        }
      });

      // Launched from a local notification tap (terminated)
      Future.microtask(() async {
        final details =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
        if (details?.didNotificationLaunchApp ?? false) {
          final resp = details!.notificationResponse;
          if (resp != null) {
            handleNotificationResponse(resp);
          }
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForPendingNavigation();
      });
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      super.didChangeAppLifecycleState(state);
      if (state == AppLifecycleState.resumed) {
        _checkForPendingNavigation();
      }
    }

    void _checkForPendingNavigation() {
      final ctx = MyApp.navigatorKey.currentContext;

      if (MyApp.shouldNavigateToConnected) {
        MyApp.shouldNavigateToConnected = false;
        if (ctx != null) {
          Navigator.of(ctx).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ConnectedScreen()),
            (route) => false,
          );
        } else {
          Future.delayed(const Duration(milliseconds: 400), _checkForPendingNavigation);
        }
        return;
      }

      if (MyApp.shouldNavigateToStream) {
        MyApp.shouldNavigateToStream = false;
        if (ctx != null) {
          if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed && !MyApp.wasBackgroundLaunch) {
            // App is in foreground, navigate to VideoStreamScreen
            Navigator.of(ctx).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const VideoStreamScreen()),
              (route) => false,
            );
          } else {
            // Navigate to connected screen if app was in background/terminated
            Navigator.of(ctx).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ConnectedScreen()),
              (route) => false,
            );
            MyApp.wasBackgroundLaunch = false; // Reset the flag
          }
        } else {
          Future.delayed(const Duration(milliseconds: 400), _checkForPendingNavigation);
        }
        return;
      }
    }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this);
      super.dispose();
    }

    Future<void> getToken(String accessToken) async {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        try {
          await _dbRef1.set(token);
        } catch (_) {}
      }
    }

    Future<void> getDatafromDB(Future<FirebaseApp> initialization) async {
      final Map<String, dynamic> data = await fbUtils.backgroundListen(initialization);
      Provider.of<LoaderProvider>(context, listen: false).setFcmToken(data['fcm_token']);
      Provider.of<LoaderProvider>(context, listen: false).setIp(data['ipv6']);
    }

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        navigatorKey: MyApp.navigatorKey,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }
  }