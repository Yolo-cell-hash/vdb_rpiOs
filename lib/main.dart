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
//
// FIX: This handler is intentionally a no-op for notification display.
//
// The Lambda sends a FCM payload that includes BOTH a `notification` block
// and a `data` block. When a `notification` block is present, Android
// automatically displays the notification in the system tray — even when
// the app is killed — without any Flutter code involved.
//
// Previously, this handler also called `_showNotification()`, which caused
// a second (duplicate) notification to appear on top of the system one.
// Removing that call leaves the system to handle display on its own,
// giving exactly one notification per event in background/killed states.
//
// The `channel_id: vdb_alerts` set in the Lambda's android.notification
// block ensures the system-auto-displayed notification uses the correct
// channel (sound, vibration, importance) that we created in
// `_ensureNotificationChannels()`.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Ensure channels exist so the system-auto-displayed notification
  // can resolve `vdb_alerts` correctly on first launch after a cold start.
  await _ensureNotificationChannels();

  // ✅ Do NOT call _showNotification() here.
  // The FCM `notification` block is already auto-displayed by Android.
  // Calling it would produce a second duplicate notification.
  debugPrint('[BG] Message received — source: ${_extractSourceFromMessageData(message.data)}');
}

// ─── Notification tap handler ───
//
// Called when the user taps a LOCAL notification (shown by _showNotification).
// System FCM notifications (background/killed) are handled via
// onMessageOpenedApp and getInitialMessage instead.
@pragma('vm:entry-point')
void handleNotificationResponse(NotificationResponse response) {
  final payload = response.payload ?? '';
  final notifId = response.id ?? _kForegroundNotifId;

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
/// Supports "source=advantis_iot9" or "device_type=gsld1&other=val"
String? _extractPayloadValue(String payload, String key) {
  final pairs = payload.split('&');
  for (final pair in pairs) {
    final kv = pair.split('=');
    if (kv.length == 2 && kv[0] == key) {
      return kv[1];
    }
  }
  return null;
}

// ─── Fixed notification ID for foreground local notifications ───
//
// Using a constant ID means a new foreground alert replaces the previous
// one rather than stacking. Change to a timestamp-based ID if you want
// multiple simultaneous alerts to coexist.
const int _kForegroundNotifId = 1001;

// ─── Show a local notification (foreground only) ───
//
// FIX: Title and body now prefer the FCM `notification` block fields
// (passed in explicitly by the caller) so the displayed text always
// matches what the cloud sent, rather than falling back to data fields
// which may be absent or differently formatted.
@pragma('vm:entry-point')
Future<void> _showNotification(
    String title,
    String body, {
      String? payload,
      String channelId = 'vdb_alerts',
      String channelName = 'VDB Alerts',
    }) async {
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    importance: Importance.max,
    priority: Priority.high,
    color: const Color(0xFF2196F3),
  );
  final NotificationDetails details = NotificationDetails(android: androidDetails);

  // FIX: Use a fixed ID (_kForegroundNotifId) instead of 0 so this
  // foreground notification does not collide with the ID used by
  // handleNotificationResponse's cancel() call.
  await flutterLocalNotificationsPlugin.show(
    _kForegroundNotifId,
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
      AndroidFlutterLocalNotificationsPlugin>();

  // Primary channel for VDB alert notifications.
  // The Lambda sets `channel_id: vdb_alerts` in android.notification,
  // so system-auto-displayed notifications will use this channel's
  // sound and vibration settings.
  const vdbAlertsChannel = AndroidNotificationChannel(
    'vdb_alerts',
    'VDB Alerts',
    description: 'Notifications for VDB device alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  await androidPlugin?.createNotificationChannel(vdbAlertsChannel);

  // Legacy channel kept for backward compatibility with older payloads.
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

  /// Stores the pending source when the app is launched from killed state
  /// before the navigator context is ready.
  static String? pendingDeviceType;

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

// ─── Navigate to LandingScreen for a given source key ───
void _navigateToLanding(String source) {
  final config = NotificationDeviceMap.lookup(source);
  if (config == null) {
    debugPrint('Unknown source in notification: $source');
    return;
  }

  final ctx = MyApp.navigatorKey.currentContext;
  if (ctx != null) {
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
    // Navigator not ready yet (e.g. app still initialising after cold start).
    // Store for deferred navigation — picked up in _checkForPendingNavigation.
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

    // ─── Foreground messages → show local notification ───
    //
    // FCM does NOT auto-display notifications when the app is in the
    // foreground, so we must show one manually here.
    //
    // FIX: Prefer the `notification` block fields (title/body) from the
    // RemoteMessage directly — these are exactly what the Lambda sent in
    // the FCM `notification` object — rather than digging into `data`.
    // Fall back to `data` fields only if the notification block is absent
    // (i.e. a data-only message).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final source = _extractSourceFromMessageData(message.data);
      final config = NotificationDeviceMap.lookup(source);

      final title = message.notification?.title
          ?? message.data['title']
          ?? (config != null ? 'Alert: ${config.title}' : 'VDB Notification');

      final body = message.notification?.body
          ?? message.data['body']
          ?? (config != null ? 'Tap to view ${config.title}' : 'Tap to open');

      _showNotification(
        title,
        body,
        payload: source != null ? 'source=$source' : null,
        channelId: 'vdb_alerts',
        channelName: 'VDB Alerts',
      );
    });

    // ─── System notification tap — app was in background ───
    //
    // Android auto-displayed the system notification (from the FCM
    // `notification` block). When the user taps it, FCM fires
    // onMessageOpenedApp. No local notification was involved, so we
    // navigate directly without going through handleNotificationResponse.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final source = _extractSourceFromMessageData(message.data);
      if (source != null) {
        _navigateToLanding(source);
      }
    });

    // ─── App launched from a system FCM notification (killed state) ───
    //
    // Same reasoning as onMessageOpenedApp above — system handled display,
    // we just need to navigate to the right screen.
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        final source = _extractSourceFromMessageData(message.data);
        if (source != null) {
          _navigateToLanding(source);
        }
      }
    });

    // ─── App launched from a LOCAL notification tap (foreground notif, killed state) ───
    //
    // This covers the edge case where the user tapped the foreground
    // local notification (shown by onMessage) after the app was killed.
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
    final pendingType = MyApp.pendingDeviceType;
    if (pendingType == null) return;

    final ctx = MyApp.navigatorKey.currentContext;
    if (ctx != null) {
      MyApp.pendingDeviceType = null; // Clear before navigating to avoid re-entry
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
      // Context not ready yet — retry shortly.
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
