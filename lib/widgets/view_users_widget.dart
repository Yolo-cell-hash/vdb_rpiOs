import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/widgets/user_card_row.dart';

class ViewUsersWidget extends StatefulWidget {
  const ViewUsersWidget({super.key});

  @override
  State<ViewUsersWidget> createState() => _ViewUsersWidgetState();
}

class _ViewUsersWidgetState extends State<ViewUsersWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getUsersStream() {
    return _firestore
        .collection('users')
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
      print('Error decoding image: $e');
      return null;
    }
  }

  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading users...'),
              ],
            ),
          );
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No users found', style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: users.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              String name = data['name '] as String? ?? 'Unknown';
              final imageData = _decodeBase64Image(data['image']);
              return UserCardRow(name: name, imageData: imageData);
            }).toList(),
          ),
        );
      },
    );
  }
}