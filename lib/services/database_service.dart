import 'dart:io';
import 'dart:ffi';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import '../models/device.dart';
import '../models/sync_folder.dart';
import '../models/transfer.dart';
import '../models/chunk_progress.dart';

DynamicLibrary _openSqliteOnLinux() {
  final candidates = [
    'libsqlite3.so',
    'libsqlite3.so.0',
    '/usr/lib64/libsqlite3.so.0',
    '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
    '/usr/lib/libsqlite3.so.0',
  ];
  for (final path in candidates) {
    try {
      return DynamicLibrary.open(path);
    } catch (_) {}
  }
  return DynamicLibrary.process();
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (Platform.isLinux) {
      open.overrideFor(OperatingSystem.linux, _openSqliteOnLinux);
    }

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      dbPath = p.join(appSupportDir.path, 'velix_local.db');
    } catch (_) {
      final documentsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(documentsDir.path, 'velix_local.db');
    }

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Dispositivos confiáveis
        await db.execute('''
          CREATE TABLE trusted_devices (
            device_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            os TEXT NOT NULL,
            ip TEXT NOT NULL,
            port INTEGER NOT NULL,
            is_trusted INTEGER NOT NULL DEFAULT 1,
            last_seen TEXT,
            paired_at TEXT
          )
        ''');

        // Pastas sincronizadas
        await db.execute('''
          CREATE TABLE sync_folders (
            id TEXT PRIMARY KEY,
            local_path TEXT NOT NULL,
            folder_name TEXT NOT NULL,
            remote_device_id TEXT NOT NULL,
            remote_device_name TEXT,
            is_paused INTEGER NOT NULL DEFAULT 0,
            last_synced_at TEXT,
            total_files INTEGER NOT NULL DEFAULT 0,
            total_size INTEGER NOT NULL DEFAULT 0,
            status_text TEXT
          )
        ''');

        // Arquivos de sincronização para detecção de alterações e exclusões
        await db.execute('''
          CREATE TABLE sync_files (
            id TEXT PRIMARY KEY,
            sync_folder_id TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            modified_time TEXT NOT NULL,
            checksum TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (sync_folder_id) REFERENCES sync_folders(id) ON DELETE CASCADE
          )
        ''');

        // Histórico de transferências
        await db.execute('''
          CREATE TABLE transfer_history (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT,
            file_size INTEGER NOT NULL,
            source_device TEXT NOT NULL,
            target_device TEXT NOT NULL,
            is_incoming INTEGER NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            status TEXT NOT NULL,
            speed_mbps REAL NOT NULL DEFAULT 0,
            error_message TEXT
          )
        ''');

        // Progresso de blocos para retomada
        await db.execute('''
          CREATE TABLE chunk_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            total_chunks INTEGER NOT NULL,
            chunk_size INTEGER NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            chunk_hash TEXT,
            updated_at TEXT NOT NULL,
            UNIQUE(session_id, chunk_index)
          )
        ''');

        // Configurações do app
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        // Apelidos/Renomeação de dispositivos para ambientes corporativos
        await db.execute('''
          CREATE TABLE IF NOT EXISTS device_aliases (
            device_id TEXT PRIMARY KEY,
            alias TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );

    // Garante que a tabela device_aliases exista mesmo se o banco já foi criado
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_aliases (
        device_id TEXT PRIMARY KEY,
        alias TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Garante que a tabela transfer_history exista mesmo em bancos já criados anteriormente
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transfer_history (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT,
        file_size INTEGER NOT NULL,
        source_device TEXT NOT NULL,
        target_device TEXT NOT NULL,
        is_incoming INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        status TEXT NOT NULL,
        speed_mbps REAL NOT NULL DEFAULT 0,
        error_message TEXT
      )
    ''');

    return db;
  }

  // --- Apelidos e Renomeação Corporativa ---

  Future<void> saveDeviceAlias(String deviceId, String alias) async {
    final db = await database;
    if (alias.trim().isEmpty) {
      await db.delete('device_aliases', where: 'device_id = ?', whereArgs: [deviceId]);
    } else {
      await db.insert(
        'device_aliases',
        {
          'device_id': deviceId,
          'alias': alias.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<String?> getDeviceAlias(String deviceId) async {
    final db = await database;
    final results = await db.query(
      'device_aliases',
      columns: ['alias'],
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['alias'] as String?;
  }

  Future<Map<String, String>> getAllDeviceAliases() async {
    final db = await database;
    final results = await db.query('device_aliases');
    final Map<String, String> map = {};
    for (final row in results) {
      map[row['device_id'] as String] = row['alias'] as String;
    }
    return map;
  }

  // --- Dispositivos Confiáveis ---

  Future<List<Device>> getTrustedDevices() async {
    final db = await database;
    final aliases = await getAllDeviceAliases();
    final maps = await db.query('trusted_devices', orderBy: 'paired_at DESC');
    return maps.map((m) {
      final dev = Device.fromMap(m);
      return dev.copyWith(customAlias: aliases[dev.id]);
    }).toList();
  }

  Future<Device?> getTrustedDevice(String deviceId) async {
    final db = await database;
    final maps = await db.query(
      'trusted_devices',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final dev = Device.fromMap(maps.first);
    final alias = await getDeviceAlias(deviceId);
    return dev.copyWith(customAlias: alias);
  }

  Future<bool> isDeviceTrusted(String deviceId) async {
    final dev = await getTrustedDevice(deviceId);
    return dev != null && dev.isTrusted;
  }

  Future<void> saveTrustedDevice(Device device) async {
    final db = await database;
    final map = device.toMap();
    map['paired_at'] = (device.pairedAt ?? DateTime.now()).toIso8601String();
    map['is_trusted'] = 1;
    await db.insert(
      'trusted_devices',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeTrustedDevice(String deviceId) async {
    final db = await database;
    await db.delete('trusted_devices', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  // --- Pastas Sincronizadas ---

  Future<List<SyncFolder>> getSyncFolders() async {
    final db = await database;
    final maps = await db.query('sync_folders', orderBy: 'folder_name ASC');
    return maps.map((m) => SyncFolder.fromMap(m)).toList();
  }

  Future<SyncFolder?> getSyncFolder(String id) async {
    final db = await database;
    final maps = await db.query('sync_folders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return SyncFolder.fromMap(maps.first);
  }

  Future<void> saveSyncFolder(SyncFolder folder) async {
    final db = await database;
    await db.insert('sync_folders', folder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSyncFolderStatus(String id, {
    String? statusText,
    DateTime? lastSyncedAt,
    int? totalFiles,
    int? totalSize,
    bool? isPaused,
  }) async {
    final db = await database;
    final Map<String, dynamic> updates = {};
    if (statusText != null) updates['status_text'] = statusText;
    if (lastSyncedAt != null) updates['last_synced_at'] = lastSyncedAt.toIso8601String();
    if (totalFiles != null) updates['total_files'] = totalFiles;
    if (totalSize != null) updates['total_size'] = totalSize;
    if (isPaused != null) updates['is_paused'] = isPaused ? 1 : 0;

    if (updates.isNotEmpty) {
      await db.update('sync_folders', updates, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteSyncFolder(String id) async {
    final db = await database;
    await db.delete('sync_files', where: 'sync_folder_id = ?', whereArgs: [id]);
    await db.delete('sync_folders', where: 'id = ?', whereArgs: [id]);
  }

  // --- Histórico de Transferências ---

  Future<List<TransferItem>> getTransferHistory({String? query}) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> maps;
      if (query != null && query.trim().isNotEmpty) {
        maps = await db.query(
          'transfer_history',
          where: 'file_name LIKE ? OR source_device LIKE ? OR target_device LIKE ?',
          whereArgs: ['%$query%', '%$query%', '%$query%'],
          orderBy: 'start_time DESC',
        );
      } else {
        maps = await db.query('transfer_history', orderBy: 'start_time DESC');
      }
      return maps.map((m) => TransferItem.fromMap(m)).toList();
    } catch (e, stack) {
      debugPrint('[DatabaseService] Erro ao carregar transfer_history: $e\n$stack');
      return [];
    }
  }

  Future<void> saveTransferHistory(TransferItem item) async {
    try {
      final db = await database;
      await db.insert('transfer_history', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('[DatabaseService] Transferência salva no histórico: ${item.fileName} (${item.status.name})');
    } catch (e, stack) {
      debugPrint('[DatabaseService] Erro ao salvar item em transfer_history: $e\n$stack');
    }
  }

  Future<void> clearHistory() async {
    try {
      final db = await database;
      await db.delete('transfer_history');
      debugPrint('[DatabaseService] Histórico limpo com sucesso.');
    } catch (e) {
      debugPrint('[DatabaseService] Erro ao limpar histórico: $e');
    }
  }

  // --- Progresso de Blocos (Chunks) para Retomada ---

  Future<void> markChunkCompleted(ChunkProgress chunk) async {
    final db = await database;
    await db.insert(
      'chunk_progress',
      chunk.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<int>> getCompletedChunkIndexes(String sessionId) async {
    final db = await database;
    final results = await db.query(
      'chunk_progress',
      columns: ['chunk_index'],
      where: 'session_id = ? AND is_completed = 1',
      whereArgs: [sessionId],
    );
    return results.map((r) => r['chunk_index'] as int).toList();
  }

  Future<void> clearChunkProgress(String sessionId) async {
    final db = await database;
    await db.delete('chunk_progress', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  // --- Configurações Locais ---

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
