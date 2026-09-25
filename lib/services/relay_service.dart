import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/session_models.dart';

class RelayService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final _frameController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get frameStream => _frameController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  RemoteScreenInfo? _screenInfo;
  RemoteScreenInfo? get screenInfo => _screenInfo;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _pingTimer;
  int _lastPingSent = 0;
  int _currentPingMs = 0;
  int get currentPingMs => _currentPingMs;

  int _framesReceived = 0;
  int _fps = 0;
  int get fps => _fps;
  Timer? _fpsTimer;

  int _bytesPerSec = 0;
  int get bytesPerSec => _bytesPerSec;
  int _currentByteCount = 0;

  Future<void> connectToHost({
    required String relayUrl,
    required String partnerId,
    required String pin,
    required String clientName,
    required Function(RemoteScreenInfo info) onSuccess,
    required Function(String error) onError,
  }) async {
    await disconnect();

    try {
      final uri = Uri.parse(relayUrl);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (message) {
          if (message is Uint8List) {
            _framesReceived++;
            _currentByteCount += message.length;
            _frameController.add(message);
          } else if (message is List<int>) {
            final bytes = Uint8List.fromList(message);
            _framesReceived++;
            _currentByteCount += bytes.length;
            _frameController.add(bytes);
          } else if (message is String) {
            _handleTextMessage(message, onSuccess, onError);
          }
        },
        onError: (err) {
          _isConnected = false;
          onError('Connection error: $err');
          _cleanUp();
        },
        onDone: () {
          _isConnected = false;
          _statusController.add('disconnected');
          _cleanUp();
        },
      );

      // Clean ID format (remove spaces)
      final cleanId = partnerId.replaceAll(' ', '');

      // Send connection handshake
      final connectPayload = {
        'type': 'connect_host',
        'partnerId': cleanId,
        'pin': pin.trim(),
        'clientName': clientName,
      };

      _channel!.sink.add(jsonEncode(connectPayload));

      // Start Ping & FPS counters
      _startDiagnostics();

    } catch (e) {
      _isConnected = false;
      onError('Failed to connect to relay: $e');
    }
  }

  void _handleTextMessage(
    String raw,
    Function(RemoteScreenInfo info) onSuccess,
    Function(String error) onError,
  ) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'connected':
          _isConnected = true;
          _screenInfo = RemoteScreenInfo.fromJson(data);
          _statusController.add('connected');
          onSuccess(_screenInfo!);
          break;

        case 'connect_failed':
          _isConnected = false;
          final msg = data['message'] as String? ?? 'Failed to connect to partner';
          onError(msg);
          disconnect();
          break;

        case 'session_closed':
          _isConnected = false;
          _statusController.add('session_closed');
          disconnect();
          break;

        case 'pong':
          final sent = data['timestamp'] as int? ?? 0;
          if (sent > 0) {
            _currentPingMs = DateTime.now().millisecondsSinceEpoch - sent;
          }
          break;

        case 'clipboard':
          // Clipboard received from host
          break;
      }
    } catch (_) {}
  }

  void _startDiagnostics() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isConnected && _channel != null) {
        _lastPingSent = DateTime.now().millisecondsSinceEpoch;
        _sendJson({'type': 'ping', 'timestamp': _lastPingSent});
      }
    });

    _fpsTimer?.cancel();
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fps = _framesReceived;
      _framesReceived = 0;
      _bytesPerSec = _currentByteCount;
      _currentByteCount = 0;
    });
  }

  void _sendJson(Map<String, dynamic> payload) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(payload));
      } catch (_) {}
    }
  }

  // ==================== Input Event Dispatchers ====================
  void sendMouseMove(double normX, double normY) {
    _sendJson({
      'type': 'input',
      'action': 'move',
      'x': normX.clamp(0.0, 1.0),
      'y': normY.clamp(0.0, 1.0),
    });
  }

  void sendMouseDown(String button) {
    _sendJson({
      'type': 'input',
      'action': 'mouse_down',
      'button': button, // 'left' | 'right' | 'middle'
    });
  }

  void sendMouseUp(String button) {
    _sendJson({
      'type': 'input',
      'action': 'mouse_up',
      'button': button,
    });
  }

  void sendMouseClick(String button, {bool doubleClick = false}) {
    _sendJson({
      'type': 'input',
      'action': 'click',
      'button': button,
      'double': doubleClick,
    });
  }

  void sendMouseScroll(double deltaY) {
    _sendJson({
      'type': 'input',
      'action': 'scroll',
      'deltaY': deltaY,
    });
  }

  void sendKeyDown(int vk) {
    _sendJson({
      'type': 'input',
      'action': 'key_down',
      'vk': vk,
    });
  }

  void sendKeyUp(int vk) {
    _sendJson({
      'type': 'input',
      'action': 'key_up',
      'vk': vk,
    });
  }

  void sendKey(String key) {
    _sendJson({
      'type': 'input',
      'action': 'press_key',
      'key': key,
    });
  }

  void sendText(String text) {
    _sendJson({
      'type': 'input',
      'action': 'type_text',
      'text': text,
    });
  }

  void sendShortcut(String shortcutName) {
    _sendJson({
      'type': 'input',
      'action': 'shortcut',
      'name': shortcutName, // 'win' | 'alt_tab' | 'win_d' | 'esc' | 'ctrl_c' | 'ctrl_v'
    });
  }

  void sendQualityChange(StreamQuality quality) {
    _sendJson({
      'type': 'control',
      'quality': quality.jpegQuality,
      'scale': quality.scale,
      'fps': quality.fps,
    });
  }

  void sendClipboard(String text) {
    _sendJson({
      'type': 'clipboard',
      'text': text,
    });
  }

  Future<void> disconnect() async {
    _sendJson({'type': 'disconnect_session'});
    _isConnected = false;
    _cleanUp();
  }

  void _cleanUp() {
    _pingTimer?.cancel();
    _fpsTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    disconnect();
    _frameController.close();
    _statusController.close();
  }
}
