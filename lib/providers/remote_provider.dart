import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/session_models.dart';
import '../services/relay_service.dart';
import '../services/storage_service.dart';

enum ConnectionStateStatus {
  idle,
  connecting,
  connected,
  error,
}

class RemoteProvider extends ChangeNotifier {
  final RelayService relayService = RelayService();

  ConnectionStateStatus _status = ConnectionStateStatus.idle;
  ConnectionStateStatus get status => _status;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _relayUrl = StorageService.defaultRelayUrl;
  String get relayUrl => _relayUrl;

  String _myPartnerId = '';
  String get myPartnerId => _myPartnerId;

  String _myPin = '';
  String get myPin => _myPin;

  StreamQuality _quality = StreamQuality.balanced;
  StreamQuality get quality => _quality;

  ControlMode _controlMode = ControlMode.directTouch;
  ControlMode get controlMode => _controlMode;

  double _sensitivity = 1.0;
  double get sensitivity => _sensitivity;

  List<RecentConnection> _recentConnections = [];
  List<RecentConnection> get recentConnections => _recentConnections;

  RemoteScreenInfo? get screenInfo => relayService.screenInfo;
  bool get isSessionActive => relayService.isConnected;

  Timer? _statsTimer;

  RemoteProvider() {
    _init();
  }

  Future<void> _init() async {
    _relayUrl = await StorageService.getRelayUrl();
    _quality = await StorageService.getQuality();
    _controlMode = await StorageService.getControlMode();
    _sensitivity = await StorageService.getSensitivity();
    _recentConnections = await StorageService.getRecentConnections();

    // Load or generate my Partner ID & PIN
    final savedId = await StorageService.getSavedPartnerId();
    if (savedId != null && savedId.isNotEmpty) {
      _myPartnerId = savedId;
    } else {
      _myPartnerId = _generateRandomId();
      await StorageService.savePartnerId(_myPartnerId);
    }

    final savedPin = await StorageService.getSavedPin();
    if (savedPin != null && savedPin.isNotEmpty) {
      _myPin = savedPin;
    } else {
      _myPin = _generateRandomPin();
      await StorageService.savePin(_myPin);
    }

    // Listen to session status
    relayService.statusStream.listen((event) {
      if (event == 'disconnected' || event == 'session_closed') {
        _status = ConnectionStateStatus.idle;
        _statsTimer?.cancel();
        notifyListeners();
      }
    });

    notifyListeners();
  }

  String _generateRandomId() {
    final rnd = Random();
    final a = rnd.nextInt(900) + 100;
    final b = rnd.nextInt(900) + 100;
    final c = rnd.nextInt(900) + 100;
    return '$a$b$c';
  }

  String _generateRandomPin() {
    final rnd = Random();
    return (rnd.nextInt(9000) + 1000).toString();
  }

  void refreshMyPin() async {
    _myPin = _generateRandomPin();
    await StorageService.savePin(_myPin);
    notifyListeners();
  }

  Future<void> setRelayUrl(String url) async {
    _relayUrl = url.trim();
    await StorageService.setRelayUrl(_relayUrl);
    notifyListeners();
  }

  Future<void> setQuality(StreamQuality q) async {
    _quality = q;
    await StorageService.setQuality(q);
    if (isSessionActive) {
      relayService.sendQualityChange(q);
    }
    notifyListeners();
  }

  Future<void> setControlMode(ControlMode m) async {
    _controlMode = m;
    await StorageService.setControlMode(m);
    notifyListeners();
  }

  Future<void> setSensitivity(double s) async {
    _sensitivity = s;
    await StorageService.setSensitivity(s);
    notifyListeners();
  }

  Future<bool> connect({
    required String partnerId,
    required String pin,
    String? clientName,
  }) async {
    final cleanId = partnerId.replaceAll(' ', '').trim();
    if (cleanId.length < 6) {
      _errorMessage = 'Invalid Partner ID';
      _status = ConnectionStateStatus.error;
      notifyListeners();
      return false;
    }

    _status = ConnectionStateStatus.connecting;
    _errorMessage = '';
    notifyListeners();

    final completer = Completer<bool>();

    await relayService.connectToHost(
      relayUrl: _relayUrl,
      partnerId: cleanId,
      pin: pin,
      clientName: clientName ?? (kIsWeb ? 'Web Client' : 'Mobile Client'),
      onSuccess: (info) async {
        _status = ConnectionStateStatus.connected;

        // Save to recent connections
        final recent = RecentConnection(
          partnerId: cleanId,
          deviceName: info.deviceName,
          lastConnected: DateTime.now(),
        );
        await StorageService.addRecentConnection(recent);
        _recentConnections = await StorageService.getRecentConnections();

        // Send preferred quality
        relayService.sendQualityChange(_quality);

        // Start stats refresh timer
        _statsTimer?.cancel();
        _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          notifyListeners();
        });

        notifyListeners();
        completer.complete(true);
      },
      onError: (err) {
        _status = ConnectionStateStatus.error;
        _errorMessage = err;
        notifyListeners();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    return completer.future;
  }

  Future<void> disconnect() async {
    _statsTimer?.cancel();
    await relayService.disconnect();
    _status = ConnectionStateStatus.idle;
    notifyListeners();
  }

  Future<void> clearRecentHistory() async {
    await StorageService.clearRecentConnections();
    _recentConnections = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    relayService.dispose();
    super.dispose();
  }
}
