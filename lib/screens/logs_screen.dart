import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vdp_poc_new/widgets/activity_log_card.dart';

class LogsScreen extends StatefulWidget {
  final bool embedded;
  const LogsScreen({super.key, this.embedded = false});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _logsPerPage = 20;
  final Map<String, Uint8List?> _imageCache = {};

  List<DocumentSnapshot> _allLogs = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isInitialLoading = true; // Add this flag

  @override
  void initState() {
    super.initState();
    _loadInitialLogs();
  }

  Future<void> _loadInitialLogs() async {
    setState(() {
      _isInitialLoading = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .limit(_logsPerPage)
          .get();

      setState(() {
        _allLogs = querySnapshot.docs
            .where((doc) => doc.id != 'no_of_logs')
            .toList();

        if (_allLogs.isNotEmpty) {
          _lastDocument = _allLogs.last;
        }

        _hasMoreData = querySnapshot.docs.length == _logsPerPage;
        _isInitialLoading = false; // Set to false after loading
      });
    } catch (e) {
      print('Error loading initial logs: $e');
      setState(() {
        _isInitialLoading = false; // Set to false even on error
      });
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_logsPerPage)
          .get();

      final newLogs = querySnapshot.docs
          .where((doc) => doc.id != 'no_of_logs')
          .toList();

      setState(() {
        _allLogs.addAll(newLogs);

        if (newLogs.isNotEmpty) {
          _lastDocument = newLogs.last;
        }

        _hasMoreData = querySnapshot.docs.length == _logsPerPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more logs: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _allLogs.clear();
      _lastDocument = null;
      _hasMoreData = true;
      _imageCache.clear();
    });
    await _loadInitialLogs();
  }

  bool _isValidBase64(String str) {
    if (str.isEmpty) return false;
    str = str.replaceAll(RegExp(r'\s'), '');
    if (str.length % 4 != 0) return false;
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    return base64Pattern.hasMatch(str);
  }

  Uint8List? _decodeBase64Image(dynamic encodedImage, String docId) {
    if (encodedImage == null) return null;

    // Check cache first
    if (_imageCache.containsKey(docId)) {
      return _imageCache[docId];
    }

    try {
      Uint8List? decoded;

      if (encodedImage is Blob) {
        decoded = encodedImage.bytes;
      } else if (encodedImage is String) {
        if (!_isValidBase64(encodedImage)) {
          // Silently handle invalid base64 - no need to log every time
          _imageCache[docId] = null;
          return null;
        }

        String cleanedString = encodedImage.replaceAll(RegExp(r'\s'), '');
        while (cleanedString.length % 4 != 0) {
          cleanedString += '=';
        }

        decoded = base64Decode(cleanedString);
      }

      _imageCache[docId] = decoded;
      return decoded;
    } catch (e) {
      // Silently cache null for failed decodes
      _imageCache[docId] = null;
      return null;
    }
  }

  int _getStatusCode(String activity) {
    if (activity.contains('Error')) {
      return 0;
    } else if (activity.contains('Success')) {
      return 1;
    } else {
      return 2;
    }
  }

  String _formatTimestamp(String? timeStamp) {
    if (timeStamp == null || timeStamp == 'Unknown') {
      return DateTime.now().toString();
    }

    try {
      DateTime dateTime = DateTime.parse(timeStamp);
      return dateTime.toString();
    } catch (e) {
      return DateTime.now().toString();
    }
  }

  Widget _buildBody() {
    return _isInitialLoading
        ? _buildLoadingState()
        : _allLogs.isEmpty
        ? _buildEmptyState()
        : RefreshIndicator(
      onRefresh: _refreshLogs,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 20,
          left: 0,
          right: 0,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _allLogs.length + 1,
        itemBuilder: (context, index) {
          if (index == _allLogs.length) {
            return _buildLoadMoreButton();
          }

          final doc = _allLogs[index];
          final data = doc.data() as Map<String, dynamic>;

          final String activity =
              data['message '] as String? ?? 'Unknown Activity';
          final int statusCode = _getStatusCode(activity);
          final String timeStamp =
          _formatTimestamp(data['timestamp'] as String?);
          final Uint8List? imageData =
          _decodeBase64Image(data['image'], doc.id);

          return ActivityLogCard(
            activity: activity,
            time: timeStamp,
            statusCode: statusCode,
            imageData: imageData,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
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
          builder: (context) => IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          children: [
            const Text(
              'Activity Logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_allLogs.isNotEmpty)
              Text(
                '${_allLogs.length} logs',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator(strokeWidth: 4, color: Colors.blueAccent,),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading logs...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (!_hasMoreData) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.grey[400], size: 20),
                const SizedBox(width: 8),
                Text(
                  'All logs loaded',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: _isLoadingMore
          ? Center(
        child: Column(
          children: [
            const SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading more logs...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : ElevatedButton.icon(
        onPressed: _loadMoreLogs,
        icon: const Icon(Icons.expand_more),
        label: const Text('Load More Logs'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Logs Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Activity logs will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshLogs,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _imageCache.clear();
    super.dispose();
  }
}