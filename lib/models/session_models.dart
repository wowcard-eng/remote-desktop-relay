/// Data models for Remote Desktop Sessions and Events

enum StreamQuality {
  low,
  balanced,
  high;

  int get jpegQuality {
    switch (this) {
      case StreamQuality.low:
        return 45;
      case StreamQuality.balanced:
        return 65;
      case StreamQuality.high:
        return 85;
    }
  }

  double get scale {
    switch (this) {
      case StreamQuality.low:
        return 0.6;
      case StreamQuality.balanced:
        return 0.75;
      case StreamQuality.high:
        return 1.0;
    }
  }

  int get fps {
    switch (this) {
      case StreamQuality.low:
        return 20;
      case StreamQuality.balanced:
        return 30;
      case StreamQuality.high:
        return 45;
    }
  }
}

enum ControlMode {
  directTouch, // Tap directly translates to desktop coordinate
  trackpad     // Touch acts like a laptop trackpad controlling a cursor
}

class RecentConnection {
  final String partnerId;
  final String deviceName;
  final DateTime lastConnected;

  RecentConnection({
    required this.partnerId,
    required this.deviceName,
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
    'partnerId': partnerId,
    'deviceName': deviceName,
    'lastConnected': lastConnected.toIso8601String(),
  };

  factory RecentConnection.fromJson(Map<String, dynamic> json) => RecentConnection(
    partnerId: json['partnerId'] as String,
    deviceName: json['deviceName'] as String? ?? 'Remote Computer',
    lastConnected: DateTime.tryParse(json['lastConnected'] as String? ?? '') ?? DateTime.now(),
  );
}

class RemoteScreenInfo {
  final int width;
  final int height;
  final String deviceName;
  final String partnerId;

  RemoteScreenInfo({
    required this.width,
    required this.height,
    required this.deviceName,
    required this.partnerId,
  });

  factory RemoteScreenInfo.fromJson(Map<String, dynamic> json) => RemoteScreenInfo(
    width: json['width'] as int? ?? 1920,
    height: json['height'] as int? ?? 1080,
    deviceName: json['deviceName'] as String? ?? 'Remote PC',
    partnerId: json['partnerId'] as String? ?? '',
  );
}

class SessionStats {
  int pingMs = 0;
  int fps = 0;
  int bytesReceived = 0;
  DateTime lastReset = DateTime.now();

  void updateBytes(int count) {
    bytesReceived += count;
  }
}
