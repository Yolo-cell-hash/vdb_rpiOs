import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vdp_poc_new/screens/logs_screen.dart';
import 'package:vdp_poc_new/screens/users_screen.dart';
import 'package:vdp_poc_new/screens/wifi_disconnected_screen.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/janus_webrtc_client.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:vdp_poc_new/utils/web_api_brain.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';
import 'package:vdp_poc_new/widgets/full_screen_video_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════
// Color constants matching the HTML Tailwind theme
// ═══════════════════════════════════════════════════════════════════
const Color _kPrimary = Color(0xFF0058BC);
const Color _kPrimaryLight = Color(0xFF3DC2FD);
const Color _kSurface = Color(0xFFF7F9FB);
const Color _kOnSurface = Color(0xFF191C1E);
const Color _kOutline = Color(0xFF717786);
const Color _kSurfaceContainerLow = Color(0xFFF2F4F6);
const Color _kSurfaceContainerLowest = Color(0xFFFFFFFF);
const Color _kError = Color(0xFFBA1A1A);
const Color _kSecondary = Color(0xFF00668A);
const Color _kGrayText = Color(0xFF44474A);
const Color _kOutlineVariant = Color(0xFFC1C6D7);

class LandingScreen extends StatefulWidget {
  final String? title, fb_path;
  final int? stream_id;
  const LandingScreen({super.key, this.title, this.fb_path, this.stream_id});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();

  // ─── Bottom nav state ───
  int _selectedIndex = 0;

  // ─── Existing utils ───
  FbUtils fbUtils = FbUtils();
  WebApi webApi = WebApi();

  // ─── Wifi check state (PRESERVED) ───
  late bool isWifiConnected;
  bool isCheckingWifi = true;
  bool showSuccessAnimation = false;
  bool showFailureAnimation = false;
  bool _didChangeDependenciesRun = false;
  bool _isSkipped = false;
  bool _isCancelled = false;
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;

  // ─── Unlock state ───
  bool _isUnlocking = false;
  String _unlockStatus = 'Locked';
  IconData _lockIcon = Icons.lock;
  Color _lockIconColor = Colors.red;

  // ─── Recent events from Firestore ───
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _recentLogs = [];
  bool _isLoadingEvents = true;

  // ─── Surveillance mode state (from ConnectedScreen) ───
  bool _surveillanceEnabled = false;
  bool _isSurveillanceLoading = false;

  // ═══════════════════════════════════════════════════════════════════
  // LIVE VIEW — WebRTC embedded state
  // ═══════════════════════════════════════════════════════════════════
  JanusWebRTCClient? _janusClient;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _liveViewConnecting = false;
  bool _liveViewConnected = false;
  bool _liveViewStreamStarted = false;
  String _liveViewStatus = 'Disconnected';
  String? _liveViewError;
  bool _liveViewRenderersInitialized = false;

  // ─── Recording state ───
  bool _lvIsRecording = false;
  int _lvRecordingDuration = 0;
  Timer? _lvRecordingTimer;
  MediaRecorder? _lvMediaRecorder;
  String? _lvRecordedFilePath;
  GlobalKey _lvRepaintBoundaryKey = GlobalKey();

  // ─── Video overlay controls ───
  bool _lvShowControls = false;
  Timer? _lvHideControlsTimer;

  StreamSubscription? _janusMessageSub;
  StreamSubscription? _janusStreamSub;

  // ═════════════════════════════════════════════════════════════════
  // LIFECYCLE (PRESERVED)
  // ═════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.elasticOut),
    );

    _initializeDevice();
  }

  @override
  void dispose() {
    _disposeLiveView();
    webSocketSingleton.close();
    fbUtils.cancelBackgroundListen();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didChangeDependenciesRun && !_isSkipped) {
      checkWifiConnection();
      _didChangeDependenciesRun = true;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // DEVICE BINDING (PRESERVED)
  // ═════════════════════════════════════════════════════════════════

  Future<void> _initializeDevice() async {
    await _checkTokenValidity();
    if (mounted) {
      await _bindToDevice();
    }
    // Fetch lock list so unlock button works
    if (mounted) {
      await webApi.getLockList(context);
    }
    // Load recent events from Firestore
    if (mounted) {
      _loadRecentEvents();
    }
    // Load surveillance mode state from Firebase
    if (mounted) {
      _loadSurveillanceState();
    }
  }

  Future<void> _loadSurveillanceState() async {
    final fbPath = widget.fb_path;
    if (fbPath == null || fbPath.isEmpty) return;

    try {
      final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
      DatabaseReference survaillanceRef = fbUtils.database.ref(
        '/$fbPath/survailanceModeEnabled',
      );

      final DatabaseEvent event = await survaillanceRef.once();
      if (mounted && event.snapshot.exists) {
        bool survaillanceEnabled = event.snapshot.value as bool? ?? false;
        setState(() {
          _surveillanceEnabled = survaillanceEnabled;
        });
        loaderProvider.setSurvailanceMode(survaillanceEnabled);
      }
    } catch (e) {
      print('Error fetching surveillance mode: $e');
    }
  }

  Future<void> _handleSurveillanceToggle(bool newValue) async {
    final fbPath = widget.fb_path;
    if (fbPath == null || fbPath.isEmpty) return;
    if (_isSurveillanceLoading) return; // Prevent double-tap

    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    // Show loading — do NOT update the toggle yet
    setState(() => _isSurveillanceLoading = true);

    FirebaseDatabase database = fbUtils.database;
    DatabaseReference survailanceMode = database.ref(
      '/$fbPath/survailanceModeEnabled',
    );
    DatabaseReference ack = database.ref('/$fbPath/ack');

    try {
      // Set up listener for acknowledgment first
      final ackFuture = ack.onValue.skip(1).first;

      // Then set the value in Firebase
      await survailanceMode.set(newValue);

      // Wait for the acknowledgment
      final DatabaseEvent event = await ackFuture;
      final DataSnapshot snapshot = event.snapshot;

      // Process the response
      if (snapshot.exists) {
        var data = snapshot.value.toString();
        if (data.isNotEmpty && data.contains('Success')) {
          // Only update UI after ack confirms success
          if (mounted) {
            setState(() {
              _surveillanceEnabled = newValue;
              _isSurveillanceLoading = false;
            });
          }
          loaderProvider.setSurvailanceMode(newValue);
        } else if (data.isNotEmpty && data.contains('Error')) {
          if (mounted) {
            setState(() => _isSurveillanceLoading = false);
          }
          loaderProvider.setSurvailanceMode(_surveillanceEnabled);
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Error',
            text: data.toString(),
            confirmBtnText: 'OK',
          );
        } else {
          // Unknown ack value — don't change
          if (mounted) {
            setState(() => _isSurveillanceLoading = false);
          }
        }
      } else {
        if (mounted) {
          setState(() => _isSurveillanceLoading = false);
        }
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: 'Status not received from server.',
          confirmBtnText: 'OK',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSurveillanceLoading = false);
      }
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: 'Failed to set surveillance mode. $e',
        confirmBtnText: 'OK',
      );
    }
  }

  Future<void> _checkTokenValidity() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    if (loaderProvider.accessToken.isEmpty &&
        loaderProvider.refreshToken.isNotEmpty) {
      print('Access token missing, attempting to refresh...');
      await WebApi().useRefreshTokenToGetAccessToken(context);
    } else if (loaderProvider.refreshToken.isEmpty) {
      print('No refresh token - logging out');
      await WebApi.logoutUser(context);
    }
  }

  Future<void> _bindToDevice() async {
    final fbPath = widget.fb_path;
    if (fbPath == null || fbPath.isEmpty) return;

    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firebase_path', fbPath);

    FirebaseDatabase database = fbUtils.database;

    if (loaderProvider.accessToken.isNotEmpty) {
      try {
        await database
            .ref('$fbPath/accessToken')
            .set(loaderProvider.accessToken);
        print('Access token written to $fbPath');
      } catch (e) {
        print('Error writing access token to Firebase: $e');
      }
    }

    if (loaderProvider.refreshToken.isNotEmpty) {
      try {
        await database
            .ref('$fbPath/refresh_token')
            .set(loaderProvider.refreshToken);
        print('Refresh token written to $fbPath');
      } catch (e) {
        print('Error writing refresh token to Firebase: $e');
      }
    }

    if (loaderProvider.fcmToken.isNotEmpty) {
      try {
        await database.ref('$fbPath/fcm_token').set(loaderProvider.fcmToken);
        print('FCM token written to $fbPath');
      } catch (e) {
        print('Error writing FCM token to Firebase: $e');
      }
    }

    try {
      final data = await fbUtils.backgroundListen(
        Future.value(Firebase.app()),
        context,
        fbPath,
      );
      if (mounted && data.isNotEmpty) {
        loaderProvider.setIp(data['ipv6'] ?? '');
        loaderProvider.setWifiState(data['wifi_state'] ?? false);
      }
    } catch (e) {
      print('Error starting background listener: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // WIFI CHECK (PRESERVED — IDENTICAL LOGIC)
  // ═════════════════════════════════════════════════════════════════

  Future<void> checkWifiConnection() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    FirebaseDatabase database = fbUtils.database;
    DatabaseReference wifiState = database.ref('/${widget.fb_path}/wifi_state');

    setState(() {
      isCheckingWifi = true;
      showSuccessAnimation = false;
      showFailureAnimation = false;
      _isCancelled = false;
    });

    try {
      DataSnapshot snapshot = await wifiState.get();

      if (_isCancelled || _isSkipped) {
        print('WiFi check cancelled by user');
        return;
      }

      bool currentWifiState = snapshot.value as bool? ?? false;
      print('Current WiFi state: $currentWifiState');

      if (currentWifiState) {
        await wifiState.set(false);
        print('WiFi state set to false, waiting for device response...');
      }

      bool wifiConnected = false;
      DateTime startTime = DateTime.now();

      while (DateTime.now().difference(startTime).inSeconds < 5) {
        if (_isCancelled || _isSkipped) {
          print('WiFi check cancelled by user during polling');
          return;
        }

        await Future.delayed(const Duration(milliseconds: 500));
        DataSnapshot checkSnapshot = await wifiState.get();
        bool currentState = checkSnapshot.value as bool? ?? false;

        if (currentState == true) {
          wifiConnected = true;
          print('WiFi state changed back to true - Device is connected!');
          break;
        }
      }

      if (_isCancelled || _isSkipped) {
        print('WiFi check cancelled before final steps');
        return;
      }

      loaderProvider.setWifiState(wifiConnected);

      if (!wifiConnected) {
        print('WiFi check timeout - Device did not respond');

        if (mounted && !_isCancelled && !_isSkipped) {
          setState(() {
            showFailureAnimation = true;
          });

          _animationController!.forward();
          await Future.delayed(const Duration(milliseconds: 1500));

          if (mounted && !_isCancelled && !_isSkipped) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WifiDisconnectedScreen(
                  onRetry: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LandingScreen(),
                      ),
                    );
                  },
                  onSkip: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LandingScreen(),
                      ),
                    ).then((_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _isSkipped = true;
                            isCheckingWifi = false;
                            showSuccessAnimation = false;
                            showFailureAnimation = false;
                          });
                        }
                      });
                    });
                  },
                ),
              ),
            );
          }
        }
      } else {
        if (mounted && !_isCancelled && !_isSkipped) {
          setState(() {
            showSuccessAnimation = true;
          });

          _animationController!.forward();
          await Future.delayed(const Duration(milliseconds: 1500));

          if (mounted && !_isCancelled && !_isSkipped) {
            setState(() {
              isCheckingWifi = false;
              showSuccessAnimation = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error occurred in checking wifi state - $e');
      if (_isCancelled || _isSkipped) {
        print('WiFi check cancelled during error handling');
        return;
      }

      loaderProvider.setWifiState(false);
      if (mounted && !_isCancelled && !_isSkipped) {
        setState(() {
          showFailureAnimation = true;
        });

        _animationController!.forward();

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted && !_isCancelled && !_isSkipped) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WifiDisconnectedScreen(
                onRetry: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LandingScreen(),
                    ),
                  );
                },
                onSkip: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LandingScreen(),
                    ),
                  ).then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isSkipped = true;
                          isCheckingWifi = false;
                          showSuccessAnimation = false;
                          showFailureAnimation = false;
                        });
                      }
                    });
                  });
                },
              ),
            ),
          );
        }
      }
    }
  }

  void _skipWifiCheck() {
    setState(() {
      _isSkipped = true;
      _isCancelled = true;
      isCheckingWifi = false;
      showSuccessAnimation = false;
      showFailureAnimation = false;
    });
  }

  // ═════════════════════════════════════════════════════════════════
  // NEW — RECENT EVENTS (Firestore)
  // ═════════════════════════════════════════════════════════════════

  Future<void> _loadRecentEvents() async {
    try {
      final querySnapshot = await _firestore
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      if (mounted) {
        setState(() {
          _recentLogs = querySnapshot.docs
              .where((doc) => doc.id != 'no_of_logs')
              .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'message': data['message '] as String? ?? 'Unknown Activity',
              'timestamp': data['timestamp'] as String? ?? '',
              'image': data['image'],
            };
          }).toList();
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      print('Error loading recent events: $e');
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  String _formatEventTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '--:--';
    try {
      DateTime dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  Uint8List? _decodeEventImage(dynamic imageData) {
    if (imageData == null) return null;
    try {
      // Handle Firestore Blob type
      if (imageData is Blob) {
        return imageData.bytes;
      }
      // Handle base64 String
      if (imageData is String && imageData.isNotEmpty) {
        // Validate base64 first
        String cleaned = imageData.replaceAll(RegExp(r'\s'), '');
        if (cleaned.isEmpty) return null;
        final base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
        if (cleaned.length % 4 != 0 || !base64Pattern.hasMatch(cleaned)) {
          // Try padding it
          while (cleaned.length % 4 != 0) {
            cleaned += '=';
          }
          if (!base64Pattern.hasMatch(cleaned)) return null;
        }
        return base64Decode(cleaned);
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _getEventStatus(String message) {
    if (message.contains('Error')) {
      return {'text': 'CRITICAL', 'color': _kPrimary};
    } else if (message.contains('Success')) {
      return {'text': 'RESOLVED', 'color': _kSecondary};
    } else {
      return {'text': 'INFO', 'color': _kOutline};
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // NEW — UNLOCK HANDLER (from ConnectedScreen)
  // ═════════════════════════════════════════════════════════════════

  void _handleUnlock() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    final fbPath = widget.fb_path;
    if (fbPath == null || fbPath.isEmpty) return;

    setState(() {
      _isUnlocking = true;
    });

    try {
      FirebaseDatabase database = fbUtils.database;
      DatabaseReference unlockRef = database.ref('/$fbPath/unlockDoor');
      await unlockRef.set(true);

      int value = await webApi.unlockDoor(context);

      if (value == 200) {
        setState(() {
          _lockIcon = Icons.lock_open_rounded;
          _lockIconColor = Colors.green;
          _unlockStatus = 'Unlocked';
          _isUnlocking = false;
        });

        Future.delayed(const Duration(seconds: 7), () {
          if (mounted) {
            setState(() {
              _lockIcon = Icons.lock;
              _lockIconColor = Colors.red;
              _unlockStatus = 'Locked';
            });
          }
        });
      } else {
        setState(() {
          _lockIcon = Icons.lock;
          _lockIconColor = Colors.red;
          _unlockStatus = 'Locked';
          _isUnlocking = false;
        });
      }
    } catch (e) {
      loaderProvider.hideLoader();
      setState(() {
        _isUnlocking = false;
      });
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: 'Failed to unlock door',
        confirmBtnColor: Colors.red,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // TAB NAVIGATION
  // ═════════════════════════════════════════════════════════════════

  void _onItemTapped(int index) {
    final previousIndex = _selectedIndex;
    setState(() {
      _selectedIndex = index;
    });

    // Start connection when switching TO Live View tab
    if (index == 1 && previousIndex != 1) {
      _initLiveView();
    }
    // Disconnect when switching AWAY from Live View tab
    if (previousIndex == 1 && index != 1) {
      _disposeLiveView();
    }
  }

  Widget _getTabContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildLiveViewTab();
      case 2:
        return LogsScreen(embedded: true);
      case 3:
        return UsersScreen(embedded: true);
      default:
        return _buildHomeContent();
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // LIVE VIEW — WebRTC Connection Management
  // ═════════════════════════════════════════════════════════════════

  Future<void> _initLiveView() async {
    // Guard: already connecting or connected
    if (_liveViewConnecting || _liveViewConnected) return;

    setState(() {
      _liveViewConnecting = true;
      _liveViewError = null;
      _liveViewStatus = 'Initializing...';
    });

    try {
      // Initialize renderers
      if (!_liveViewRenderersInitialized) {
        await _localRenderer.initialize();
        await _remoteRenderer.initialize();
        _liveViewRenderersInitialized = true;
      }

      final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
      final ip = loaderProvider.ip;
      final streamId = loaderProvider.streamId;
      final fbPath = loaderProvider.firebasePath;

      if (ip.isEmpty) {
        throw Exception('Device IP not available. Please check device connection.');
      }

      // Read IP type from Firebase
      final ipType = (await fbUtils.readIpType(fbPath))?.toString();

      if (!mounted) return;

      if (ipType == null || (ipType != 'IPv4' && ipType != 'IPv6')) {
        throw Exception('IP type could not be determined (got: $ipType)');
      }

      // Build WebSocket URL based on IP type
      final wsUrl = ipType == 'IPv6'
          ? 'ws://[$ip]:8188'
          : 'ws://$ip:8188';

      setState(() => _liveViewStatus = 'Connecting to stream server...');

      _janusClient = JanusWebRTCClient(wsUrl);

      // Listen to status messages
      _janusMessageSub = _janusClient!.messages.listen((message) {
        if (mounted) {
          setState(() => _liveViewStatus = message);
        }
      });

      // Listen to remote stream
      _janusStreamSub = _janusClient!.remoteStream.listen((stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
          });
        }
      });

      // Connect to Janus
      await _janusClient!.connect();
      await _janusClient!.attachToStreamingPlugin();
      await _janusClient!.listStreams();

      if (!mounted) return;

      setState(() {
        _liveViewConnected = true;
        _liveViewConnecting = false;
        _liveViewStatus = 'Connected — tap Watch Feed to start';
      });

      // Auto-watch the stream
      if (streamId != null) {
        await _janusClient!.watchStream(streamId);

        // Set sendFeed to true in Firebase
        final database = fbUtils.database;
        DatabaseReference sendFeedRef = database.ref('/$fbPath/sendFeed');
        try {
          await sendFeedRef.set(true);
        } catch (e) {
          print('Error setting sendFeed: $e');
        }

        if (mounted) {
          setState(() {
            _liveViewStreamStarted = true;
            _liveViewStatus = 'Stream active';
          });
        }
      }
    } catch (e) {
      print('Live View connection error: $e');
      if (mounted) {
        setState(() {
          _liveViewConnecting = false;
          _liveViewConnected = false;
          _liveViewError = e.toString();
          _liveViewStatus = 'Connection failed';
        });
      }
    }
  }

  Future<void> _disposeLiveView() async {
    // Cancel recording if active
    if (_lvIsRecording) {
      _lvRecordingTimer?.cancel();
      try {
        await _lvMediaRecorder?.stop();
      } catch (_) {}
    }

    _janusMessageSub?.cancel();
    _janusMessageSub = null;
    _janusStreamSub?.cancel();
    _janusStreamSub = null;
    _lvHideControlsTimer?.cancel();
    _lvRecordingTimer?.cancel();

    // Set sendFeed to false
    try {
      final fbPath = widget.fb_path ?? Provider.of<LoaderProvider>(context, listen: false).firebasePath;
      if (fbPath.isNotEmpty && _janusClient != null) {
        final database = fbUtils.database;
        DatabaseReference sendFeedRef = database.ref('/$fbPath/sendFeed');
        await sendFeedRef.set(false);
      }
    } catch (e) {
      print('Error resetting sendFeed: $e');
    }

    // Disconnect Janus
    try {
      await _janusClient?.disconnect();
    } catch (e) {
      print('Error disconnecting Janus: $e');
    }
    _janusClient = null;

    // Dispose renderers
    if (_liveViewRenderersInitialized) {
      try {
        _remoteRenderer.srcObject = null;
        await _localRenderer.dispose();
        await _remoteRenderer.dispose();
      } catch (e) {
        print('Error disposing renderers: $e');
      }
      // Re-create renderer objects for potential reuse
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      _liveViewRenderersInitialized = false;
    }

    if (mounted) {
      setState(() {
        _liveViewConnecting = false;
        _liveViewConnected = false;
        _liveViewStreamStarted = false;
        _liveViewError = null;
        _liveViewStatus = 'Disconnected';
        _lvIsRecording = false;
        _lvRecordingDuration = 0;
        _lvMediaRecorder = null;
        _lvRecordedFilePath = null;
        _lvShowControls = false;
      });
    }
  }

  Future<void> _retryLiveView() async {
    await _disposeLiveView();
    // Small delay to let resources clean up
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && _selectedIndex == 1) {
      await _initLiveView();
    }
  }

  // ─── Live View action handlers ───

  void _lvHandleUnlock() async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    final fbPath = widget.fb_path ?? loaderProvider.firebasePath;
    if (fbPath.isEmpty) return;

    setState(() => _isUnlocking = true);

    try {
      FirebaseDatabase database = fbUtils.database;
      DatabaseReference unlockRef = database.ref('/$fbPath/unlockDoor');
      await unlockRef.set(true);
      int value = await webApi.unlockDoor(context);

      if (value == 200) {
        setState(() {
          _lockIcon = Icons.lock_open_rounded;
          _lockIconColor = Colors.green;
          _unlockStatus = 'Unlocked';
          _isUnlocking = false;
        });
        Future.delayed(const Duration(seconds: 7), () {
          if (mounted) {
            setState(() {
              _lockIcon = Icons.lock;
              _lockIconColor = Colors.red;
              _unlockStatus = 'Locked';
            });
          }
        });
      } else {
        setState(() {
          _lockIcon = Icons.lock;
          _lockIconColor = Colors.red;
          _unlockStatus = 'Locked';
          _isUnlocking = false;
        });
      }
    } catch (e) {
      loaderProvider.hideLoader();
      setState(() => _isUnlocking = false);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: 'Failed to unlock door',
        confirmBtnColor: Colors.red,
      );
    }
  }

  Future<void> _lvHandleCapture() async {
    try {
      final GlobalKey repaintBoundaryKey = GlobalKey();
      setState(() => _lvRepaintBoundaryKey = repaintBoundaryKey);
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List imageBytes = byteData!.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'door_capture_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result != null && result['isSuccess']) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: 'Success',
          text: 'Image saved to gallery',
        );
      } else {
        throw Exception('Failed to save image');
      }
    } catch (e) {
      print('Capture error: $e');
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Oops...',
        text: 'Failed to capture image',
        confirmBtnColor: const Color(0xFFE30A17),
      );
    }
  }

  Future<void> _lvHandleRecord() async {
    if (_lvIsRecording) {
      // Stop recording
      try {
        _lvRecordingTimer?.cancel();
        await _lvMediaRecorder?.stop();
        final result = await ImageGallerySaverPlus.saveFile(
          _lvRecordedFilePath!,
          name: 'door_recording_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (result != null && result['isSuccess']) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Success',
            text: 'Video saved to gallery',
          );
        } else {
          throw Exception('Failed to save video');
        }
        setState(() {
          _lvIsRecording = false;
          _lvMediaRecorder = null;
          _lvRecordingDuration = 0;
        });
      } catch (e) {
        print('Error stopping recording: $e');
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Oops...',
          text: 'Failed to save recording',
          confirmBtnColor: const Color(0xFFE30A17),
        );
      }
    } else {
      // Start recording
      try {
        if (_remoteRenderer.srcObject == null) {
          throw Exception('No video stream to record');
        }
        Directory tempDir = await getTemporaryDirectory();
        String tempPath =
            '${tempDir.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
        _lvRecordedFilePath = tempPath;

        _lvMediaRecorder = MediaRecorder();
        final videoTrack = _remoteRenderer.srcObject!.getVideoTracks().first;
        await _lvMediaRecorder!.start(tempPath, videoTrack: videoTrack);

        setState(() {
          _lvIsRecording = true;
          _lvRecordingDuration = 0;
        });

        _lvRecordingTimer = Timer.periodic(
          const Duration(seconds: 1),
          (timer) {
            if (mounted) {
              setState(() => _lvRecordingDuration++);
            }
          },
        );

        QuickAlert.show(
          context: context,
          type: QuickAlertType.info,
          title: 'Recording',
          text: 'Video recording started',
          autoCloseDuration: const Duration(seconds: 2),
        );
      } catch (e) {
        print('Error starting recording: $e');
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Oops...',
          text: 'Failed to start recording',
          confirmBtnColor: const Color(0xFFE30A17),
        );
      }
    }
  }

  String _lvFormatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ═════════════════════════════════════════════════════════════════
  // WIFI CHECKING SCREEN (PRESERVED — IDENTICAL UI)
  // ═════════════════════════════════════════════════════════════════

  Widget _buildWifiCheckingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.lightBlueAccent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'images/gnb_new_logo_.svg',
                  color: Colors.white,
                  height: 120,
                ),
                const SizedBox(height: 50),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: showSuccessAnimation
                      ? ScaleTransition(
                          key: const ValueKey('success'),
                          scale: _scaleAnimation!,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 50,
                            ),
                          ),
                        )
                      : showFailureAnimation
                          ? ScaleTransition(
                              key: const ValueKey('failure'),
                              scale: _scaleAnimation!,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 50,
                                ),
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('loading'),
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 4,
                              ),
                            ),
                ),
                const SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    showSuccessAnimation
                        ? 'Connected Successfully!'
                        : showFailureAnimation
                            ? 'Connection Failed!'
                            : 'Checking Device Connection...',
                    key: ValueKey(
                      '$showSuccessAnimation-$showFailureAnimation',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!showSuccessAnimation && !showFailureAnimation)
                  const Text(
                    'Please wait',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  )
                else if (showFailureAnimation)
                  const Text(
                    'Unable to reach device',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _skipWifiCheck,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // NEW UI — CUSTOM APP BAR
  // ═════════════════════════════════════════════════════════════════

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chevron_left, color: _kGrayText),
              ),
            ),
            const SizedBox(width: 12),
            // Logo
            Text(
              'Godrej VDB',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
                color: _kOnSurface,
              ),
            ),
            const Spacer(),
            // Settings

            const SizedBox(width: 10),
            // Profile avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kPrimaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // NEW UI — HOME TAB CONTENT
  // ═════════════════════════════════════════════════════════════════

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildLiveFeedSection(),
            const SizedBox(height: 16),
            _buildUnlockButton(),
            const SizedBox(height: 28),
            _buildRecentEventsSection(),
            const SizedBox(height: 28),
            _buildQuickControls(),
          ],
        ),
      ),
    );
  }

  // ── Live Feed Image Card ──
  Widget _buildLiveFeedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            // Pulsing orb
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kPrimaryLight],
                ),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Front Door Bell',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ID: FD-2044',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kOutline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Image card
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'images/front_img.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: _kSurfaceContainerLow,
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 48, color: _kOutline),
                      ),
                    );
                  },
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _kOnSurface.withOpacity(0.2),
                        Colors.transparent,
                        _kOnSurface.withOpacity(0.6),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                // LIVE badge + 1080p
                Positioned(
                  top: 16,
                  left: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kError,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '1080p',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Full-width Unlock button ──
  Widget _buildUnlockButton() {
    final bool isUnlocked = _unlockStatus == 'Unlocked';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _isUnlocking ? null : _handleUnlock,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isUnlocked
                    ? [Colors.green.shade600, Colors.green.shade400]
                    : [_kPrimary, _kPrimaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (isUnlocked ? Colors.green : _kPrimary)
                      .withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isUnlocking)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                else
                  Icon(_lockIcon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  _isUnlocking
                      ? 'Unlocking...'
                      : isUnlocked
                          ? 'Door Unlocked'
                          : 'Unlock',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Recent Events Section (from Firestore) ──
  Widget _buildRecentEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Events',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = 2; // Switch to History tab
                });
              },
              child: Text(
                'View History',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isLoadingEvents)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _kPrimary),
            ),
          )
        else if (_recentLogs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.history, size: 40, color: _kOutline.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  'No recent events',
                  style: GoogleFonts.inter(color: _kOutline, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...List.generate(_recentLogs.length, (index) {
            final log = _recentLogs[index];
            return _buildEventCard(log, index == 0);
          }),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> log, bool isLatest) {
    final String message = log['message'] ?? '';
    final String time = _formatEventTime(log['timestamp']);
    final status = _getEventStatus(message);
    final Uint8List? imageBytes = _decodeEventImage(log['image']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: isLatest
            ? const Border(left: BorderSide(color: _kPrimary, width: 4))
            : null,
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kSurfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _kOutlineVariant.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageBytes != null
                ? Image.memory(imageBytes, fit: BoxFit.cover)
                : Container(
                    color: _kPrimary.withOpacity(0.1),
                    child: Icon(
                      Icons.notifications_active,
                      color: _kPrimary,
                      size: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          // Title & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.length > 30
                      ? '${message.substring(0, 30)}...'
                      : message,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _kOnSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Front Door Bell',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _kOutline,
                  ),
                ),
              ],
            ),
          ),
          // Time & status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kOnSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status['text'],
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: status['color'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Controls & Stats ──
  Widget _buildQuickControls() {
    return Column(
      children: [
        // Security State card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
              ),
            ],
            border: Border.all(
                color: _kOutlineVariant.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security State',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              _buildSurveillanceToggle(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Active Perimeter card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, _kPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'ACTIVE PERIMETER',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '0',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 36,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Threats Detected Today',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '100%',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'INTEGRITY',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSurveillanceToggle() {
    return GestureDetector(
      onTap: _isSurveillanceLoading
          ? null
          : () => _handleSurveillanceToggle(!_surveillanceEnabled),
      child: Opacity(
        opacity: _isSurveillanceLoading ? 0.7 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kSurfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _isSurveillanceLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _kPrimary,
                      ),
                    )
                  : Icon(
                      _surveillanceEnabled ? Icons.videocam : Icons.videocam_off,
                      color: _surveillanceEnabled ? Colors.green : _kError,
                      size: 22,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surveillance Mode',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isSurveillanceLoading
                          ? 'Waiting for device...'
                          : _surveillanceEnabled
                              ? 'Active'
                              : 'Inactive',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _isSurveillanceLoading
                            ? _kOutline
                            : _surveillanceEnabled
                                ? Colors.green
                                : _kOutline,
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                ignoring: _isSurveillanceLoading,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _surveillanceEnabled
                        ? Colors.green
                        : const Color(0xFFE0E3E5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: _surveillanceEnabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // LIVE VIEW TAB — Embedded WebRTC stream
  // ═════════════════════════════════════════════════════════════════

  Widget _buildLiveViewTab() {
    // ── State: Connecting (show loading) ──
    if (_liveViewConnecting) {
      return _buildLiveViewLoading();
    }

    // ── State: Error (show retry) ──
    if (_liveViewError != null) {
      return _buildLiveViewError();
    }

    // ── State: Connected with stream ──
    if (_liveViewConnected && _liveViewStreamStarted) {
      return _buildLiveViewStream();
    }

    // ── State: Connected but no stream yet ──
    if (_liveViewConnected) {
      return _buildLiveViewLoading();
    }

    // ── Fallback: Idle / initial ──
    return _buildLiveViewIdle();
  }

  /// Loading / connecting state with animated indicator
  Widget _buildLiveViewLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimary, _kPrimaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _liveViewStatus,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: _kOnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Establishing secure connection...',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _kOutline,
            ),
          ),
        ],
      ),
    );
  }

  /// Error state with retry
  Widget _buildLiveViewError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kError.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off, color: _kError, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Failed',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _kOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _liveViewError ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _kOutline,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Material(
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _retryLiveView,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kPrimaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Retry Connection',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Idle state — should not normally be visible (auto-connects on tab switch)
  Widget _buildLiveViewIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_outlined, size: 64, color: _kOutline.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'Live View',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: _kOnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to initialize camera stream',
            style: GoogleFonts.inter(fontSize: 13, color: _kOutline),
          ),
          const SizedBox(height: 24),
          Material(
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _initLiveView,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPrimary, _kPrimaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Connect',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Active stream view with video feed + action buttons
  Widget _buildLiveViewStream() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ── Header ──
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kPrimary, _kPrimaryLight],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Main Door Camera',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // Disconnect button
              GestureDetector(
                onTap: _disposeLiveView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kError.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop_circle_outlined, color: _kError, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Disconnect',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kError,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Video Feed ──
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Video view
                    GestureDetector(
                      onTap: () {
                        setState(() => _lvShowControls = !_lvShowControls);
                        if (_lvShowControls) {
                          _lvHideControlsTimer?.cancel();
                          _lvHideControlsTimer = Timer(
                            const Duration(milliseconds: 2500),
                            () {
                              if (mounted) {
                                setState(() => _lvShowControls = false);
                              }
                            },
                          );
                        }
                      },
                      child: RepaintBoundary(
                        key: _lvRepaintBoundaryKey,
                        child: RTCVideoView(
                          _remoteRenderer,
                          filterQuality: FilterQuality.high,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: false,
                        ),
                      ),
                    ),
                    // LIVE badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Flash(
                        animate: true,
                        infinite: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kError,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'LIVE',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Recording indicator
                    if (_lvIsRecording)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle, color: Colors.red, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                _lvFormatDuration(_lvRecordingDuration),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Fullscreen control
                    if (_lvShowControls)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 28),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenVideoView(
                                    renderer: _remoteRenderer,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Action Buttons ──
          Row(
            children: [
              Expanded(child: _buildLvActionButton(
                icon: Icons.lock_open_rounded,
                label: 'Unlock Door',
                gradient: _unlockStatus == 'Unlocked'
                    ? [Colors.green.shade600, Colors.green.shade400]
                    : [_kPrimary, _kPrimaryLight],
                isLoading: _isUnlocking,
                onTap: _isUnlocking ? null : _lvHandleUnlock,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildLvActionButton(
                icon: _lvIsRecording ? Icons.stop_rounded : Icons.fiber_manual_record,
                label: _lvIsRecording ? 'Stop' : 'Record',
                gradient: _lvIsRecording
                    ? [_kError, _kError.withOpacity(0.8)]
                    : [_kPrimary, _kPrimaryLight],
                onTap: _lvHandleRecord,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildLvActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Capture',
                gradient: [_kPrimary, _kPrimaryLight],
                onTap: _lvHandleCapture,
              )),
            ],
          ),
          const SizedBox(height: 20),
          // ── Status bar ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _liveViewConnected ? Colors.green : _kOutline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _liveViewStatus,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kGrayText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Styled action button for live view controls
  Widget _buildLvActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // NEW UI — CUSTOM BOTTOM NAV
  // ═════════════════════════════════════════════════════════════════

  Widget _buildCustomBottomNav() {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        boxShadow: [
          BoxShadow(
            color: _kOnSurface.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home, 'Home'),
          _buildNavItem(1, Icons.videocam, 'Live View'),
          _buildNavItem(2, Icons.history, 'History'),
          _buildNavItem(3, Icons.people, 'Users'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 6,
        ),
        decoration: isSelected
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kPrimaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : _kGrayText.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color:
                    isSelected ? Colors.white : _kGrayText.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // BUILD (REWRITTEN)
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (isCheckingWifi) {
      return SafeArea(child: Scaffold(body: _buildWifiCheckingScreen()));
    }

    return Scaffold(
      backgroundColor: _kSurface,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(child: _getTabContent()),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }
}
