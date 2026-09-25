import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/device.dart';
import 'settings_service.dart';

enum DeployStatus {
  idle,
  uploading,
  installing,
  success,
  error,
}

class DeployTask {
  final Device targetDevice;
  DeployStatus status;
  double progress;
  String? message;
  DateTime startedAt;

  DeployTask({
    required this.targetDevice,
    this.status = DeployStatus.idle,
    this.progress = 0.0,
    this.message,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();
}

class DeployService extends ChangeNotifier {
  static final DeployService instance = DeployService._internal();
  DeployService._internal();

  final List<DeployTask> _currentTasks = [];
  List<DeployTask> get currentTasks => List.unmodifiable(_currentTasks);

  bool _isDeploying = false;
  bool get isDeploying => _isDeploying;

  // Sugestão de argumentos silenciosos baseado na extensão do arquivo
  static String suggestSilentArguments(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.msi':
        return '/quiet /qn /norestart';
      case '.exe':
        return '/S /silent /quiet /qn';
      case '.rpm':
        return '-Uvh --replacepkgs';
      case '.deb':
        return '-i';
      case '.sh':
        return '';
      default:
        return '';
    }
  }

  // Dispara instalação em massa para múltiplos computadores
  Future<void> deployInstaller({
    required File installerFile,
    required String customArguments,
    required List<Device> targetDevices,
  }) async {
    if (!await installerFile.exists()) {
      throw Exception('O arquivo do instalador não foi encontrado no seu computador.');
    }

    _isDeploying = true;
    _currentTasks.clear();

    for (final dev in targetDevices) {
      _currentTasks.add(DeployTask(targetDevice: dev));
    }
    notifyListeners();

    final fileName = p.basename(installerFile.path);
    final fileSize = await installerFile.length();

    // Executa em paralelo para todos os alvos
    final futures = _currentTasks.map((task) async {
      final dev = task.targetDevice;
      task.status = DeployStatus.uploading;
      task.message = 'Enviando instalador (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)...';
      notifyListeners();

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      try {
        final uri = Uri.parse('http://${dev.ip}:${dev.port}/api/deploy/execute');
        final request = await client.postUrl(uri);

        request.headers.set('x-filename', Uri.encodeComponent(fileName));
        request.headers.set('x-arguments', Uri.encodeComponent(customArguments));
        request.headers.set('x-source-device', Uri.encodeComponent(SettingsService.instance.deviceName));
        request.headers.contentLength = fileSize;
        request.headers.contentType = ContentType.binary;

        // Streaming do arquivo
        final fileStream = installerFile.openRead();
        int sentBytes = 0;

        await request.addStream(fileStream.transform(
          StreamTransformer.fromHandlers(
            handleData: (List<int> data, EventSink<List<int>> sink) {
              sentBytes += data.length;
              task.progress = (sentBytes / fileSize).clamp(0.0, 0.95);
              notifyListeners();
              sink.add(data);
            },
          ),
        ));

        task.status = DeployStatus.installing;
        task.message = 'Executando instalação silenciosa no ${dev.resolvedName}...';
        notifyListeners();

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          task.status = DeployStatus.success;
          task.progress = 1.0;
          try {
            final json = jsonDecode(responseBody);
            task.message = json['message'] ?? 'Instalado com sucesso!';
          } catch (_) {
            task.message = 'Instalação disparada com sucesso no computador!';
          }
        } else {
          task.status = DeployStatus.error;
          task.message = 'Falha (HTTP ${response.statusCode}): $responseBody';
        }
      } catch (e) {
        task.status = DeployStatus.error;
        task.message = 'Erro de comunicação: $e';
      } finally {
        client.close();
        notifyListeners();
      }
    });

    await Future.wait(futures);
    _isDeploying = false;
    notifyListeners();
  }

  void clearTasks() {
    _currentTasks.clear();
    notifyListeners();
  }
}
