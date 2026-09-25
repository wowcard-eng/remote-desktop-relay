import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_models.dart';

class StorageService {
  static const String _keyServerUrl = 'relay_server_url';
  static const String _keyPartnerId = 'my_partner_id';
  static const String _keyPin = 'my_pin';
  static const String _keyRecentConnections = 'recent_connections';
  static const String _keyQuality = 'stream_quality';
  static const String _keyControlMode = 'control_mode';
  static const String _keySensitivity = 'mouse_sensitivity';

  static const String defaultRelayUrl = 'ws://10.212.90.238:8080';

  static Future<String> getRelayUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? defaultRelayUrl;
  }

  static Future<void> setRelayUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url.trim());
  }

  static Future<String?> getSavedPartnerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPartnerId);
  }

  static Future<void> savePartnerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPartnerId, id);
  }

  static Future<String?> getSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPin);
  }

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
  }

  static Future<List<RecentConnection>> getRecentConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyRecentConnections);
    if (raw == null) return [];
    try {
      return raw.map((item) => RecentConnection.fromJson(jsonDecode(item))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addRecentConnection(RecentConnection conn) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getRecentConnections();
    list.removeWhere((item) => item.partnerId == conn.partnerId);
    list.insert(0, conn);
    if (list.length > 10) list.removeRange(10, list.length);

    final encoded = list.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_keyRecentConnections, encoded);
  }

  static Future<void> clearRecentConnections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecentConnections);
  }

  static Future<StreamQuality> getQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyQuality) ?? StreamQuality.balanced.index;
    return StreamQuality.values[index.clamp(0, StreamQuality.values.length - 1)];
  }

  static Future<void> setQuality(StreamQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyQuality, quality.index);
  }

  static Future<ControlMode> getControlMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyControlMode) ?? ControlMode.directTouch.index;
    return ControlMode.values[index.clamp(0, ControlMode.values.length - 1)];
  }

  static Future<void> setControlMode(ControlMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyControlMode, mode.index);
  }

  static Future<double> getSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySensitivity) ?? 1.0;
  }

  static Future<void> setSensitivity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySensitivity, value);
  }
}
