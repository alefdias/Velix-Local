import 'dart:io';

enum DevicePlatformType {
  windows,
  linux,
  android,
  macos,
  ios,
  web,
  unknown;

  static DevicePlatformType fromString(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('windows')) return DevicePlatformType.windows;
    if (lower.contains('linux')) return DevicePlatformType.linux;
    if (lower.contains('android')) return DevicePlatformType.android;
    if (lower.contains('macos') || lower.contains('darwin')) return DevicePlatformType.macos;
    if (lower.contains('ios')) return DevicePlatformType.ios;
    return DevicePlatformType.unknown;
  }

  static DevicePlatformType currentPlatform() {
    if (Platform.isWindows) return DevicePlatformType.windows;
    if (Platform.isLinux) return DevicePlatformType.linux;
    if (Platform.isAndroid) return DevicePlatformType.android;
    if (Platform.isMacOS) return DevicePlatformType.macos;
    if (Platform.isIOS) return DevicePlatformType.ios;
    return DevicePlatformType.unknown;
  }

  String get displayName {
    switch (this) {
      case DevicePlatformType.windows:
        return 'Windows';
      case DevicePlatformType.linux:
        return 'Linux';
      case DevicePlatformType.android:
        return 'Android';
      case DevicePlatformType.macos:
        return 'macOS';
      case DevicePlatformType.ios:
        return 'iOS';
      case DevicePlatformType.web:
        return 'Web';
      case DevicePlatformType.unknown:
        return 'Desconhecido';
    }
  }
}

class Device {
  final String id;
  final String name;
  final String? customAlias; // Apelido corporativo (ex: "Computador X - Financeiro")
  final DevicePlatformType platform;
  final String ip;
  final int port;
  final bool isTrusted;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? pairedAt;

  Device({
    required this.id,
    required this.name,
    this.customAlias,
    required this.platform,
    required this.ip,
    required this.port,
    this.isTrusted = false,
    this.isOnline = true,
    this.lastSeen,
    this.pairedAt,
  });

  String get hostAddress => '$ip:$port';

  String get resolvedName {
    if (customAlias != null && customAlias!.trim().isNotEmpty) {
      return customAlias!.trim();
    }
    return name;
  }

  String get fullDisplayName {
    if (customAlias != null && customAlias!.trim().isNotEmpty && customAlias != name) {
      return '$customAlias ($name)';
    }
    return name;
  }

  Device copyWith({
    String? id,
    String? name,
    String? customAlias,
    DevicePlatformType? platform,
    String? ip,
    int? port,
    bool? isTrusted,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? pairedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      customAlias: customAlias ?? this.customAlias,
      platform: platform ?? this.platform,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      isTrusted: isTrusted ?? this.isTrusted,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': id,
      'name': name,
      'custom_alias': customAlias,
      'os': platform.displayName,
      'ip': ip,
      'port': port,
      'is_trusted': isTrusted ? 1 : 0,
      'last_seen': (lastSeen ?? DateTime.now()).toIso8601String(),
      'paired_at': pairedAt?.toIso8601String(),
    };
  }

  factory Device.fromMap(Map<String, dynamic> map, {bool isOnline = false}) {
    return Device(
      id: map['device_id'] as String,
      name: map['name'] as String,
      customAlias: map['custom_alias'] as String?,
      platform: DevicePlatformType.fromString(map['os'] as String? ?? 'unknown'),
      ip: map['ip'] as String? ?? '',
      port: map['port'] as int? ?? 53318,
      isTrusted: (map['is_trusted'] as int? ?? 0) == 1,
      isOnline: isOnline,
      lastSeen: map['last_seen'] != null ? DateTime.tryParse(map['last_seen'] as String) : null,
      pairedAt: map['paired_at'] != null ? DateTime.tryParse(map['paired_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJsonBroadcast() {
    return {
      'id': id,
      'name': name,
      'os': platform.displayName,
      'port': port,
    };
  }

  factory Device.fromJsonBroadcast(Map<String, dynamic> json, String remoteIp) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: DevicePlatformType.fromString(json['os'] as String? ?? 'unknown'),
      ip: remoteIp,
      port: json['port'] as int? ?? 53318,
      isTrusted: false,
      isOnline: true,
      lastSeen: DateTime.now(),
    );
  }
}
