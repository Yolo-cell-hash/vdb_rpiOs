import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vdp_poc_new/utils/firebase_core_utils.dart';
import 'package:provider/provider.dart';
import 'package:vdp_poc_new/utils/loader_provider.dart';
import 'package:drop_down_search_field/drop_down_search_field.dart';

class DeleteUsersDropdownWidget extends StatefulWidget {
  const DeleteUsersDropdownWidget({super.key});

  @override
  State<DeleteUsersDropdownWidget> createState() =>
      _DeleteUsersDropdownWidgetState();
}

class _DeleteUsersDropdownWidgetState extends State<DeleteUsersDropdownWidget> {
  String? selectedUserId;
  FbUtils fbUtils = FbUtils();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _getUsersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Text('Error loading users: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              );
            }

            final users = snapshot.data?.docs ?? [];

            if (users.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Text('No users available'),
              );
            }

            return DropDownSearchField(
              displayAllSuggestionWhenTap: true,
              isMultiSelectDropdown: false,
              textFieldConfiguration: TextFieldConfiguration(
                controller: _controller,
                autofocus: false,
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(fontStyle: FontStyle.italic),
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),
              suggestionsCallback: (pattern) async {
                if (pattern.isEmpty) {
                  return users.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    String userName = data['name '] as String? ?? 'Unknown';
                    return {
                      'id': doc.id,
                      'name': userName,
                      'image': _decodeBase64Image(data['image']),
                    };
                  }).toList();
                }
                return users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String userName = data['name '] as String? ?? 'Unknown';
                  return userName.toLowerCase().contains(pattern.toLowerCase());
                }).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String userName = data['name '] as String? ?? 'Unknown';
                  return {
                    'id': doc.id,
                    'name': userName,
                    'image': _decodeBase64Image(data['image']),
                  };
                }).toList();
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  leading: Image.memory(
                    suggestion['image'] as Uint8List? ?? Uint8List(0),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                  title: Text(suggestion['name'] as String? ?? 'Unknown'),
                  subtitle: Text('ID: ${suggestion['id']}'),
                );
              },
              onSuggestionSelected: (suggestion) {
                setState(() {
                  selectedUserId = suggestion['id'] as String?;
                  String userName = suggestion['name'] as String? ?? '';

                  _controller.text = userName;

                  Provider.of<LoaderProvider>(
                    context,
                    listen: false,
                  ).setSelectedUser(selectedUserId!, userName);
                });
              },
            );
          },
        ),
      ],
    );
  }
}
