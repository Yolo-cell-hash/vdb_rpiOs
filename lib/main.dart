import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/utils/notification_device_map.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

String? _extractSourceFromMessageData(Map<String, dynamic> data) {
  final source = data['source'] as String?;
  if (source != null && source.isNotEmpty) return source;
  // Backward compatibility with older payloads.
  final legacy = data['device_type'] as String?;
  return (legacy == null || legacy.isEmpty) ? null : legacy;
}

// ─── Background handler ───
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: handleNotificationResponse,
  );

  // Create both channels
  await _ensureNotificationChannels();

  // Extract source (preferred) from the notification payload
  final source = _extractSourceFromMessageData(message.data);
  final config = NotificationDeviceMap.lookup(source);

  if (config != null) {
    await _showNotification(
      message.data['title'] ?? 'Alert: ${config.title}',
      message.data['body'] ?? 'Tap to view ${config.title}',
      payload: 'source=$source',
      channelId: 'vdb_alerts',
      channelName: 'VDB Alerts',
    );
  } else {
    // Fallback: show generic notification
    await _showNotification(
      message.data['title'] ?? 'VDB Notification',
      message.data['body'] ?? 'Tap to open',
      channelId: 'vdb_alerts',
      channelName: 'VDB Alerts',
    );
  }
}

// ─── Notification tap handler ───
@pragma('vm:entry-point')
void handleNotificationResponse(NotificationResponse response) {
  final payload = response.payload ?? '';
  final notifId = response.id ?? 0;

  // Parse source (preferred) from payload
  final source =
      _extractPayloadValue(payload, 'source') ??
      _extractPayloadValue(payload, 'device_type');
  if (source != null) {
    _navigateToLanding(source);
  }

  flutterLocalNotificationsPlugin.cancel(notifId);
}

/// Extracts a value from a simple key=value payload string.
String? _extractPayloadValue(String payload, String key) {
  // Supports "source=advantis_iot9" or "device_type=gsld1&other=val"
  final pairs = payload.split('&');
  for (final pair in pairs) {
    final kv = pair.split('=');
    if (kv.length == 2 && kv[0] == key) {
      return kv[1];
    }
  }
  return null;
}

// ─── Show a local notification ───
@pragma('vm:entry-point')
Future<void> _showNotification(
    String title,
    String body, {
      String? payload,
      String channelId = 'vdb_alerts',
      String channelName = 'VDB Alerts',
    }) async {
  AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    importance: Importance.max,
    priority: Priority.high,
    color: const Color(0xFF2196F3),
  );
  NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    details,
    payload: payload,
  );
}

// ─── Create notification channels ───
Future<void> _ensureNotificationChannels() async {
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
  >();

  // Primary channel for VDB alert notifications
  const vdbAlertsChannel = AndroidNotificationChannel(
    'vdb_alerts',
    'VDB Alerts',
    description: 'Notifications for VDB device alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  await androidPlugin?.createNotificationChannel(vdbAlertsChannel);

  // Keep legacy stream channel for backward compatibility
  const streamChannel = AndroidNotificationChannel(
    'stream_channel',
    'Stream Notifications',
    description: 'Channel for stream notifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  await androidPlugin?.createNotificationChannel(streamChannel);
}

// ─── Init local notifications (foreground) ───
Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: handleNotificationResponse,
  );

  await _ensureNotificationChannels();
}

// ═══════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initLocalNotifications();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => LoaderProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  /// Stores the pending device_type when the app is launched from killed state.
  static String? pendingDeviceType;

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

// ─── Navigate to LandingScreen for a given device type ───
void _navigateToLanding(String source) {
  final config = NotificationDeviceMap.lookup(source);
  if (config == null) {
    debugPrint('Unknown source in notification: $source');
    return;
  }

  final ctx = MyApp.navigatorKey.currentContext;
  if (ctx != null) {
    // Set LoaderProvider fields so LandingScreen has all the data it needs
    final loader = Provider.of<LoaderProvider>(ctx, listen: false);
    loader.setDeviceName(config.deviceName);
    loader.setStreamId(config.streamId);
    loader.setFirebasePath(config.fbPath);
    loader.setLogsPath(config.logPath);

    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LandingScreen(
          title: config.title,
          fb_path: config.fbPath,
          stream_id: config.streamId,
        ),
      ),
          (route) => false,
    );
  } else {
    // App not ready yet — store for deferred navigation
    MyApp.pendingDeviceType = source;
  }
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final FbUtils fbUtils = FbUtils();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    fbUtils.fbPushNotification();
    fbUtils.getNotifPermission();

    _storeFcmTokenLocally();

    // ─── Foreground data messages → show local notification ───
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final source = _extractSourceFromMessageData(message.data);
      final config = NotificationDeviceMap.lookup(source);

      if (config != null) {
        _showNotification(
          message.data['title'] ?? 'Alert: ${config.title}',
          message.data['body'] ?? 'Tap to view ${config.title}',
          payload: 'source=$source',
          channelId: 'vdb_alerts',
          channelName: 'VDB Alerts',
        );
      } else {
        _showNotification(
          message.data['title'] ?? 'VDB Notification',
          message.data['body'] ?? 'Tap to open',
          channelId: 'vdb_alerts',
          channelName: 'VDB Alerts',
        );
      }
    });

    // ─── System notification tap (app was in background) ───
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final source = _extractSourceFromMessageData(message.data);
      if (source != null) {
        _navigateToLanding(source);
      }
    });

    // ─── Launched from terminated via system FCM notification ───
    FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
        ) {
      if (message != null) {
        final source = _extractSourceFromMessageData(message.data);
        if (source != null) {
          _navigateToLanding(source);
        }
      }
    });

    // ─── Launched from a local notification tap (terminated) ───
    Future.microtask(() async {
      final details =
      await flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
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
    final pendingType = MyApp.pendingDeviceType;
    if (pendingType == null) return;

    final ctx = MyApp.navigatorKey.currentContext;
    if (ctx != null) {
      MyApp.pendingDeviceType = null; // Clear before navigating
      final config = NotificationDeviceMap.lookup(pendingType);
      if (config != null) {
        final loader = Provider.of<LoaderProvider>(ctx, listen: false);
        loader.setDeviceName(config.deviceName);
        loader.setStreamId(config.streamId);
        loader.setFirebasePath(config.fbPath);
        loader.setLogsPath(config.logPath);

        Navigator.of(ctx).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LandingScreen(
              title: config.title,
              fb_path: config.fbPath,
              stream_id: config.streamId,
            ),
          ),
              (route) => false,
        );
      }
    } else {
      // Context not ready yet, retry shortly
      Future.delayed(
        const Duration(milliseconds: 400),
        _checkForPendingNavigation,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _storeFcmTokenLocally() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && mounted) {
      Provider.of<LoaderProvider>(context, listen: false).setFcmToken(token);
    }
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
