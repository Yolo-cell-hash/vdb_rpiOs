import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// Design tokens (matching the HTML Tailwind config)
// ═══════════════════════════════════════════════════════════════════
class _T {
  static const Color primary = Color(0xFF0058BC);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color outline = Color(0xFF717786);
  static const Color outlineVariant = Color(0xFFC1C6D7);
  static const Color error = Color(0xFFBA1A1A);
}

const _pulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0058BC), Color(0xFF3DC2FD)],
);

// ═══════════════════════════════════════════════════════════════════
// ViewUsersWidget – redesigned to match the HTML user directory
// ═══════════════════════════════════════════════════════════════════
class ViewUsersWidget extends StatefulWidget {
  const ViewUsersWidget({super.key});

  @override
  State<ViewUsersWidget> createState() => _ViewUsersWidgetState();
}

class _ViewUsersWidgetState extends State<ViewUsersWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getUsersStream() {
    final collectionName =
        Provider.of<LoaderProvider>(context, listen: false).usersCollection;
    return _firestore
        .collection(collectionName)
        .where(FieldPath.documentId, isNotEqualTo: 'no_of_users')
        .snapshots();
  }

  Uint8List? _decodeBase64Image(dynamic encodedImage) {
    if (encodedImage == null) return null;

    try {
      if (encodedImage is Blob) {
        return encodedImage.bytes;
      } else if (encodedImage is String && encodedImage.isNotEmpty) {
        return base64Decode(encodedImage);
      }
      return null;
    } catch (e) {
      debugPrint('Error decoding image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        // ── Error state ──
        if (snapshot.hasError) {
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
                      color: _T.error.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded,
                        size: 36, color: _T.error),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Failed to load users',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _T.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _T.outline, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // ── Loading state ──
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_T.primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading personnel…',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _T.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final users = snapshot.data?.docs ?? [];

        // ── Empty state ──
        if (users.isEmpty) {
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
                      color: _T.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline_rounded,
                        size: 36, color: _T.outline),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No personnel found',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _T.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users will appear here once they are added to the system.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _T.outline, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // ── Data loaded — build the directory ──
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Directory Header & Stats ──
            _DirectoryHeader(userCount: users.length),
            const SizedBox(height: 24),

            // ── User Grid ──
            LayoutBuilder(
              builder: (context, constraints) {
                // 2 columns on wider screens, 1 on narrow
                final crossAxisCount = constraints.maxWidth > 500 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: crossAxisCount == 2 ? 0.95 : 1.6,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data =
                        users[index].data() as Map<String, dynamic>;
                    final name =
                        data['name '] as String? ?? 'Unknown';
                    final imageData = _decodeBase64Image(data['image']);

                    return FadeInUp(
                      duration: Duration(milliseconds: 350 + (index * 80)),
                      from: 16,
                      child: _UserCard(
                        name: name,
                        imageData: imageData,
                        index: index,
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: _T.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 16, color: _T.outline),
                  const SizedBox(width: 8),
                  Text(
                    'Showing ${users.length} ${users.length == 1 ? 'user' : 'users'}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _T.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Directory Header
// ═══════════════════════════════════════════════════════════════════
class _DirectoryHeader extends StatelessWidget {
  final int userCount;
  const _DirectoryHeader({required this.userCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'ACCESS CONTROL',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _T.outline,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 6),
        // Title
        Text(
          'Active Personnel',
          style: GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _T.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        // Online badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _T.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _T.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _T.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$userCount Registered',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _T.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// User Card – matches the HTML card design
// ═══════════════════════════════════════════════════════════════════
class _UserCard extends StatefulWidget {
  final String name;
  final Uint8List? imageData;
  final int index;

  const _UserCard({
    required this.name,
    this.imageData,
    required this.index,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isHovered = false;

  void _showFullImage() {
    if (widget.imageData == null) return;
    showDialog(
      context: context,
      builder: (context) => FadeIn(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            widget.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.memory(
                widget.imageData!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Assign a role label based on index for visual variety
  String get _roleLabel {
    const roles = ['Admin', 'User', 'Viewer', 'Editor', 'Analyst', 'Auditor'];
    return roles[widget.index % roles.length];
  }

  bool get _isAdmin => _roleLabel == 'Admin';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showFullImage,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _T.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? _T.outlineVariant.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: _T.onSurface.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Left accent bar (visible on hover/press)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                left: 0,
                top: 24,
                bottom: 24,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 3.5,
                  decoration: BoxDecoration(
                    gradient: _isHovered ? _pulseGradient : null,
                    color: _isHovered ? null : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: avatar + more button ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with online indicator
                        _buildAvatar(),
                        const Spacer(),
                        // More button
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _T.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: _T.outline,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Name & role ──
                    Text(
                      widget.name,
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _T.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'System User',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _T.outline,
                      ),
                    ),

                    const Spacer(),

                    // ── Bottom row: timestamp + role badge ──
                    Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: _T.surfaceContainer,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Schedule icon + text
                          Icon(Icons.schedule_rounded,
                              size: 14, color: _T.outline),
                          const SizedBox(width: 6),
                          Text(
                            'Active',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _T.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isAdmin
                                  ? const Color(0xFFEBF2FF)
                                  : const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _roleLabel.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _isAdmin
                                    ? _T.primary
                                    : const Color(0xFF4B5563),
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
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar with green online dot ──
  Widget _buildAvatar() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Profile image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _T.onSurface.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: widget.imageData != null
                  ? Image.memory(
                      widget.imageData!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholderAvatar(),
                    )
                  : _placeholderAvatar(),
            ),
          ),
          // Online indicator dot
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      width: 56,
      height: 56,
      color: _T.surfaceContainerLow,
      child: Icon(
        Icons.person_rounded,
        size: 28,
        color: _T.outline,
      ),
    );
  }
}