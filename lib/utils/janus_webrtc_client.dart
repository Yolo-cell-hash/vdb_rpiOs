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
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<MediaStream> _remoteStreamController = StreamController<MediaStream>.broadcast();

  int _sessionId = 0;
  int _handleId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _transactions = {};

  JanusWebRTCClient(this._janusUrl);

  Stream<String> get messages => _messageController.stream;
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;

  Future<void> connect() async {
    try {
      // Connect to Janus WebSocket with janus-protocol subprotocol
      _channel = WebSocketChannel.connect(
        Uri.parse(_janusUrl),
        protocols: ['janus-protocol'], // Required subprotocol
      );

      print('Connected to Janus WebSocket with janus-protocol');

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          print('WebSocket error: $error');
          _messageController.add('Connection error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
          _messageController.add('Connection closed');
        },
      );

      // Create Janus session
      await _createSession();

    } catch (e) {
      print('Connection failed: $e');
      _messageController.add('Connection failed: $e');
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      print('Received: $data');

      // Handle transaction responses
      if (data['transaction'] != null) {
        final transactionId = data['transaction'];
        if (_transactions.containsKey(transactionId)) {
          _transactions[transactionId]!.complete(data);
          _transactions.remove(transactionId);
          return;
        }
      }

      // Handle Janus events
      if (data['janus'] == 'event') {
        _handleJanusEvent(data);
      } else if (data['janus'] == 'webrtcup') {
        _messageController.add('WebRTC connection established');
      } else if (data['janus'] == 'media') {
        _messageController.add('Media ${data['receiving'] ? 'started' : 'stopped'}');
      }

    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void _handleJanusEvent(Map<String, dynamic> data) {
    final pluginData = data['plugindata'];
    if (pluginData != null) {
      final plugin = pluginData['plugin'];
      final eventData = pluginData['data'];

      if (plugin == 'janus.plugin.streaming') {
        _handleStreamingEvent(eventData);
      }
    }

    // Handle JSEP (SDP) messages
    if (data['jsep'] != null) {
      _handleJSEP(data['jsep']);
    }
  }

  void _handleStreamingEvent(Map<String, dynamic> data) {
    final result = data['result'];

    if (result != null) {
      final status = result['status'];

      switch (status) {
        case 'starting':
          _messageController.add('Stream starting...');
          break;
        case 'started':
          _messageController.add('Stream started successfully');
          break;
        case 'stopped':
          _messageController.add('Stream stopped');
          break;
        case 'preparing':
          _messageController.add('Preparing stream...');
          break;
      }
    }

    // Handle stream list
    if (data['streaming'] == 'list') {
      final list = data['list'];
      if (list != null) {
        _messageController.add('Available streams: ${list.length}');
        print('Stream list: $list');
      }
    }

    // Handle stream info
    if (data['streaming'] == 'info') {
      final info = data['info'];
      if (info != null) {
        _messageController.add('Stream info: ${info['description']}');
        print('Stream info: $info');
      }
    }
  }

  Future<void> _handleJSEP(Map<String, dynamic> jsep) async {
    if (_peerConnection == null) {
      await _createPeerConnection();
    }

    try {
      if (jsep['type'] == 'offer') {
        await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(jsep['sdp'], jsep['type'])
        );

        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

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
      }
    } catch (e) {
      print('Error handling JSEP: $e');
    }
  }

  Future<void> _createSession() async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'create',
      'transaction': transaction,
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'success') {
      _sessionId = response['data']['id'];
      print('Session created: $_sessionId');
      _messageController.add('Session created: $_sessionId');
    } else {
      throw Exception('Failed to create session: ${response['error']}');
    }
  }

  Future<void> attachToStreamingPlugin() async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'attach',
      'session_id': _sessionId,
      'plugin': 'janus.plugin.streaming',
      'transaction': transaction,
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'success') {
      _handleId = response['data']['id'];
      print('Attached to streaming plugin: $_handleId');
      _messageController.add('Attached to streaming plugin');
    } else {
      throw Exception('Failed to attach to plugin: ${response['error']}');
    }
  }

  Future<void> listStreams() async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'list',
      }
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'ack') {
      print('List streams request acknowledged');
    }
  }

  Future<void> watchStream(int streamId) async {
    await _createPeerConnection();

    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'watch',
        'id': streamId,
      }
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'ack') {
      print('Watch stream request acknowledged');
      _messageController.add('Watching stream $streamId...');
    }
  }

  Future<void> startStream(int streamId) async {
    await _createPeerConnection();

    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'start',
        'id': streamId,
      }
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'ack') {
      print('Start stream request acknowledged');
      _messageController.add('Starting stream $streamId...');
    }
  }

  Future<void> stopStream() async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'stop',
      }
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'ack') {
      print('Stop stream request acknowledged');
      _messageController.add('Stopping stream...');
    }
  }

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

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'ack') {
      print('Pause stream request acknowledged');
      _messageController.add('Pausing stream...');
    }
  }

  Future<void> switchStream(int streamId) async {
    final transaction = _generateTransaction();
    final message = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'transaction': transaction,
      'body': {
        'request': 'switch',
        'id': streamId,
      }
    };

    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;

    _channel!.sink.add(jsonEncode(message));

    final response = await completer.future;
    if (response['janus'] == 'ack') {
      print('Switch stream request acknowledged');
      _messageController.add('Switching to stream $streamId...');
    }
  }

  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        // {'urls': 'stun:stun3.l.google.com:19302'},
        // {
        //   'urls': 'turn:openrelay.metered.ca',
        //   'username': 'openrelayproject',
        //   'credential': 'openrelayproject',
        // },
      ],
      // 'iceTransportPolicy': 'relay',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      _sendMessage({
        'janus': 'trickle',
        'session_id': _sessionId,
        'handle_id': _handleId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });

      print("VALUE OF CANDIDATE IS - ${candidate.candidate}");
    };

    _peerConnection!.onAddStream = (stream) {
      print('Remote stream added');
      _remoteStream = stream;
      _remoteStreamController.add(stream);
    };

    _peerConnection!.onConnectionState = (state) {
      print('Connection state: $state');
      _messageController.add('Connection state: $state');
    };
  }

  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (message['transaction'] == null) {
      message['transaction'] = _generateTransaction();
    }

    print('Sending: $message');
    _channel!.sink.add(jsonEncode(message));
  }

  String _generateTransaction() {
    return 'transaction_${Random().nextInt(999999)}';
  }

  MediaStream? get localStream => _localStream;

  Future<void> disconnect() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _channel?.sink.close();

    _messageController.close();
    _remoteStreamController.close();
  }

  Future<void> keepAlive() async {
    Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_channel != null && _sessionId > 0) {
        await _sendMessage({
          'janus': 'keepalive',
          'session_id': _sessionId,
        });
      } else {
        timer.cancel();
      }
    });
  }
}
