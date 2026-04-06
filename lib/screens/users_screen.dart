import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vdp_poc_new/utils/ble_util.dart';
import 'package:vdp_poc_new/utils/websocket_util.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:provider/provider.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:vdp_poc_new/widgets/add_user_widget.dart';
import 'package:vdp_poc_new/widgets/delete_user_widget.dart';
import 'package:vdp_poc_new/widgets/view_users_widget.dart';
import 'package:vdp_poc_new/widgets/verify_user_widget.dart';

// ═══════════════════════════════════════════════════════════════════
// Design System Color Tokens (from HTML Tailwind config)
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

// ═══════════════════════════════════════════════════════════════════
// Gradient helpers
// ═══════════════════════════════════════════════════════════════════
const _pulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0058BC), Color(0xFF3DC2FD)],
);

// ═══════════════════════════════════════════════════════════════════
// Management card data model
// ═══════════════════════════════════════════════════════════════════
class _MgmtCard {
  final String title;
  final String desc;
  final IconData icon;
  final Color accentColor;
  final Color iconColor;

  const _MgmtCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.accentColor,
    required this.iconColor,
  });
}

const List<_MgmtCard> _mgmtCards = [
  _MgmtCard(
    title: 'Add Users',
    desc: 'Provision new credentials and assign role-based access controls.',
    icon: Icons.person_add_rounded,
    accentColor: _C.primary,
    iconColor: _C.primary,
  ),
  _MgmtCard(
    title: 'Delete Users',
    desc: 'Revoke access privileges and purge expired identity profiles.',
    icon: Icons.person_remove_rounded,
    accentColor: _C.error,
    iconColor: _C.error,
  ),
  _MgmtCard(
    title: 'Verify Users',
    desc: 'Audit biometric signatures and multi-factor authentication.',
    icon: Icons.verified_user_rounded,
    accentColor: _C.secondaryContainer,
    iconColor: _C.secondary,
  ),
  _MgmtCard(
    title: 'View Users',
    desc: 'Comprehensive directory of all system participants.',
    icon: Icons.group_rounded,
    accentColor: _C.primary,
    iconColor: _C.primary,
  ),
];

class UsersScreen extends StatefulWidget {
  final bool embedded;
  const UsersScreen({super.key, this.embedded = false});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  WebSocketSingleton webSocketSingleton = WebSocketSingleton();
  BleUtil bleUtil = BleUtil();
  StreamSubscription? streamSubscription;
  bool isStreamSubscribed = false;

  @override
  void initState() {
    super.initState();
    streamSubscription = webSocketSingleton.stream?.listen((data) {
      // handle data
    });
  }

  @override
  void dispose() {
    streamSubscription?.cancel();
    super.dispose();
  }

  // ─── Navigate to dedicated screen for each widget ───
  void _onCardTap(int index) {
    Widget targetWidget;
    String screenTitle;
    Color accentColor;

    switch (index) {
      case 0:
        targetWidget = AddUserWidget();
        screenTitle = 'Add Users';
        accentColor = _C.primary;
        break;
      case 1:
        targetWidget = DeleteUserWidget();
        screenTitle = 'Delete Users';
        accentColor = _C.error;
        break;
      case 2:
        targetWidget = VerifyUserWidget();
        screenTitle = 'Verify Users';
        accentColor = _C.secondary;
        break;
      case 3:
        if (webSocketSingleton.channel != null) {
          print('Sent: View Users');
        } else {
          print('Channel is not connected');
        }
        targetWidget = ViewUsersWidget();
        screenTitle = 'View Users';
        accentColor = _C.primary;
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _UserActionScreen(
              title: screenTitle,
              accentColor: accentColor,
              child: targetWidget,
            ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBody() {
    return Container(
      color: _C.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dashboard Header ──
            _buildDashboardHeader(),
            const SizedBox(height: 28),

            // ── Policy Card ──
            _buildPolicyCard(),
            const SizedBox(height: 28),

            // ── Management Cards ──
            _buildManagementSection(),
          ],
        ),
      ),
    );
  }

  // ─── Dashboard Header ───
  Widget _buildDashboardHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _C.onSurface,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 80,
          height: 5,
          decoration: BoxDecoration(
            gradient: _pulseGradient,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  // ─── Policy Card ───
  Widget _buildPolicyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Global Policy',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'VDB Pro',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
          // Glow effect
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: _pulseGradient,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Management Cards Section ───
  Widget _buildManagementSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card height dynamically to ensure content fits
        const crossAxisCount = 2;
        const crossAxisSpacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - crossAxisSpacing) / crossAxisCount;
        // Fixed height that comfortably fits icon (50) + gap + title + desc
        const cardHeight = 190.0;

        return Wrap(
          spacing: crossAxisSpacing,
          runSpacing: 12,
          children: List.generate(_mgmtCards.length, (i) {
            final card = _mgmtCards[i];
            return SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: _ManagementCardWidget(
                card: card,
                onTap: () => _onCardTap(i),
              ),
            );
          }),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Main build
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<LoaderProvider>(context).isLoading;

    if (widget.embedded) {
      return _buildBody();
    }

    return SafeArea(
      child: ModalProgressHUD(
        inAsyncCall: isLoading,
        child: Scaffold(
          backgroundColor: _C.surface,
          appBar: AppBar(
            backgroundColor: _C.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 64,
            leading: Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: _C.primary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
            ),
            title: Text(
              'System Access Hub',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _C.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: false,
          ),
          body: _buildBody(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DEDICATED SCREEN FOR EACH USER ACTION
// Wraps AddUserWidget / DeleteUserWidget / VerifyUserWidget /
// ViewUsersWidget in a full Scaffold so PopScope, Navigator.pop,
// and video renderers all work correctly.
// ═══════════════════════════════════════════════════════════════════
class _UserActionScreen extends StatelessWidget {
  final String title;
  final Color accentColor;
  final Widget child;

  const _UserActionScreen({
    required this.title,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<LoaderProvider>(context).isLoading;

    return SafeArea(
      child: ModalProgressHUD(
        inAsyncCall: isLoading,
        child: Scaffold(
          backgroundColor: _C.surface,
          appBar: AppBar(
            backgroundColor: _C.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 64,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _C.primary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _C.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _C.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _C.outlineVariant.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.onSurface.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MANAGEMENT CARD WIDGET (Stateful for press animation)
// ═══════════════════════════════════════════════════════════════════
class _ManagementCardWidget extends StatefulWidget {
  final _MgmtCard card;
  final VoidCallback onTap;

  const _ManagementCardWidget({required this.card, required this.onTap});

  @override
  State<_ManagementCardWidget> createState() => _ManagementCardWidgetState();
}

class _ManagementCardWidgetState extends State<_ManagementCardWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

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
          color: _isPressed
              ? _C.primary.withValues(alpha: 0.04)
              : _C.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _C.outlineVariant.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _C.onSurface.withValues(alpha: _isPressed ? 0.08 : 0.03),
              blurRadius: _isPressed ? 16 : 8,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Left accent strip
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _isPressed ? 4 : 0,
                  color: card.accentColor,
                ),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isPressed ? null : _C.surfaceContainerLow,
                        gradient: _isPressed ? _pulseGradient : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        card.icon,
                        color: _isPressed ? Colors.white : card.iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Title
                    Text(
                      card.title,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _C.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Expanded(
                      child: Text(
                        card.desc,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _C.outline,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Arrow indicator
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: _isPressed ? card.accentColor : _C.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
