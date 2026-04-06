import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/janus_webrtc_client.dart';

// ═══════════════════════════════════════════════════════════════════
// Design System Color Tokens (consistent with users_screen.dart)
// ═══════════════════════════════════════════════════════════════════
class _C {
  static const Color primary = Color(0xFF0058BC);
  static const Color surface = Color(0xFFF7F9FB);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color outline = Color(0xFF717786);
  static const Color outlineVariant = Color(0xFFC1C6D7);
  static const Color error = Color(0xFFBA1A1A);
  static const Color secondary = Color(0xFF00668A);
  static const Color secondaryContainer = Color(0xFF3DC2FD);
}

const _pulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0058BC), Color(0xFF3DC2FD)],
);

class AddUserWidget extends StatefulWidget {
  const AddUserWidget({super.key});

  @override
  State<AddUserWidget> createState() => _AddUserWidgetState();
}

class _AddUserWidgetState extends State<AddUserWidget>
    with SingleTickerProviderStateMixin {
  late String name;
  late String ip;
  late int streamId;
  String _status = 'Disconnected';
  bool _connected = false;
  bool isStreamStarted = false;
  FbUtils fbUtils = FbUtils();
  late JanusWebRTCClient _client;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late AnimationController _scanLineController;

  void _watchStream() async {
    await _client.watchStream(streamId);
    print('Watch Stream Called -------------------------------------------');
  }

  Future<void> connectOnPageInit() async {
    try {
      await _client.connect();
      await _client.attachToStreamingPlugin();
      setState(() {
        _connected = true;
        _status = 'Connected to Janus Streaming';
      });
      await _client.listStreams();
    } catch (e) {
      print(e);
      setState(() {
        _status = 'Connection failed: $e';
      });
    }
  }

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loaderProvider = Provider.of<LoaderProvider>(
        context,
        listen: false,
      );
      loaderProvider.showLoader();
      try {
        ip = Provider.of<LoaderProvider>(context, listen: false).ip;
        streamId = Provider.of<LoaderProvider>(context, listen: false).streamId;
        _client = JanusWebRTCClient('ws://$ip:8188');
        await connectOnPageInit();
        _client.messages.listen((message) {
          setState(() {
            _status = message;
          });
        });
        _client.remoteStream.listen((stream) {
          _remoteRenderer.srcObject = stream;
        });
      } finally {
        loaderProvider.hideLoader();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _client.disconnect();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String fb_path =
        Provider.of<LoaderProvider>(context, listen: false).firebasePath;
    FirebaseDatabase database = fbUtils.database;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        final loaderProvider = Provider.of<LoaderProvider>(
          context,
          listen: false,
        );
        if (didPop) {
          loaderProvider.showLoader();
          await _client.disconnect();
          DatabaseReference userResponseFieldRef = database.ref(
            '/$fb_path/sendFeed',
          );
          try {
            await userResponseFieldRef.set(false);
            loaderProvider.hideLoader();
          } catch (e) {
            print('Error updating user response to false: $e');
            loaderProvider.hideLoader();
          }
        }
      },
      child: Column(
        children: [
          // ── Name input phase ──
          if (!isStreamStarted) ...[
            // Instructions header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
              child: Column(
                children: [
                  Text(
                    'Register New User',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _C.onSurface,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the user\'s name below and confirm to start biometric capture.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _C.outline,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Name text field
            Container(
              decoration: BoxDecoration(
                color: _C.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _C.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: TextField(
                onChanged: (value) {
                  name = value;
                },
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: _C.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter User Name',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16,
                    color: _C.outline.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: _C.primary,
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Confirm Name button
            GestureDetector(
              onTap: () {
                QuickAlert.show(
                  context: context,
                  type: QuickAlertType.confirm,
                  title: 'Add User',
                  text: 'Are you sure you want to add user with name - $name ?',
                  confirmBtnColor: Colors.green,
                  confirmBtnText: 'Yes',
                  cancelBtnText: 'No',
                  onConfirmBtnTap: () async {
                    final loaderProvider = Provider.of<LoaderProvider>(
                      context,
                      listen: false,
                    );
                    Navigator.pop(context);
                    loaderProvider.showLoader();
                    try {
                      DatabaseReference sendFeedState = database.ref(
                        '/$fb_path/sendFeed',
                      );
                      try {
                        await sendFeedState.set(true);
                        if (kDebugMode) {
                          print(
                            'User response updated to true in Firebase at /updates/userResponse',
                          );
                        }
                        setState(() {
                          isStreamStarted = true;
                        });
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error updating user response to true: $e');
                        }
                      }
                      _watchStream();
                      loaderProvider.hideLoader();
                    } catch (e) {
                      print(e);
                      loaderProvider.hideLoader();
                    }
                  },
                  onCancelBtnTap: () {
                    Navigator.pop(context);
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: _pulseGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _C.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                child: Text(
                  'Confirm Name',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],

          // ── Stream / biometric capture phase ──
          if (_connected && isStreamStarted) ...[
            // Instruction header
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Text(
                    'Center your face in the frame',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _C.onSurface,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Position your head within the circle and follow the on-screen instructions for biometric verification.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _C.outline,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Circular camera preview with decorative rings & brackets
            Center(
              child: SizedBox(
                width: 288,
                height: 288,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer decorative ring
                    Container(
                      width: 288,
                      height: 288,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _C.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    // Inner decorative ring
                    Container(
                      width: 256,
                      height: 256,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _C.primary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                    // Camera preview (circular)
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.primary, width: 4),
                        color: _C.surfaceContainerLowest,
                      ),
                      child: ClipOval(
                        child: RTCVideoView(
                          _remoteRenderer,
                          objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                    // Animated scan line
                    AnimatedBuilder(
                      animation: _scanLineController,
                      builder: (context, child) {
                        return Positioned(
                          top: 24 + (_scanLineController.value * 240),
                          left: 24,
                          right: 24,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: _C.primary.withValues(alpha: 0.6),
                              boxShadow: [
                                BoxShadow(
                                  color: _C.primary.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Corner brackets
                    // Top-left
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: _C.primary, width: 4),
                            left: BorderSide(color: _C.primary, width: 4),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    // Top-right
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: _C.primary, width: 4),
                            right: BorderSide(color: _C.primary, width: 4),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    // Bottom-left
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _C.primary, width: 4),
                            left: BorderSide(color: _C.primary, width: 4),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    // Bottom-right
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _C.primary, width: 4),
                            right: BorderSide(color: _C.primary, width: 4),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Status / scanning info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanning...',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _C.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep still, detecting features',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _C.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Info tip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _C.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: _C.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ensure you are in a well-lit environment',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _C.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Add User button
            GestureDetector(
              onTap: () async {
                final loaderProvider = Provider.of<LoaderProvider>(
                  context,
                  listen: false,
                );
                loaderProvider.showLoader();
                try {
                  DatabaseReference userResponseFieldRef = database.ref(
                    '/$fb_path/addUsers',
                  );

                  DatabaseReference showFeedField = database.ref(
                    '/$fb_path/sendFeed',
                  );

                  DatabaseReference confirmClick = database.ref(
                    '/$fb_path/confirm',
                  );

                  DatabaseReference ack = database.ref('/$fb_path/ack');

                  await userResponseFieldRef.set(name);
                  await showFeedField.set(false);
                  await confirmClick.set(true);

                  final DatabaseEvent event = await ack.onValue.skip(1).first;
                  final DataSnapshot snapshot = event.snapshot;

                  if (snapshot.exists) {
                    var data = snapshot.value.toString();
                    if (data.isNotEmpty && data.contains('Success')) {
                      loaderProvider.hideLoader();
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.success,
                        title: 'Success',
                        text: data.toString(),
                        confirmBtnText: 'OK',
                        onConfirmBtnTap: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      );
                    } else if (data.isNotEmpty && data.contains('Error')) {
                      loaderProvider.hideLoader();
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.error,
                        title: 'Error',
                        text: data.toString(),
                        confirmBtnText: 'OK',
                        onConfirmBtnTap: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      );
                    }
                  } else {
                    print('No valid ACK received.');
                  }

                  print(
                    'User response updated to true in Firebase at /updates/addUsers',
                  );
                  loaderProvider.hideLoader();
                } catch (e) {
                  loaderProvider.hideLoader();
                  print(e);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: _pulseGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _C.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                child: Text(
                  'Add User',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
