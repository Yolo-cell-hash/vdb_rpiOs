import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class JanusWebRTCClient {
  WebSocketChannel? _channel;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final String _janusUrl;
  final StreamController<String> _messageController = StreamController<String>. broadcast();
  final StreamController<MediaStream> _remoteStreamController = StreamController<MediaStream>.broadcast();
  final StreamController<RTCIceConnectionState> _iceStateController = StreamController<RTCIceConnectionState>.broadcast();
  final StreamController<RTCPeerConnectionState> _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();

  int _sessionId = 0;
  int _handleId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _transactions = {};
  Timer? _keepAliveTimer;
  bool _isConnected = false;

  JanusWebRTCClient(this._janusUrl);

  // Public streams
  Stream<String> get messages => _messageController.stream;
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  Stream<RTCIceConnectionState> get iceConnectionState => _iceStateController. stream;
  Stream<RTCPeerConnectionState> get connectionState => _connectionStateController.stream;

  // Public getters
  bool get isConnected => _isConnected;
  int get sessionId => _sessionId;
  int get handleId => _handleId;
  MediaStream? get localStream => _localStream;
  RTCPeerConnection? get peerConnection => _peerConnection;

  /// Connect to Janus server and create session
  Future<void> connect() async {
    try {
      print('🔌 Connecting to Janus at $_janusUrl');

      // Connect to Janus WebSocket with janus-protocol subprotocol
      _channel = WebSocketChannel.connect(
        Uri.parse(_janusUrl),
        protocols: ['janus-protocol'],
      );

      print('✅ Connected to Janus WebSocket');

      // Listen to incoming messages
      _channel! .stream.listen(
        _handleWebSocketMessage,
        onError:  (error) {
          print('❌ WebSocket error: $error');
          _messageController.add('Connection error: $error');
          _isConnected = false;
        },
        onDone: () {
          print('🔴 WebSocket connection closed');
          _messageController.add('Connection closed');
          _isConnected = false;
        },
      );

      // Create Janus session
      await _createSession();

      // Start keep-alive
      _startKeepAlive();

      _isConnected = true;
      _messageController.add('Connected to Janus');

    } catch (e) {
      print('❌ Connection failed: $e');
      _messageController.add('Connection failed: $e');
      _isConnected = false;
      rethrow;
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      print('📩 Received:  $data');

      final janusEvent = data['janus'];

      // Handle trickle ICE candidates from Janus (CRITICAL!)
      if (janusEvent == 'trickle') {
        final candidate = data['candidate'];
        if (candidate != null) {
          if (candidate.containsKey('completed')) {
            print('✅ Janus finished sending ICE candidates');
          } else {
            _addRemoteIceCandidate(candidate);
          }
        }
        return;
      }

      // Handle transaction responses
      if (data['transaction'] != null) {
        final transactionId = data['transaction'];
        if (_transactions.containsKey(transactionId)) {
          if (! _transactions[transactionId]! .isCompleted) {
            _transactions[transactionId]!.complete(data);
          }
          _transactions.remove(transactionId);
        }
      }

      // Handle Janus events
      switch (janusEvent) {
        case 'event':
          _handleJanusEvent(data);
          break;

        case 'webrtcup':
          _messageController.add('WebRTC connection established');
          print('✅ WebRTC connection is UP');
          break;

        case 'media':
          final receiving = data['receiving'] ?? false;
          final type = data['type'] ?? 'unknown';
          _messageController.add('Media $type ${receiving ? 'started' : 'stopped'}');
          print('📺 Media $type ${receiving ? 'flowing' : 'stopped'}');
          break;

        case 'slowlink':
          final uplink = data['uplink'] ?? false;
          final lost = data['lost'] ?? 0;
          print('⚠️ Slow link detected (${uplink ? 'uplink' :  'downlink'}): $lost packets lost');
          _messageController.add('Network quality degraded');
          break;

        case 'hangup':
          final reason = data['reason'] ?? 'Unknown reason';
          print('📴 Hangup received: $reason');
          _messageController.add('Stream ended: $reason');
          break;

        case 'detached':
          print('🔌 Plugin detached');
          _messageController.add('Plugin detached');
          break;

        case 'timeout':
          print('⏱️ Session timeout');
          _messageController. add('Session timeout');
          _isConnected = false;
          break;

        case 'keepalive':
          print('💓 Keep-alive ACK received');
          break;

        case 'ack':
        // Just an acknowledgment, no action needed
          break;

        default:
          print('ℹ️ Unknown Janus event: $janusEvent');
      }

    } catch (e) {
      print('❌ Error parsing message: $e');
    }
  }

  /// Handle Janus plugin events
  void _handleJanusEvent(Map<String, dynamic> data) {
    final pluginData = data['plugindata'];
    if (pluginData != null) {
      final plugin = pluginData['plugin'];
      final eventData = pluginData['data'];

      if (plugin == 'janus.plugin.streaming') {  // ✅ FIXED:  Removed extra space
        _handleStreamingEvent(eventData);
      }
    }

    // Handle JSEP (SDP) messages
    if (data['jsep'] != null) {
      _handleJSEP(data['jsep']);
    }
  }

  /// Handle streaming plugin specific events
  void _handleStreamingEvent(Map<String, dynamic> data) {
    final result = data['result'];

    if (result != null) {
      final status = result['status'];

      switch (status) {
        case 'starting':
          _messageController.add('Stream starting.. .');
          print('▶️ Stream starting...');
          break;
        case 'started':
          _messageController.add('Stream started successfully');
          print('✅ Stream started');
          break;
        case 'stopped':
          _messageController.add('Stream stopped');
          print('⏹️ Stream stopped');
          break;
        case 'stopping':
          _messageController.add('Stream stopping...');
          print('⏸️ Stream stopping...');
          break;
        case 'preparing':
          _messageController.add('Preparing stream...');
          print('🔄 Preparing stream...');
          break;
        case 'pausing':
          _messageController.add('Pausing stream...');
          print('⏸️ Pausing stream...');
          break;
        case 'resuming':
          _messageController. add('Resuming stream...');
          print('▶️ Resuming stream...');
          break;
      }
    }

    // Handle stream list
    if (data['streaming'] == 'list') {
      final list = data['list'];
      if (list != null && list is List) {
        _messageController.add('Available streams: ${list.length}');
        print('📋 Stream list (${list.length} streams):');
        for (var stream in list) {
          print('  - ID: ${stream['id']}, Description: ${stream['description']}');
        }
      }
    }

    // Handle stream info
    if (data['streaming'] == 'info') {
      final info = data['info'];
      if (info != null) {
        final description = info['description'] ?? 'Unknown';
        _messageController.add('Stream info: $description');
        print('ℹ️ Stream info:  $info');
      }
    }

    // Handle errors
    if (data['error_code'] != null) {
      final errorCode = data['error_code'];
      final error = data['error'] ?? 'Unknown error';
      print('❌ Streaming error ($errorCode): $error');
      _messageController.add('Error: $error');
    }
  }

  /// Handle JSEP (SDP offer/answer)
  Future<void> _handleJSEP(Map<String, dynamic> jsep) async {
    if (_peerConnection == null) {
      await _createPeerConnection();
    }

    try {
      if (jsep['type'] == 'offer') {
        print('📩 Received SDP offer from Janus');

        // Set remote description
        await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(jsep['sdp'], jsep['type'])
        );

        // Create answer with optimized constraints
        final answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        });

        // Set local description
        await _peerConnection!.setLocalDescription(answer);

        // Send answer to Janus
        await _sendMessage({
          'janus': 'message',
          'session_id': _sessionId,
          'handle_id': _handleId,
          'body': {
            'request': 'start',
          },
          'jsep': {
            'type': answer.type,
            'sdp': answer.sdp,
          }
        });

        print('📤 Sent SDP answer to Janus');
      }
    } catch (e) {
      print('❌ Error handling JSEP: $e');
      _messageController.add('Error handling JSEP: $e');
    }
  }

  /// Add remote ICE candidate from Janus
  Future<void> _addRemoteIceCandidate(Map<String, dynamic> candidate) async {
    if (_peerConnection == null) {
      print('⚠️ Cannot add remote candidate:  PeerConnection not ready');
      return;
    }

    try {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
      print('✅ Added remote ICE candidate:  ${candidate['candidate']}');
    } catch (e) {
      print('❌ Error adding remote ICE candidate: $e');
    }
  }

  /// Create Janus session
  Future<void> _createSession() async {
    final transaction = _generateTransaction();
    final message = {
      'janus':  'create',
      'transaction': transaction,
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel! .sink.add(jsonEncode(message));

    final response = await completer.future. timeout(
      Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Session creation timeout'),
    );

    if (response['janus'] == 'success') {
      _sessionId = response['data']['id'];
      print('✅ Session created:  $_sessionId');
      _messageController.add('Session created: $_sessionId');
    } else {
      final error = response['error'] ?? 'Unknown error';
      throw Exception('Failed to create session: $error');
    }
  }

  Future<bool> attachToStreamingPlugin() async {
    if (_sessionId == 0) {
      print('❌ No active session.   Call connect() first.');
      return false;
    }

    try {
      final transaction = _generateTransaction();
      final message = {
        'janus':  'attach',
        'session_id': _sessionId,
        'plugin': 'janus.plugin.streaming',  // ✅ FIXED:  Removed extra space
        'transaction': transaction,
      };

      final completer = Completer<Map<String, dynamic>>();
      _transactions[transaction] = completer;

      _channel! .sink.add(jsonEncode(message));

      final response = await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Plugin attach timeout'),
      );

      if (response['janus'] == 'success') {
        _handleId = response['data']['id'];
        print('✅ Attached to streaming plugin:  $_handleId');
        _messageController.add('Attached to streaming plugin');
        return true;
      } else {
        final error = response['error'] ?? 'Unknown error';
        print('❌ Failed to attach to plugin: $error');
        return false;
      }
    } catch (e) {
      print('❌ Exception attaching to plugin: $e');
      return false;
    }
  }

  /// List available streams
  Future<void> listStreams() async {
    if (_handleId == 0) {
      print('⚠️ No plugin handle. Call attachToStreamingPlugin() first.');
      return;
    }

    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id':  _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'list',
      }
    };

    _channel!.sink.add(jsonEncode(message));
    print('📋 List streams request sent');
  }

  /// Watch a specific stream
  Future<void> watchStream(int streamId) async {
    if (_handleId == 0) {
      throw Exception('No plugin handle.  Call attachToStreamingPlugin() first.');
    }

    await _createPeerConnection();

    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id':  _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'watch',
        'id': streamId,
      }
    };

    _channel!. sink.add(jsonEncode(message));
    print('👁️ Watch stream $streamId request sent');
    _messageController.add('Watching stream $streamId.. .');
  }

  /// Start playback of current stream
  Future<void> startStream(int streamId) async {
    if (_peerConnection == null) {
      throw Exception('No peer connection. Call watchStream() first.');
    }

    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request':  'start',
      }
    };

    _channel! .sink.add(jsonEncode(message));
    print('▶️ Start stream request sent');
    _messageController. add('Starting stream.. .');
  }

  /// Stop current stream
  Future<void> stopStream() async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id':  _handleId,
      'transaction': transaction,
      'body':  {
        'request': 'stop',
      }
    };

    _channel!.sink. add(jsonEncode(message));
    print('⏹️ Stop stream request sent');
    _messageController.add('Stopping stream...');
  }

  /// Pause current stream
  Future<void> pauseStream() async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'pause',
      }
    };

    _channel!.sink.add(jsonEncode(message));
    print('⏸️ Pause stream request sent');
    _messageController.add('Pausing stream...');
  }

  /// Switch to a different stream
  Future<void> switchStream(int streamId) async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id':  _handleId,
      'transaction': transaction,
      'body':  {
        'request': 'switch',
        'id': streamId,
      }
    };

    _channel!.sink. add(jsonEncode(message));
    print('🔄 Switch to stream $streamId request sent');
    _messageController.add('Switching to stream $streamId...');
  }

  /// Create WebRTC peer connection
  Future<void> _createPeerConnection() async {
    // OPTIMIZED ICE CONFIGURATION FOR LOW LATENCY
    final configuration = {
      'iceServers': [

        {'urls': 'stun:13.203.89.154:3478'},
        {'urls': 'turns:vdb-poc.duckdns.org:5349', 'username': 'vdb-poc', 'credential': 'vdb-poc'},
        {'urls': 'turn:vdb-poc.duckdns.org:3478?transport=tcp', 'username': 'vdb-poc', 'credential': 'vdb-poc'},


        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        { 'urls': "stun:stun.l.google.com:19302" },
        { 'urls': "stun:stun.l.google.com:5349" },
        { 'urls': "stun:stun1.l.google.com:3478" },
        { 'urls': "stun:stun1.l.google.com:5349" },
        { 'urls': "stun:stun2.l.google.com:19302" },
        { 'urls': "stun:stun2.l.google.com:5349" },
        { 'urls': "stun:stun3.l.google.com:3478" },
        { 'urls': "stun:stun3.l.google.com:5349" },
        { 'urls': "stun:stun4.l.google.com:19302" },
        { 'urls': "stun:stun4.l.google.com:5349" },

      ],
      // Prefer UDP for lower latency
      'iceTransportPolicy': 'all',
      // Bundle policy for faster connection
      'bundlePolicy': 'max-bundle',
      // RTP policy for better media performance
      'rtcpMuxPolicy': 'require',
    };

    _peerConnection = await createPeerConnection(configuration);

    // Handle local ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate. candidate != null) {
        _sendMessage({
          'janus':  'trickle',
          'session_id': _sessionId,
          'handle_id': _handleId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
        print("📡 Local ICE candidate:  ${candidate.candidate}");
      } else {
        // ICE gathering complete
        _sendMessage({
          'janus':  'trickle',
          'session_id': _sessionId,
          'handle_id':  _handleId,
          'candidate': {'completed': true}
        });
        print("✅ Local ICE gathering completed");
      }
    };

    // Flag to prevent emitting the remote stream multiple times
    bool _remoteStreamEmitted = false;

    // Handle remote tracks
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('🎬 Remote track added: ${event.track.kind}');
      if (event.streams.isNotEmpty && !_remoteStreamEmitted) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(event.streams[0]);
        _remoteStreamEmitted = true;
        _messageController.add('Remote stream received');
        print('📺 Remote stream set on renderer (from onTrack)');
      }
    };

    // Legacy callback - only use as fallback if onTrack didn't fire
    _peerConnection!.onAddStream = (stream) {
      print('📺 Remote stream added (legacy callback)');
      if (!_remoteStreamEmitted) {
        _remoteStream = stream;
        _remoteStreamController.add(stream);
        _remoteStreamEmitted = true;
        print('📺 Remote stream set on renderer (from onAddStream fallback)');
      } else {
        print('📺 Skipping duplicate stream assignment from onAddStream');
      }
    };

    // Handle connection state changes
    _peerConnection!. onConnectionState = (state) {
      print('🔌 Connection state: $state');
      _connectionStateController.add(state);
      _messageController.add('Connection state: ${state.toString().split('.').last}');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _messageController.add('Connection failed - please retry');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _messageController.add('Successfully connected! ');
      }
    };

    // Handle ICE connection state changes
    _peerConnection!. onIceConnectionState = (state) {
      print('🧊 ICE connection state: $state');
      _iceStateController.add(state);

      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _messageController.add('ICE disconnected - checking connection...');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _messageController.add('ICE connection failed - please check network');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _messageController.add('ICE connected successfully!');
      }
    };

    // Handle ICE gathering state changes
    _peerConnection!. onIceGatheringState = (state) {
      print('📊 ICE gathering state: $state');
    };

    print('✅ PeerConnection created');
  }

  /// Send message to Janus server
  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }

    if (message['transaction'] == null) {
      message['transaction'] = _generateTransaction();
    }

    print('📤 Sending:  $message');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Generate random transaction ID
  String _generateTransaction() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random. secure();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Start keep-alive timer (for backward compatibility with old API)
  Future<void> keepAlive() async {
    _startKeepAlive();
  }

  /// Start keep-alive timer (internal method)
  void _startKeepAlive() {
    _keepAliveTimer?. cancel();
    _keepAliveTimer = Timer. periodic(Duration(seconds: 30), (timer) {
      if (_channel != null && _sessionId > 0 && _isConnected) {
        _sendMessage({
          'janus': 'keepalive',
          'session_id': _sessionId,
        });
        print('💓 Keep-alive sent');
      } else {
        print('⚠️ Keep-alive cancelled - session inactive');
        timer.cancel();
      }
    });
    print('✅ Keep-alive timer started (30s interval)');
  }

  /// Disconnect from Janus and cleanup
  Future<void> disconnect() async {
    print('🔴 Disconnecting from Janus...');

    // Cancel keep-alive timer
    _keepAliveTimer?.cancel();
    print('⏹️ Keep-alive timer stopped');

    // Send destroy message to Janus
    if (_sessionId > 0 && _channel != null) {
      try {
        await _sendMessage({
          'janus': 'destroy',
          'session_id': _sessionId,
        });
        print('✅ Session destroyed');
      } catch (e) {
        print('⚠️ Error sending destroy:  $e');
      }
    }

    // Cleanup WebRTC resources
    try {
      await _localStream?.dispose();
      await _peerConnection?.close();
      _peerConnection?. dispose();
      await _channel?.sink.close();
    } catch (e) {
      print('⚠️ Error during cleanup: $e');
    }

    // Reset state
    _sessionId = 0;
    _handleId = 0;
    _isConnected = false;
    _remoteStream = null;
    _localStream = null;
    _peerConnection = null;
    _channel = null;
    _transactions.clear();

    print('✅ Disconnected from Janus');
  }

  /// Dispose and close all resources
  void dispose() {
    disconnect();
    _messageController.close();
    _remoteStreamController.close();
    _iceStateController.close();
    _connectionStateController.close();
  }
}