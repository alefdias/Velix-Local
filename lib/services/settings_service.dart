import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'database_service.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  String _deviceId = '';
  String _deviceName = '';
  int _httpPort = 53318;
  final int _discoveryPort = 53317;
  String _downloadDirectory = '';
  String _themeMode = 'light'; // 'system', 'light', 'dark'
  bool _autoSyncEnabled = true;
  bool _isInitialized = false;

  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  int get httpPort => _httpPort;
  int get discoveryPort => _discoveryPort;
  String get downloadDirectory => _downloadDirectory;
  String get themeMode => _themeMode;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    final db = DatabaseService.instance;

    // Device ID
    var storedId = await db.getSetting('device_id');
    if (storedId == null || storedId.isEmpty) {
      storedId = const Uuid().v4();
      await db.setSetting('device_id', storedId);
    }
    _deviceId = storedId;

    // Device Name
    var storedName = await db.getSetting('device_name');
    if (storedName == null || storedName.isEmpty) {
      storedName = await _resolveDefaultDeviceName();
      await db.setSetting('device_name', storedName);
    }
    _deviceName = storedName;

    // HTTP Port
    final storedPort = await db.getSetting('http_port');
    if (storedPort != null) {
      _httpPort = int.tryParse(storedPort) ?? 53318;
    }

    // Download Directory - Garantir pasta pública visível pelo usuário
    var storedDownloadDir = await db.getSetting('download_dir');
    bool isInvalidAndroidPath = Platform.isAndroid &&
        (storedDownloadDir != null && (storedDownloadDir.contains('/data/user/0') || storedDownloadDir.contains('app_flutter')));

    if (storedDownloadDir == null || storedDownloadDir.isEmpty || isInvalidAndroidPath) {
      storedDownloadDir = await _resolveDefaultDownloadDirectory();
      await db.setSetting('download_dir', storedDownloadDir);
    }
    _downloadDirectory = storedDownloadDir;

    // Theme Mode
    final storedTheme = await db.getSetting('theme_mode');
    if (storedTheme != null && storedTheme == 'system') {
      _themeMode = 'system';
    } else {
      _themeMode = 'light';
      await db.setSetting('theme_mode', 'light');
    }

    // Auto Sync
    final storedAutoSync = await db.getSetting('auto_sync');
    if (storedAutoSync != null) {
      _autoSyncEnabled = storedAutoSync == '1';
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<String> _resolveDefaultDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.prettyName.isNotEmpty ? linuxInfo.prettyName : Platform.localHostname;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        return winInfo.computerName.isNotEmpty ? winInfo.computerName : Platform.localHostname;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.computerName.isNotEmpty ? macInfo.computerName : Platform.localHostname;
      }
    } catch (_) {}
    return Platform.localHostname.isNotEmpty ? Platform.localHostname : 'Velix Node';
  }

  Future<String> _resolveDefaultDownloadDirectory() async {
    // 1. Android: Salvar diretamente na pasta pública Downloads do dispositivo
    if (Platform.isAndroid) {
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download/VelixLocal');
        if (!publicDownloadDir.existsSync()) {
          publicDownloadDir.createSync(recursive: true);
        }
        return publicDownloadDir.path;
      } catch (_) {
        try {
          final rootDownload = Directory('/storage/emulated/0/Download');
          if (rootDownload.existsSync()) {
            return rootDownload.path;
          }
        } catch (_) {}
      }
    }

    // 2. Linux: ~/Downloads
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final linuxDownloads = Directory('$home/Downloads');
        if (linuxDownloads.existsSync()) {
          return linuxDownloads.path;
        }
      }
    }

    // 3. Windows: %USERPROFILE%\Downloads
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final winDownloads = Directory('$userProfile\\Downloads');
        if (winDownloads.existsSync()) {
          return winDownloads.path;
        }
      }
    }

    // 4. macOS / Fallback genérico via path_provider
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && downloads.existsSync()) {
        return downloads.path;
      }
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      return docs.path;
    } catch (_) {
      return Directory.current.path;
    }
  }

  Future<void> setDeviceName(String newName) async {
    _deviceName = newName.trim();
    await DatabaseService.instance.setSetting('device_name', _deviceName);
    notifyListeners();
  }

  Future<void> setHttpPort(int newPort) async {
    _httpPort = newPort;
    await DatabaseService.instance.setSetting('http_port', newPort.toString());
    notifyListeners();
  }

  Future<void> setDownloadDirectory(String dirPath) async {
    _downloadDirectory = dirPath;
    await DatabaseService.instance.setSetting('download_dir', dirPath);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await DatabaseService.instance.setSetting('theme_mode', mode);
    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    await DatabaseService.instance.setSetting('auto_sync', enabled ? '1' : '0');
    notifyListeners();
  }
}
