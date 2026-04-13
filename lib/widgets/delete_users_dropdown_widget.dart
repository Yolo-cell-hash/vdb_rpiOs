import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';

class DeleteUsersDropdownWidget extends StatefulWidget {
  final ValueChanged<Set<String>> onSelectionChanged;
  final ValueChanged<Map<String, String>> onUserNamesChanged;

  const DeleteUsersDropdownWidget({
    super.key,
    required this.onSelectionChanged,
    required this.onUserNamesChanged,
  });

  @override
  State<DeleteUsersDropdownWidget> createState() =>
      _DeleteUsersDropdownWidgetState();
}

class _DeleteUsersDropdownWidgetState extends State<DeleteUsersDropdownWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _usersStream;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  final Map<String, String> _userNames = {};
  final Map<String, Uint8List?> _imageCache = {};

  String _searchQuery = '';
  bool _selectAll = false;
  bool _streamInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamInitialized) {
      final collectionName =
          Provider.of<LoaderProvider>(context, listen: false).usersCollection;
      _usersStream = _firestore
          .collection(collectionName)
          .where(FieldPath.documentId, isNotEqualTo: 'no_of_users')
          .snapshots();
      _streamInitialized = true;
    }
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
    } catch (_) {
      return null;
    }
  }

  Uint8List? _getCachedImageBytes(String userId, dynamic encodedImage) {
    if (_imageCache.containsKey(userId)) return _imageCache[userId];
    final bytes = _decodeBase64Image(encodedImage);
    _imageCache[userId] = bytes;
    return bytes;
  }

  void _emitSelection() {
    // Emit copies so parent does not hold mutable references from this State.
    widget.onSelectionChanged(Set<String>.from(_selectedUserIds));
    widget.onUserNamesChanged(Map<String, String>.from(_userNames));
  }

  void _toggleUser(String userId, String userName, int totalUsers) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        _userNames.remove(userId);
      } else {
        _selectedUserIds.add(userId);
        _userNames[userId] = userName;
      }
      _selectAll = totalUsers > 0 && _selectedUserIds.length == totalUsers;
    });

    _emitSelection();
  }

  void _toggleSelectAll(List<QueryDocumentSnapshot> users) {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        for (final doc in users) {
          final data = doc.data() as Map<String, dynamic>;
          final userName = data['name '] as String? ?? 'Unknown';
          _selectedUserIds.add(doc.id);
          _userNames[doc.id] = userName;
        }
      } else {
        _selectedUserIds.clear();
        _userNames.clear();
      }
    });

    _emitSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading users: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF0058BC)),
            ),
          );
        }

        final allUsers = snapshot.data?.docs ?? [];

        if (allUsers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Text('No users available'),
          );
        }

        final users = _searchQuery.isEmpty
            ? allUsers
            : allUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final userName = data['name '] as String? ?? 'Unknown';
          return userName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
              doc.id.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Revoke Access',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Decommissioning user identities from the Godrej VDB. This action is irreversible.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF414755),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),

            // Search
            Container(
              height: 56,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E3E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF191C1E),
                ),
                decoration: InputDecoration(
                  hintText: 'Search users by name or ID...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: const Color(0xFF717786).withOpacity(0.6),
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 8),
                    child: Icon(Icons.search, color: Color(0xFF717786)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),

            // User list
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFFC1C6D7).withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _selectAll,
                            onChanged: (_) => _toggleSelectAll(allUsers),
                            activeColor: const Color(0xFF0058BC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: const BorderSide(color: Color(0xFFC1C6D7)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select All Users',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF414755),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${allUsers.length} TOTAL ENTITIES',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Color(0xFF717786),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No users found',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF717786),
                        ),
                      ),
                    )
                  else
                    ...users.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userName = data['name '] as String? ?? 'Unknown';
                      final imageBytes =
                      _getCachedImageBytes(doc.id, data['image']);
                      final isSelected = _selectedUserIds.contains(doc.id);

                      return InkWell(
                        onTap: () =>
                            _toggleUser(doc.id, userName, allUsers.length),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0058BC).withOpacity(0.04)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleUser(
                                    doc.id,
                                    userName,
                                    allUsers.length,
                                  ),
                                  activeColor: const Color(0xFF0058BC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFC1C6D7),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E3E5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageBytes != null
                                    ? Image.memory(
                                  imageBytes,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                )
                                    : const Icon(
                                  Icons.person,
                                  color: Color(0xFF717786),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF191C1E),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${doc.id}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: Color(0xFF414755),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),

            // Warning
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFBA1A1A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFBA1A1A).withOpacity(0.1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.gpp_maybe, color: Color(0xFFBA1A1A), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Critical Action Confirmation',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBA1A1A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Deletion will instantly revoke all hardware access, cloud permissions, and wipe encrypted local keys for the selected accounts.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF414755),
                          ),
                        ),
                      ],
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
