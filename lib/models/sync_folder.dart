class SyncFolder {
  final String id;
  final String localPath;
  final String folderName;
  final String remoteDeviceId;
  final String remoteDeviceName;
  final bool isPaused;
  final DateTime? lastSyncedAt;
  final int totalFiles;
  final int totalSize;
  final String statusText;
  final bool isSyncing;

  SyncFolder({
    required this.id,
    required this.localPath,
    required this.folderName,
    required this.remoteDeviceId,
    this.remoteDeviceName = 'Dispositivo Pareado',
    this.isPaused = false,
    this.lastSyncedAt,
    this.totalFiles = 0,
    this.totalSize = 0,
    this.statusText = 'Pronto para sincronizar',
    this.isSyncing = false,
  });

  SyncFolder copyWith({
    String? id,
    String? localPath,
    String? folderName,
    String? remoteDeviceId,
    String? remoteDeviceName,
    bool? isPaused,
    DateTime? lastSyncedAt,
    int? totalFiles,
    int? totalSize,
    String? statusText,
    bool? isSyncing,
  }) {
    return SyncFolder(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      folderName: folderName ?? this.folderName,
      remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
      remoteDeviceName: remoteDeviceName ?? this.remoteDeviceName,
      isPaused: isPaused ?? this.isPaused,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      totalFiles: totalFiles ?? this.totalFiles,
      totalSize: totalSize ?? this.totalSize,
      statusText: statusText ?? this.statusText,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_path': localPath,
      'folder_name': folderName,
      'remote_device_id': remoteDeviceId,
      'remote_device_name': remoteDeviceName,
      'is_paused': isPaused ? 1 : 0,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'total_files': totalFiles,
      'total_size': totalSize,
      'status_text': statusText,
    };
  }

  factory SyncFolder.fromMap(Map<String, dynamic> map) {
    return SyncFolder(
      id: map['id'] as String,
      localPath: map['local_path'] as String,
      folderName: map['folder_name'] as String,
      remoteDeviceId: map['remote_device_id'] as String,
      remoteDeviceName: map['remote_device_name'] as String? ?? 'Dispositivo Pareado',
      isPaused: (map['is_paused'] as int? ?? 0) == 1,
      lastSyncedAt: map['last_synced_at'] != null ? DateTime.tryParse(map['last_synced_at'] as String) : null,
      totalFiles: map['total_files'] as int? ?? 0,
      totalSize: map['total_size'] as int? ?? 0,
      statusText: map['status_text'] as String? ?? 'Aguardando',
    );
  }

  String get humanReadableSize {
    if (totalSize <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = totalSize.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String get timeSinceLastSync {
    if (lastSyncedAt == null) return 'Nunca sincronizado';
    final diff = DateTime.now().difference(lastSyncedAt!);
    if (diff.inSeconds < 10) return 'Sincronizado há instantes';
    if (diff.inSeconds < 60) return 'Sincronizado há ${diff.inSeconds} segundos';
    if (diff.inMinutes < 60) return 'Sincronizado há ${diff.inMinutes} minuto${diff.inMinutes > 1 ? 's' : ''}';
    if (diff.inHours < 24) return 'Sincronizado há ${diff.inHours} hora${diff.inHours > 1 ? 's' : ''}';
    return 'Sincronizado há ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
  }
}
