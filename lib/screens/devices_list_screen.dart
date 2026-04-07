import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/screens/landing_screen.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';

import '../utils/loader_provider.dart';

// ─── Color tokens from the HTML design system ───
class _DSColors {
  static const Color primary = Color(0xFF0058BC);
  static const Color surface = Color(0xFFF7F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF414755);
  static const Color outlineVariant = Color(0xFFC1C6D7);
  static const Color outline = Color(0xFF717786);
}

// ─── Device model to keep things DRY ───
class _DeviceEntry {
  final String title;
  final String subtitle;
  final String fbPath;
  final String deviceName;
  final int streamId;
  final String img_path;
  final String log_path;

  const _DeviceEntry({
    required this.title,
    required this.subtitle,
    required this.fbPath,
    required this.deviceName,
    required this.streamId,
    required this.img_path,
    required this.log_path,
  });
}

class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({super.key});

  @override
  State<DevicesListScreen> createState() => _DevicesListScreenState();
}

class _DevicesListScreenState extends State<DevicesListScreen>
    with TickerProviderStateMixin {
  FbUtils fbUtils = FbUtils();

  // Pulse animation for "online" orbs
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ─── Exact same devices & state logic as before ───
  static const List<_DeviceEntry> _devices = [
    _DeviceEntry(
      title: 'Advantis IoT9 VDB',
      subtitle: 'VDB Configured with Advantis IoT9',
      fbPath: 'dev_env',
      deviceName: 'Advantis IoT9',
      streamId: 7,
      img_path: 'images/front_img.png',
      log_path: 'logs',
    ),
    _DeviceEntry(
      title: 'GSLD1 VDB',
      subtitle: 'VDB Configured with Advantis GSLD1',
      fbPath: 'gsld1_vdb_env',
      deviceName: 'Advantis GSLD1',
      streamId: 8,
      img_path: 'images/back_img.png',
      log_path: 'gsld1_vdb_env',
    ),
    _DeviceEntry(
      title: 'VDB Module',
      subtitle: 'Standard VDB Module',
      fbPath: 'standard_vdb_env',
      deviceName: 'Standard VDB',
      streamId: 9,
      img_path: 'images/garage_img.png',
      log_path: 'standard_vdb_env'
    ),
    _DeviceEntry(
      title: 'Dev VDB Module 1',
      subtitle: 'Standard Dev Module',
      fbPath: 'dev_vdb_env1',
      deviceName: 'Dev VDB Module 1',
      streamId: 10,
      img_path: 'images/interior.png',
      log_path: 'dev_vdb_env1'
    ),
    _DeviceEntry(
      title: 'Dev VDB Module 2',
      subtitle: 'Standard Dev Module',
      fbPath: 'dev_vdb_env2',
      deviceName: 'Dev VDB Module 2',
      streamId: 11,
      img_path: 'images/front_img.png',
      log_path: 'dev_vdb_env2'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Exact same logic as the original screen ───
  void _onDeviceTap(_DeviceEntry device) {
    debugPrint('${device.title} Clicked');
    final loader = Provider.of<LoaderProvider>(context, listen: false);
    loader.setDeviceName(device.deviceName);
    loader.setStreamId(device.streamId);
    loader.setFirebasePath(device.fbPath);
    loader.setLogsPath(device.log_path);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LandingScreen(
          title: device.deviceName,
          fb_path: device.fbPath,
          stream_id: device.streamId,
        ),
      ),
    );
  }

  // ─── Gradient colors matching HTML design ───
  static const _playGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0058BC), Color(0xFF3DC2FD)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DSColors.surface,
      body: CustomScrollView(
        slivers: [
          // ─── Top Header ───
          SliverAppBar(
            pinned: true,
            backgroundColor: _DSColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 1,
            shadowColor: Colors.black12,
            toolbarHeight: 64,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _DSColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: _DSColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Godrej VDB',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                    color: _DSColors.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // ─── Hero Section ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label with pulsing orb
                  Row(
                    children: [
                      const Text(
                        'SECURITY NETWORK',
                        style: TextStyle(
                          color: _DSColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _DSColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _DSColors.primary.withValues(
                                      alpha: 0.4 * (1 - (_pulseAnimation.value - 0.95) / 0.05),
                                    ),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Device Selection',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      letterSpacing: -0.5,
                      color: _DSColors.onSurface,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Manage your encrypted security endpoints. Select a node to initialize high-definition telemetry or configure advanced detection protocols.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _DSColors.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ─── Devices List ───
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _DeviceCard(
                    device: _devices[index],
                    onTap: () => _onDeviceTap(_devices[index]),
                    pulseAnimation: _pulseAnimation,
                  ),
                ),
                childCount: _devices.length,
              ),
            ),
          ),

          // ─── Add Device CTA ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _playGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _DSColors.primary.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          // Placeholder — add device flow
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Add Device',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Protocol label ───
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 120),
              child: Center(
                child: Text(
                  'PROTOCOL V4.2.1  |  ENCRYPTED END-TO-END',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: _DSColors.outline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// DEVICE CARD WIDGET
// ═══════════════════════════════════════════════════
class _DeviceCard extends StatefulWidget {
  final _DeviceEntry device;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;

  const _DeviceCard({
    required this.device,
    required this.onTap,
    required this.pulseAnimation,
  });

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: _DSColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _DSColors.outlineVariant.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF191C1E).withValues(alpha: _isPressed ? 0.08 : 0.04),
              blurRadius: _isPressed ? 16 : 32,
              offset: Offset(0, _isPressed ? 2 : -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: Column(
              children: [
                // ─── Image / visual area ───
                Expanded(
                  flex: 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Device image — cover fills the card, no letterbox gaps
                      Positioned.fill(
                        child: Image.asset(
                          widget.device.img_path,
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Gradient overlay from bottom
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Online badge
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: widget.pulseAnimation,
                                builder: (context, _) {
                                  return Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _DSColors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _DSColors.primary.withValues(
                                            alpha: 0.6 *
                                                (1 -
                                                    (widget.pulseAnimation.value -
                                                        0.95) /
                                                        0.05),
                                          ),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    ],
                  ),
                ),

                // ─── Info section ───
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.device.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: _DSColors.onSurface,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.device.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _DSColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}