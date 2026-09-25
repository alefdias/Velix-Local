enum TransferStatus {
  idle,
  waiting,
  transferring,
  paused,
  completed,
  failed,
  canceled;

  String get displayName {
    switch (this) {
      case TransferStatus.idle:
        return 'Pronto';
      case TransferStatus.waiting:
        return 'Aguardando';
      case TransferStatus.transferring:
        return 'Transferindo';
      case TransferStatus.paused:
        return 'Pausado';
      case TransferStatus.completed:
        return 'Concluído';
      case TransferStatus.failed:
        return 'Falha';
      case TransferStatus.canceled:
        return 'Cancelado';
    }
  }
}

class TransferItem {
  final String id;
  final String sessionId;
  final String fileName;
  final String? localFilePath;
  final int fileSize;
  final String sourceDevice;
  final String targetDevice;
  final bool isIncoming;
  final DateTime startTime;
  final DateTime? endTime;
  final TransferStatus status;
  final int bytesTransferred;
  final double speedMbps;
  final int completedChunks;
  final int totalChunks;
  final String? errorMessage;
  final bool isSyncFile;

  TransferItem({
    required this.id,
    required this.sessionId,
    required this.fileName,
    this.localFilePath,
    required this.fileSize,
    required this.sourceDevice,
    required this.targetDevice,
    required this.isIncoming,
    required this.startTime,
    this.endTime,
    this.status = TransferStatus.waiting,
    this.bytesTransferred = 0,
    this.speedMbps = 0.0,
    this.completedChunks = 0,
    this.totalChunks = 1,
    this.errorMessage,
    this.isSyncFile = false,
  });

  double get progressPercentage {
    if (fileSize <= 0) return 0.0;
    final p = (bytesTransferred / fileSize).clamp(0.0, 1.0);
    return p;
  }

  String get formattedPercentage {
    return '${(progressPercentage * 100).toStringAsFixed(1)}%';
  }

  String get formattedSpeed {
    if (speedMbps < 0.1) return '0.0 MB/s';
    return '${speedMbps.toStringAsFixed(1)} MB/s';
  }

  String get remainingTimeFormatted {
    if (speedMbps <= 0.05 || bytesTransferred >= fileSize) return '--';
    final remainingBytes = fileSize - bytesTransferred;
    final bytesPerSec = speedMbps * 1024 * 1024;
    final seconds = (remainingBytes / bytesPerSec).round();
    if (seconds < 60) return '$seconds s restantes';
    final minutes = seconds ~/ 60;
    final remSecs = seconds % 60;
    return '$minutes m $remSecs s';
  }

  String get formattedFileSize {
    if (fileSize <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = fileSize.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String get formattedTransferredSize {
    if (bytesTransferred <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytesTransferred.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  TransferItem copyWith({
    String? id,
    String? sessionId,
    String? fileName,
    String? localFilePath,
    int? fileSize,
    String? sourceDevice,
    String? targetDevice,
    bool? isIncoming,
    DateTime? startTime,
    DateTime? endTime,
    TransferStatus? status,
    int? bytesTransferred,
    double? speedMbps,
    int? completedChunks,
    int? totalChunks,
    String? errorMessage,
    bool? isSyncFile,
  }) {
    return TransferItem(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      fileName: fileName ?? this.fileName,
      localFilePath: localFilePath ?? this.localFilePath,
      fileSize: fileSize ?? this.fileSize,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      targetDevice: targetDevice ?? this.targetDevice,
      isIncoming: isIncoming ?? this.isIncoming,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      speedMbps: speedMbps ?? this.speedMbps,
      completedChunks: completedChunks ?? this.completedChunks,
      totalChunks: totalChunks ?? this.totalChunks,
      errorMessage: errorMessage ?? this.errorMessage,
      isSyncFile: isSyncFile ?? this.isSyncFile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'file_name': fileName,
      'file_path': localFilePath,
      'file_size': fileSize,
      'source_device': sourceDevice,
      'target_device': targetDevice,
      'is_incoming': isIncoming ? 1 : 0,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status.name,
      'speed_mbps': speedMbps,
      'error_message': errorMessage,
    };
  }

  factory TransferItem.fromMap(Map<String, dynamic> map) {
    return TransferItem(
      id: map['id'] as String,
      sessionId: map['session_id'] as String? ?? map['id'] as String,
      fileName: map['file_name'] as String,
      localFilePath: map['file_path'] as String?,
      fileSize: map['file_size'] as int? ?? 0,
      sourceDevice: map['source_device'] as String,
      targetDevice: map['target_device'] as String,
      isIncoming: (map['is_incoming'] as int? ?? 0) == 1,
      startTime: DateTime.tryParse(map['start_time'] as String? ?? '') ?? DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'] as String) : null,
      status: TransferStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransferStatus.completed,
      ),
      speedMbps: (map['speed_mbps'] as num?)?.toDouble() ?? 0.0,
      errorMessage: map['error_message'] as String?,
      bytesTransferred: map['file_size'] as int? ?? 0,
    );
  }
}
