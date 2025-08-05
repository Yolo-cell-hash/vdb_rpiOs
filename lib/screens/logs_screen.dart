import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/widgets/activity_log_card.dart';
import 'package:vdp_poc_new/widgets/activity_log_card.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getLogsStream() {
    return _firestore
        .collection('logs')
        .where(FieldPath.documentId, isNotEqualTo: 'no_of_logs')
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

  late int statusCode;

  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 90,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          leading: Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                ),
          ),
          title: const Text(
            'Logs',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getLogsStream(),
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
                    Text('Loading logs...'),
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
                    Text('No logs found', style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: users.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String activity = data['message '] as String? ?? 'Unknown';

                  // Calculate statusCode directly without setState
                  int statusCode;
                  if(activity.toString().contains('Error')){
                    statusCode = 0;
                  }else if(activity.toString().contains('Success')){
                    statusCode = 1;
                  } else {
                    statusCode = -1; // or some default value
                  }

                  String timeStamp = data['timestamp'] as String? ?? 'Unknown';
                  if (timeStamp != 'Unknown') {
                    try {
                      DateTime dateTime = DateTime.parse(timeStamp);
                      timeStamp = dateTime.toString();
                    } catch (e) {
                      timeStamp = 'Invalid date';
                    }
                  }
                  final imageData = _decodeBase64Image(data['image']);
                  return ActivityLogCard(activity: activity, time: timeStamp, statusCode: statusCode, imageData: imageData);
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
