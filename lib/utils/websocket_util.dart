import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketSingleton {
  static final WebSocketSingleton _instance = WebSocketSingleton._internal();
  WebSocketChannel? _channel;
  StreamController<Uint8List>? _bufferedStreamController;
  Stream<Uint8List>? _bufferedStream;
  Timer? _bufferClearTimer;
  List<Uint8List> _buffer = [];

  factory WebSocketSingleton() {
    return _instance;
  }

  WebSocketSingleton._internal();

  Future<bool> connect(String ip) async {
    try {
      if (_channel == null) {
        _channel = WebSocketChannel.connect(Uri.parse("ws://$ip"));
        _bufferedStreamController = StreamController<Uint8List>();
        _bufferedStream = _bufferedStreamController!.stream.asBroadcastStream();
        _channel!.stream.listen(
              (data) {
            if (data is Uint8List) {
              _buffer.add(data);
              _bufferedStreamController!.add(data);
            } else {
              print('Received data is not of type Uint8List');
            }
          },
          onError: (error) {
            print('Connection error: $error');
          },
          onDone: () {
            print('Connection closed');
          },
        );

        // Start the buffer clear timer
        _startBufferClearTimer();
      }
      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  void _startBufferClearTimer() {
    _bufferClearTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_buffer.length > 10) {
        _buffer.removeRange(_buffer.length - 10, _buffer.length);
        print('Last 10 items cleared from buffer');
      }
    });
  }

  Stream<Uint8List>? get stream => _bufferedStream;

  WebSocketChannel? get channel => _channel;

  void close() {
    _channel?.sink.close();
    _channel = null;
    _bufferedStreamController?.close();
    _bufferedStreamController = null;
    _bufferedStream = null;
    _bufferClearTimer?.cancel();
    _bufferClearTimer = null;
    _buffer.clear();
  }

  void dispose() {
    close();
  }
}