import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:vdp_poc_new/utils/janus_webrtc_client.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';

class VerifyUserWidget extends StatefulWidget {
  const VerifyUserWidget({super.key});

  @override
  State<VerifyUserWidget> createState() => _VerifyUserWidgetState();
}

class _VerifyUserWidgetState extends State<VerifyUserWidget>
    with SingleTickerProviderStateMixin {
  @override
  dynamic data;
  late JanusWebRTCClient _client;
  bool _connected = false;
  late String ip, fb_path;
  String _status = 'Disconnected';
  FbUtils fbUtils = FbUtils();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  late final AnimationController _scanController;

  // ────────────────────────────────────────────────────────────────────────────
  // Design tokens (mirrors dev.html / UsersScreen style)
  // ────────────────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0058BC);
  static const Color _surface = Color(0xFFF7F9FB);
  static const Color _surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF191C1E);
  static const Color _outline = Color(0xFF717786);
  static const Color _outlineVariant = Color(0xFFC1C6D7);
  static const Color _secondaryContainer = Color(0xFF3DC2FD);
  static const Color _error = Color(0xFFBA1A1A);

  static const LinearGradient _pulseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primary, _secondaryContainer],
  );

  void _watchStream() async {
    final streamId = 7;
    await _client.watchStream(streamId);
    print(
      'Wacth Stream Called ---------------------------------------------------------------',
    );
  }

  double get _progress {
    final s = _status.toLowerCase();
    if (s.contains('success') || s.contains('error')) return 1.0;
    if (s.contains('remote stream') || s.contains('stream started')) return 0.75;
    if (s.contains('watching') || s.contains('preparing')) return 0.65;
    if (_connected) return 0.55;
    if (s.contains('connecting')) return 0.25;
    return 0.15;
  }

  String get _progressLabel => '${(_progress * 100).round()}%';

  Future<void> _stopFeedAndDisconnect({required bool popAfter}) async {
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    final database = fbUtils.database;
    final fbPath = Provider.of<LoaderProvider>(context, listen: false).firebasePath;

    loaderProvider.showLoader();
    try {
      await _client.disconnect();
      final sendFeedRef = database.ref('/$fbPath/sendFeed');
      await sendFeedRef.set(false);
    } catch (e) {
      print('Error during cancel/back cleanup: $e');
    } finally {
      loaderProvider.hideLoader();
    }

    if (popAfter && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> connectOnPageInit() async {
    try {
      await _client.connect();
      await _client.attachToStreamingPlugin();
      // await _client.keepAlive();
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
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _initRenderers();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loaderProvider = Provider.of<LoaderProvider>(
        context,
        listen: false,
      );
      loaderProvider.showLoader();
      try {
        fb_path = Provider.of<LoaderProvider>(context, listen: false).firebasePath;

        FirebaseDatabase database = fbUtils.database;
        DatabaseReference verifyUser = database.ref('/${fb_path}/sendFeed');
        await verifyUser.set(true);

        ip = Provider.of<LoaderProvider>(context, listen: false).ip;

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
        _watchStream();
        loaderProvider.hideLoader();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No connection logic here
  }

  @override
  void dispose() {
    _client.disconnect();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Security Protocol: 08-X',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _primary,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Verification: Facial Scanning',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _onSurface,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primary.withValues(alpha: 0.2), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _onSurface.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_connected)
                    RTCVideoView(
                      _remoteRenderer,
                      filterQuality: FilterQuality.high,
                      mirror: false,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    _buildConnectingPlaceholder(),

                  // Subtle grayscale + opacity like dev.html
                  IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: _connected ? 0.18 : 0.04),
                    ),
                  ),

                  // Concentric rings overlay
                  IgnorePointer(child: CustomPaint(painter: _RingsPainter())),

                  // Scan line overlay (animated)
                  IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final h = constraints.maxHeight;
                        const lineH = 90.0;
                        return AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, _) {
                            final top = (h - lineH) * _scanController.value;
                            return Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: top,
                                  height: lineH,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          _secondaryContainer.withValues(alpha: 0.40),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // LIVE FEED badge
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'LIVE FEED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom-right chip
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _surfaceContainerLowest.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.center_focus_weak_rounded, size: 16, color: _primary),
                            const SizedBox(width: 6),
                            Text(
                              'ALIGNMENT OPTIMAL',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _outline,
                                letterSpacing: 1.0,
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
          ),
        ),
      ),
    );
  }

  Widget _buildConnectingPlaceholder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(_primary.withValues(alpha: 0.9)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Connecting to live feed…',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanning Identity…',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _outline,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _progressLabel,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _primary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      border: Border.all(
                        color: _outlineVariant.withValues(alpha: 0.18),
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _progress.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _pulseGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Opacity(
                      opacity: 0.20,
                      child: Container(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                title: 'Status',
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _pulseGradient,
                  ),
                ),
                value: _connected ? 'Active Search' : 'Initializing',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                title: 'Latency',
                leading: Icon(Icons.speed_rounded, size: 16, color: _primary),
                value: '—',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Widget leading,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _outline,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final database = fbUtils.database;
    final loaderProvider = Provider.of<LoaderProvider>(context, listen: false);
    final fbPath = Provider.of<LoaderProvider>(context, listen: false).firebasePath;

    return Column(
      children: [
        // Primary (Verify User)
        Opacity(
          opacity: _connected ? 1.0 : 0.6,
          child: IgnorePointer(
            ignoring: !_connected,
            child: GestureDetector(
              onTap: () async {
                loaderProvider.showLoader();

                try {
                  // stop the stream first
                  DatabaseReference sendFeed = database.ref('/$fbPath/sendFeed');
                  await sendFeed.set(false);

                  DatabaseReference feed = database.ref('/$fbPath/verifyUsers');
                  await feed.set(true);
                  //
                  DatabaseReference confirmClick = database.ref('/$fbPath/confirm');
                  await confirmClick.set(true);

                  DatabaseReference ack = database.ref('/$fbPath/ack');

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

                  loaderProvider.hideLoader();
                } catch (e) {
                  loaderProvider.hideLoader();
                  print(e);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(top: 22),
                decoration: BoxDecoration(
                  gradient: _pulseGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                width: double.infinity,
                height: 54,
                alignment: Alignment.center,
                child: Text(
                  'Verify User',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary (Cancel)
        GestureDetector(
          onTap: () => _stopFeedAndDisconnect(popAfter: true),
          child: Container(
            decoration: BoxDecoration(
              color: _surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outlineVariant.withValues(alpha: 0.25)),
            ),
            width: double.infinity,
            height: 54,
            alignment: Alignment.center,
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                color: _primary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Keep existing behavior: disconnect + set sendFeed=false on back
          await _stopFeedAndDisconnect(popAfter: false);
        }
      },
      child: Container(
        color: _surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildVideoCard(),
            const SizedBox(height: 24),
            _buildStatusSection(),
            _buildActions(),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = (size.shortestSide * 0.42);

    final pOuter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _VerifyUserWidgetState._primary.withValues(alpha: 0.18);

    final pMid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _VerifyUserWidgetState._secondaryContainer.withValues(alpha: 0.16);

    final pInner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = _VerifyUserWidgetState._primary.withValues(alpha: 0.10);

    canvas.drawCircle(center, maxR, pOuter);
    canvas.drawCircle(center, maxR * 0.92, pMid);
    canvas.drawCircle(center, maxR * 0.86, pInner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
