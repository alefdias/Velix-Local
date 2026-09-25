import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';
import 'package:uuid/uuid.dart';

import '../models/sync_folder.dart';
import '../models/device.dart';
import 'database_service.dart';
import 'settings_service.dart';
import 'mdns_service.dart';
import 'chunk_transfer_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final List<SyncFolder> _folders = [];
  final Map<String, StreamSubscription> _watchers = {};
  final Map<String, Timer> _debounceTimers = {};
  Timer? _periodicSyncTimer;
  bool _isSyncingAny = false;

  List<SyncFolder> get folders => List.unmodifiable(_folders);
  bool get isSyncingAny => _isSyncingAny;

  Future<void> init() async {
    await loadFolders();

    // Sincronização periódica a cada 20 segundos para verificar consistência
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (SettingsService.instance.autoSyncEnabled) {
        syncAllActiveFolders();
      }
    });
  }

  Future<void> loadFolders() async {
    final list = await DatabaseService.instance.getSyncFolders();
    _folders.clear();
    _folders.addAll(list);

    // Iniciar watchers para as pastas ativas
    for (final folder in _folders) {
      if (!folder.isPaused) {
        _startWatchingFolder(folder);
      }
    }
    notifyListeners();
  }

  Future<void> addSyncFolder({
    required String localPath,
    required String folderName,
    required Device targetDevice,
  }) async {
    final id = const Uuid().v4();
    final dir = Directory(localPath);
    int totalFiles = 0;
    int totalSize = 0;

    if (await dir.exists()) {
      try {
        final entities = dir.listSync(recursive: true);
        for (final e in entities) {
          if (e is File) {
            totalFiles++;
            totalSize += e.lengthSync();
          }
        }
      } catch (_) {}
    }

    final newFolder = SyncFolder(
      id: id,
      localPath: localPath,
      folderName: folderName,
      remoteDeviceId: targetDevice.id,
      remoteDeviceName: targetDevice.name,
      isPaused: false,
      lastSyncedAt: null,
      totalFiles: totalFiles,
      totalSize: totalSize,
      statusText: 'Configurado com sucesso',
    );

    await DatabaseService.instance.saveSyncFolder(newFolder);
    _folders.add(newFolder);
    _startWatchingFolder(newFolder);
    notifyListeners();

    // Sincronizar imediatamente após adicionar
    await syncFolder(newFolder.id);
  }

  void _startWatchingFolder(SyncFolder folder) {
    _watchers[folder.id]?.cancel();

    final dir = Directory(folder.localPath);
    if (!dir.existsSync()) return;

    try {
      final watcher = DirectoryWatcher(folder.localPath);
      _watchers[folder.id] = watcher.events.listen((event) {
        _handleFileChangeEvent(folder, event);
      });
      debugPrint('[SyncService] Monitorando pasta: ${folder.folderName} (${folder.localPath})');
    } catch (e) {
      debugPrint('[SyncService] Erro ao monitorar pasta ${folder.localPath}: $e');
    }
  }

  void _handleFileChangeEvent(SyncFolder folder, WatchEvent event) {
    if (folder.isPaused) return;

    // Ignora arquivos temporários e de controle do Velix
    if (event.path.contains('.velix_part') ||
        event.path.endsWith('.tmp') ||
        event.path.endsWith('~') ||
        p.basename(event.path).startsWith('.')) {
      return;
    }

    // Debounce de 1.5s para aguardar término da gravação
    _debounceTimers[folder.id]?.cancel();
    _debounceTimers[folder.id] = Timer(const Duration(milliseconds: 1500), () {
      debugPrint('[SyncService] Mudança detectada em ${folder.folderName}: ${event.type} -> ${event.path}');
      syncFolder(folder.id);
    });
  }

  Future<void> togglePauseFolder(String id) async {
    final index = _folders.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final current = _folders[index];
    final newPaused = !current.isPaused;

    if (newPaused) {
      _watchers[id]?.cancel();
      _watchers.remove(id);
    }

    await DatabaseService.instance.updateSyncFolderStatus(
      id,
      isPaused: newPaused,
      statusText: newPaused ? 'Sincronização pausada' : 'Pronto para sincronizar',
    );

    _folders[index] = current.copyWith(
      isPaused: newPaused,
      statusText: newPaused ? 'Sincronização pausada' : 'Pronto para sincronizar',
    );

    if (!newPaused) {
      _startWatchingFolder(_folders[index]);
      await syncFolder(id);
    }

    notifyListeners();
  }

  Future<void> removeFolder(String id) async {
    _watchers[id]?.cancel();
    _watchers.remove(id);
    _debounceTimers[id]?.cancel();
    _debounceTimers.remove(id);

    await DatabaseService.instance.deleteSyncFolder(id);
    _folders.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  Future<void> syncAllActiveFolders() async {
    for (final folder in _folders) {
      if (!folder.isPaused) {
        await syncFolder(folder.id);
      }
    }
  }

  Future<void> syncFolder(String folderId) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index == -1) return;

    var folder = _folders[index];
    if (folder.isPaused || folder.isSyncing) return;

    // Verificar se o dispositivo remoto está online
    final targetDevice = MdnsDiscoveryService.instance.devices.firstWhere(
      (d) => d.id == folder.remoteDeviceId,
      orElse: () => Device(
        id: folder.remoteDeviceId,
        name: folder.remoteDeviceName,
        platform: DevicePlatformType.unknown,
        ip: '',
        port: 53318,
        isOnline: false,
      ),
    );

    if (!targetDevice.isOnline || targetDevice.ip.isEmpty) {
      _folders[index] = folder.copyWith(
        statusText: 'Aguardando dispositivo conectar...',
        isSyncing: false,
      );
      notifyListeners();
      return;
    }

    // Atualizar status para "Sincronizando..."
    _folders[index] = folder.copyWith(
      isSyncing: true,
      statusText: 'Sincronizando arquivos...',
    );
    _isSyncingAny = true;
    notifyListeners();

    try {
      final localDir = Directory(folder.localPath);
      if (!await localDir.exists()) {
        throw Exception('Pasta local não encontrada: ${folder.localPath}');
      }

      int fileCount = 0;
      int totalBytes = 0;
      final fileEntities = localDir.listSync(recursive: true);

      for (final entity in fileEntities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('.') || fileName.endsWith('.velix_part')) {
            continue;
          }

          fileCount++;
          final fSize = entity.lengthSync();
          totalBytes += fSize;

          // Enviar arquivo em blocos para a pasta remota
          await ChunkTransferService.instance.sendFile(
            targetDevice: targetDevice,
            file: entity,
            isSync: true,
            targetFolder: folder.folderName,
          );
        }
      }

      final now = DateTime.now();
      await DatabaseService.instance.updateSyncFolderStatus(
        folder.id,
        statusText: 'Sincronizado há instantes',
        lastSyncedAt: now,
        totalFiles: fileCount,
        totalSize: totalBytes,
      );

      _folders[index] = folder.copyWith(
        isSyncing: false,
        lastSyncedAt: now,
        totalFiles: fileCount,
        totalSize: totalBytes,
        statusText: 'Sincronizado há instantes',
      );
    } catch (e) {
      debugPrint('[SyncService] Erro ao sincronizar ${folder.folderName}: $e');
      _folders[index] = folder.copyWith(
        isSyncing: false,
        statusText: 'Falha na sincronização: $e',
      );
    } finally {
      _isSyncingAny = _folders.any((f) => f.isSyncing);
      notifyListeners();
    }
  }

  void stop() {
    _periodicSyncTimer?.cancel();
    for (final sub in _watchers.values) {
      sub.cancel();
    }
    _watchers.clear();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }
}
