class ChunkProgress {
  final String sessionId;
  final String filePath;
  final int chunkIndex;
  final int totalChunks;
  final int chunkSize;
  final bool isCompleted;
  final String? chunkHash;
  final DateTime updatedAt;

  ChunkProgress({
    required this.sessionId,
    required this.filePath,
    required this.chunkIndex,
    required this.totalChunks,
    required this.chunkSize,
    required this.isCompleted,
    this.chunkHash,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'file_path': filePath,
      'chunk_index': chunkIndex,
      'total_chunks': totalChunks,
      'chunk_size': chunkSize,
      'is_completed': isCompleted ? 1 : 0,
      'chunk_hash': chunkHash,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ChunkProgress.fromMap(Map<String, dynamic> map) {
    return ChunkProgress(
      sessionId: map['session_id'] as String,
      filePath: map['file_path'] as String,
      chunkIndex: map['chunk_index'] as int,
      totalChunks: map['total_chunks'] as int,
      chunkSize: map['chunk_size'] as int,
      isCompleted: (map['is_completed'] as int) == 1,
      chunkHash: map['chunk_hash'] as String?,
      updatedAt: DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now(),
    );
  }
}
