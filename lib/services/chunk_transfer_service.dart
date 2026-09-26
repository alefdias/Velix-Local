import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/transfer.dart';
import '../models/chunk_progress.dart';
import 'package:open_filex/open_filex.dart';
import 'database_service.dart';
import 'settings_service.dart';
import 'pair_service.dart';
import 'file_action_service.dart';
import 'notification_service.dart';

const int kDefaultChunkSize = 1024 * 1024; // 1 MB por bloco

class ChunkTransferService extends ChangeNotifier {
  static final ChunkTransferService instance = ChunkTransferService._internal();
  ChunkTransferService._internal();

  HttpServer? _server;
  final Map<String, TransferItem> _activeTransfers = {};
  final Map<String, RandomAccessFile> _openReceivingFiles = {};
  final Map<String, int> _lastSpeedBytes = {};
  final Map<String, DateTime> _lastSpeedTimes = {};

  List<TransferItem> get activeTransfers => _activeTransfers.values.toList();

  Future<void> startServer() async {
    if (_server != null) return;

    final port = SettingsService.instance.httpPort;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handleHttpRequest);
      debugPrint('[ChunkTransferService] Servidor HTTP rodando na porta $port');
    } catch (e) {
      debugPrint('[ChunkTransferService] Erro ao iniciar servidor HTTP: $e');
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    final path = request.uri.path;

    // CORS básico e cabeçalhos padrão
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      if (path == '/api/ping') {
        _handlePing(request);
      } else if (path == '/api/pair/request' && request.method == 'POST') {
        await _handlePairRequest(request);
      } else if (path == '/api/pair/confirm' && request.method == 'POST') {
        await _handlePairConfirm(request);
      } else if (path == '/api/transfer/start' && request.method == 'POST') {
        await _handleTransferStart(request);
      } else if (path == '/api/transfer/chunk-status' && request.method == 'GET') {
        await _handleTransferChunkStatus(request);
      } else if (path == '/api/transfer/chunk' && request.method == 'PUT') {
        await _handleReceiveChunk(request);
      } else if (path == '/api/transfer/complete' && request.method == 'POST') {
        await _handleTransferComplete(request);
      } else if (path == '/api/deploy/execute' && request.method == 'POST') {
        await _handleDeployExecute(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e) {
      debugPrint('[ChunkTransferService] Erro atendendo requisição $path: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  void _handlePing(HttpRequest request) {
    final settings = SettingsService.instance;
    final payload = {
      'status': 'online',
      'device_id': settings.deviceId,
      'device_name': settings.deviceName,
      'os': DevicePlatformType.currentPlatform().displayName,
    };
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    request.response.close();
  }

  Future<void> _handlePairRequest(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    PairService.instance.handleIncomingPairRequest(data);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'status': 'pending'}));
    await request.response.close();
  }

  Future<void> _handlePairConfirm(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final pinCode = data['pin_code'] as String?;
    final incoming = PairService.instance.incomingPairRequest;

    if (incoming != null && incoming.pinCode == pinCode) {
      final remoteDevice = Device(
        id: data['device_id'] as String,
        name: data['name'] as String,
        platform: DevicePlatformType.fromString(data['os'] as String? ?? 'unknown'),
        ip: data['ip'] as String? ?? request.connectionInfo?.remoteAddress.address ?? '',
        port: data['port'] as int? ?? 53318,
        isTrusted: true,
        isOnline: true,
        pairedAt: DateTime.now(),
      );

      await DatabaseService.instance.saveTrustedDevice(remoteDevice);

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'accepted'}));
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'rejected'}));
      await request.response.close();
    }
  }

  Future<void> _handleTransferStart(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final sessionId = data['session_id'] as String;
    final rawFileName = data['file_name'] as String? ?? 'arquivo';
    // Sanitização de Segurança Nível NASA/OWASP (CWE-22: Path Traversal Prevention)
    final fileName = p.basename(rawFileName).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileSize = data['file_size'] as int;
    final totalChunks = data['total_chunks'] as int;
    final chunkSize = data['chunk_size'] as int;
    final sourceDevice = data['source_device'] as String;
    final isSyncFile = data['is_sync_file'] as bool? ?? false;

    // Diretório temporário para chunks recebidos
    final tempDir = await _getTempDirectory();
    final partFile = File(p.join(tempDir.path, '$sessionId.velix_part'));
    if (!await partFile.exists()) {
      await partFile.create(recursive: true);
    }

    final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
    _openReceivingFiles[sessionId] = raf;

    // Verificar chunks já salvos no banco para caso de retomada
    final completedChunks = await DatabaseService.instance.getCompletedChunkIndexes(sessionId);
    final bytesTransferred = completedChunks.length * chunkSize;

    final transferItem = TransferItem(
      id: sessionId,
      sessionId: sessionId,
      fileName: fileName,
      localFilePath: partFile.path,
      fileSize: fileSize,
      sourceDevice: sourceDevice,
      targetDevice: SettingsService.instance.deviceName,
      isIncoming: true,
      startTime: DateTime.now(),
      status: TransferStatus.transferring,
      bytesTransferred: bytesTransferred.clamp(0, fileSize),
      completedChunks: completedChunks.length,
      totalChunks: totalChunks,
      isSyncFile: isSyncFile,
    );

    _activeTransfers[sessionId] = transferItem;
    await DatabaseService.instance.saveTransferHistory(transferItem);
    notifyListeners();

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'ready',
      'completed_chunks': completedChunks,
    }));
    await request.response.close();
  }

  Future<void> _handleTransferChunkStatus(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['session_id'];
    if (sessionId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final completed = await DatabaseService.instance.getCompletedChunkIndexes(sessionId);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'completed_chunks': completed}));
    await request.response.close();
  }

  Future<void> _handleReceiveChunk(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['session_id'];
    final chunkIndexStr = request.uri.queryParameters['chunk_index'];
    final chunkSizeStr = request.uri.queryParameters['chunk_size'];

    if (sessionId == null || chunkIndexStr == null || chunkSizeStr == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final chunkIndex = int.parse(chunkIndexStr);
    final chunkSize = int.parse(chunkSizeStr);

    var raf = _openReceivingFiles[sessionId];
    if (raf == null) {
      final tempDir = await _getTempDirectory();
      final partFile = File(p.join(tempDir.path, '$sessionId.velix_part'));
      raf = await partFile.open(mode: FileMode.write);
      _openReceivingFiles[sessionId] = raf;
    }

    // Posicionar o offset exato no arquivo
    await raf.setPosition(chunkIndex * chunkSize);

    // Escrever stream de bytes diretamente no arquivo
    int chunkBytesReceived = 0;
    await for (final chunk in request) {
      await raf.writeFrom(chunk);
      chunkBytesReceived += chunk.length;
    }

    // Salvar bloco completado no SQLite
    await DatabaseService.instance.markChunkCompleted(
      ChunkProgress(
        sessionId: sessionId,
        filePath: raf.path,
        chunkIndex: chunkIndex,
        totalChunks: _activeTransfers[sessionId]?.totalChunks ?? 1,
        chunkSize: chunkSize,
        isCompleted: true,
        updatedAt: DateTime.now(),
      ),
    );

    // Atualizar métricas de progresso e velocidade
    _updateTransferProgress(sessionId, chunkBytesReceived);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'status': 'chunk_saved', 'index': chunkIndex}));
    await request.response.close();
  }

  Future<void> _handleTransferComplete(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final sessionId = data['session_id'] as String;
    final targetFolder = data['target_folder'] as String?;
    final sourceDevice = data['source_device'] as String? ?? 'Dispositivo Remoto';

    final raf = _openReceivingFiles.remove(sessionId);
    if (raf != null) {
      await raf.close();
    }

    final currentTransfer = _activeTransfers[sessionId];
    if (currentTransfer == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final tempDir = await _getTempDirectory();
    final partFile = File(p.join(tempDir.path, '$sessionId.velix_part'));

    if (await partFile.exists()) {
      // Definir diretório final
      String destDir = targetFolder ?? SettingsService.instance.downloadDirectory;
      final destinationDir = Directory(destDir);
      if (!await destinationDir.exists()) {
        try {
          await destinationDir.create(recursive: true);
        } catch (dirErr) {
          debugPrint('[ChunkTransferService] Erro ao criar $destDir ($dirErr). Fallback para pasta padrão.');
          destDir = await SettingsService.instance.resolveSafeDownloadDirectory();
        }
      }

      var finalFileName = p.basename(currentTransfer.fileName).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      var destinationPath = p.normalize(p.join(destDir, finalFileName));

      // Resolução de conflito: se o arquivo já existir com conteúdo diferente,
      // salva como "nome (DispositivoOrigem).ext"
      if (await File(destinationPath).exists()) {
        final ext = p.extension(finalFileName);
        final base = p.basenameWithoutExtension(finalFileName);
        final cleanSource = sourceDevice.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
        finalFileName = '$base ($cleanSource)$ext';
        destinationPath = p.join(destDir, finalFileName);
      }

      // Mover arquivo temporário para destino final de forma à prova de cross-device link
      try {
        await partFile.rename(destinationPath);
      } catch (e) {
        debugPrint('[ChunkTransferService] partFile.rename falhou ($e). Executando cópia de fluxo segura...');
        try {
          await partFile.copy(destinationPath);
          try {
            await partFile.delete();
          } catch (_) {}
        } catch (copyErr) {
          debugPrint('[ChunkTransferService] Erro crítico ao copiar partFile para $destinationPath: $copyErr');
          rethrow;
        }
      }

      // Indexar o arquivo imediatamente no Android para aparecer no app "Files do Google" e Galeria
      await FileActionService.scanMedia(destinationPath);

      final completedTransfer = currentTransfer.copyWith(
        status: TransferStatus.completed,
        endTime: DateTime.now(),
        localFilePath: destinationPath,
        bytesTransferred: currentTransfer.fileSize,
        completedChunks: currentTransfer.totalChunks,
      );

      _activeTransfers[sessionId] = completedTransfer;
      await DatabaseService.instance.saveTransferHistory(completedTransfer);
      await DatabaseService.instance.clearChunkProgress(sessionId);
      notifyListeners();

      // Disparar notificação do sistema com som/barulhinho
      NotificationService.instance.notifyFileReceived(
        fileName: completedTransfer.fileName,
        senderDevice: completedTransfer.sourceDevice,
        filePath: destinationPath,
      );

      // Manter o card com botões "Abrir Arquivo" e "Abrir Pasta" visível por 25s
      Future.delayed(const Duration(seconds: 25), () {
        if (_activeTransfers[sessionId]?.status == TransferStatus.completed) {
          _activeTransfers.remove(sessionId);
          notifyListeners();
        }
      });
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'status': 'completed'}));
    await request.response.close();
  }

  void _updateTransferProgress(String sessionId, int addedBytes) {
    final item = _activeTransfers[sessionId];
    if (item == null) return;

    final newBytes = (item.bytesTransferred + addedBytes).clamp(0, item.fileSize);
    final now = DateTime.now();

    double speedMbps = item.speedMbps;
    final lastTime = _lastSpeedTimes[sessionId];
    final lastBytes = _lastSpeedBytes[sessionId];

    if (lastTime != null && lastBytes != null) {
      final elapsedMs = now.difference(lastTime).inMilliseconds;
      if (elapsedMs >= 500) {
        final diffBytes = newBytes - lastBytes;
        final bytesPerSec = (diffBytes / (elapsedMs / 1000.0));
        speedMbps = (bytesPerSec / (1024 * 1024));
        _lastSpeedTimes[sessionId] = now;
        _lastSpeedBytes[sessionId] = newBytes;
      }
    } else {
      _lastSpeedTimes[sessionId] = now;
      _lastSpeedBytes[sessionId] = newBytes;
    }

    final updated = item.copyWith(
      bytesTransferred: newBytes,
      completedChunks: item.completedChunks + 1,
      speedMbps: speedMbps,
    );

    _activeTransfers[sessionId] = updated;
    notifyListeners();
  }

  // --- Envio de Arquivos com Retomada de Blocos (Chunks) ---

  Future<bool> sendFile({
    required Device targetDevice,
    required File file,
    String? customSessionId,
    bool isSync = false,
    String? targetFolder,
    void Function(TransferItem progress)? onProgress,
  }) async {
    final sessionId = customSessionId ?? const Uuid().v4();
    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    const chunkSize = kDefaultChunkSize;
    final totalChunks = (fileSize / chunkSize).ceil().clamp(1, 999999999);

    final transferItem = TransferItem(
      id: sessionId,
      sessionId: sessionId,
      fileName: fileName,
      localFilePath: file.path,
      fileSize: fileSize,
      sourceDevice: SettingsService.instance.deviceName,
      targetDevice: targetDevice.name,
      isIncoming: false,
      startTime: DateTime.now(),
      status: TransferStatus.waiting,
      totalChunks: totalChunks,
      isSyncFile: isSync,
    );

    _activeTransfers[sessionId] = transferItem;
    await DatabaseService.instance.saveTransferHistory(transferItem);
    notifyListeners();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      // 1. Iniciar handshake da transferência e obter blocos já concluídos
      final startUrl = Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/api/transfer/start');
      final startReq = await client.postUrl(startUrl);
      startReq.headers.contentType = ContentType.json;
      startReq.write(jsonEncode({
        'session_id': sessionId,
        'file_name': fileName,
        'file_size': fileSize,
        'total_chunks': totalChunks,
        'chunk_size': chunkSize,
        'source_device': SettingsService.instance.deviceName,
        'is_sync_file': isSync,
        'target_folder': targetFolder,
      }));

      final startResp = await startReq.close();
      if (startResp.statusCode != HttpStatus.ok) {
        throw Exception('Receptor recusou a transferência (HTTP ${startResp.statusCode})');
      }

      final startBody = await utf8.decoder.bind(startResp).join();
      final startData = jsonDecode(startBody) as Map<String, dynamic>;
      final List<dynamic> rawCompleted = startData['completed_chunks'] ?? [];
      final Set<int> completedChunks = rawCompleted.map((e) => e as int).toSet();

      // 2. Abrir o arquivo local em modo leitura
      final raf = await file.open(mode: FileMode.read);
      var currentItem = transferItem.copyWith(
        status: TransferStatus.transferring,
        completedChunks: completedChunks.length,
        bytesTransferred: (completedChunks.length * chunkSize).clamp(0, fileSize),
      );
      _activeTransfers[sessionId] = currentItem;
      notifyListeners();

      DateTime lastSpeedUpdate = DateTime.now();
      int bytesInLastWindow = 0;

      // 3. Transmitir blocos pendentes (pula os blocos já confirmados na retomada)
      for (int i = 0; i < totalChunks; i++) {
        // Se a transferência foi cancelada pelo usuário
        if (_activeTransfers[sessionId]?.status == TransferStatus.canceled) {
          await raf.close();
          client.close();
          return false;
        }

        if (completedChunks.contains(i)) {
          // Bloco já recebido anteriormente (retomada inteligente!)
          continue;
        }

        final offset = i * chunkSize;
        final currentChunkBytes = (offset + chunkSize > fileSize) ? (fileSize - offset) : chunkSize;

        await raf.setPosition(offset);
        final chunkData = await raf.read(currentChunkBytes);

        // Enviar o bloco via PUT
        final chunkUrl = Uri.parse(
          'http://${targetDevice.ip}:${targetDevice.port}/api/transfer/chunk'
          '?session_id=$sessionId&chunk_index=$i&chunk_size=$chunkSize',
        );

        final chunkReq = await client.putUrl(chunkUrl);
        chunkReq.headers.contentLength = chunkData.length;
        chunkReq.add(chunkData);
        final chunkResp = await chunkReq.close();

        if (chunkResp.statusCode != HttpStatus.ok) {
          throw Exception('Falha ao enviar chunk $i (HTTP ${chunkResp.statusCode})');
        }

        completedChunks.add(i);
        bytesInLastWindow += chunkData.length;

        // Calcular velocidade a cada 500ms
        final now = DateTime.now();
        final elapsed = now.difference(lastSpeedUpdate).inMilliseconds;
        double currentSpeed = currentItem.speedMbps;

        if (elapsed >= 500) {
          currentSpeed = (bytesInLastWindow / (elapsed / 1000.0)) / (1024 * 1024);
          bytesInLastWindow = 0;
          lastSpeedUpdate = now;
        }

        final transferredBytes = (completedChunks.length * chunkSize).clamp(0, fileSize);
        currentItem = currentItem.copyWith(
          bytesTransferred: transferredBytes,
          completedChunks: completedChunks.length,
          speedMbps: currentSpeed,
        );

        _activeTransfers[sessionId] = currentItem;
        if (onProgress != null) onProgress(currentItem);
        notifyListeners();
      }

      await raf.close();

      // 4. Finalizar transferência
      final completeUrl = Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/api/transfer/complete');
      final compReq = await client.postUrl(completeUrl);
      compReq.headers.contentType = ContentType.json;
      compReq.write(jsonEncode({
        'session_id': sessionId,
        'target_folder': targetFolder,
        'source_device': SettingsService.instance.deviceName,
      }));
      final compResp = await compReq.close();

      if (compResp.statusCode == HttpStatus.ok) {
        final finalItem = currentItem.copyWith(
          status: TransferStatus.completed,
          endTime: DateTime.now(),
          bytesTransferred: fileSize,
          completedChunks: totalChunks,
        );
        _activeTransfers[sessionId] = finalItem;
        await DatabaseService.instance.saveTransferHistory(finalItem);
        notifyListeners();

        // Manter o card visível por 20 segundos para confirmação visual de envio
        Future.delayed(const Duration(seconds: 20), () {
          if (_activeTransfers[sessionId]?.status == TransferStatus.completed) {
            _activeTransfers.remove(sessionId);
            notifyListeners();
          }
        });
        return true;
      } else {
        final errText = await utf8.decoder.bind(compResp).join();
        throw Exception('Destinatário respondeu com erro ao concluir (HTTP ${compResp.statusCode}): $errText');
      }
    } catch (e) {
      debugPrint('[ChunkTransferService] Erro durante transferência: $e');
      final failedItem = _activeTransfers[sessionId]?.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
      if (failedItem != null) {
        _activeTransfers[sessionId] = failedItem;
        await DatabaseService.instance.saveTransferHistory(failedItem);
      }
      notifyListeners();
    } finally {
      client.close();
    }
    return false;
  }

  Future<void> cancelTransfer(String sessionId) async {
    final item = _activeTransfers[sessionId];
    if (item != null) {
      final canceledItem = item.copyWith(
        status: TransferStatus.canceled,
        endTime: DateTime.now(),
      );
      _activeTransfers[sessionId] = canceledItem;
      await DatabaseService.instance.saveTransferHistory(canceledItem);
      notifyListeners();
    }
  }

  Future<Directory> _getTempDirectory() async {
    Directory baseDir;
    try {
      final downloadPath = SettingsService.instance.downloadDirectory;
      if (downloadPath.isNotEmpty) {
        final downloadDir = Directory(downloadPath);
        if (downloadDir.existsSync()) {
          baseDir = downloadDir;
        } else {
          baseDir = await getTemporaryDirectory();
        }
      } else {
        baseDir = await getTemporaryDirectory();
      }
    } catch (_) {
      try {
        baseDir = await getTemporaryDirectory();
      } catch (_) {
        baseDir = Directory.current;
      }
    }
    final velixTemp = Directory(p.join(baseDir.path, '.velix_temp'));
    if (!await velixTemp.exists()) {
      try {
        await velixTemp.create(recursive: true);
      } catch (_) {
        return Directory.systemTemp;
      }
    }
    return velixTemp;
  }

  Future<void> _handleDeployExecute(HttpRequest request) async {
    final fileNameEncoded = request.headers.value('x-filename') ?? 'installer.bin';
    final fileName = Uri.decodeComponent(fileNameEncoded);
    final argsEncoded = request.headers.value('x-arguments') ?? '';
    final argsString = Uri.decodeComponent(argsEncoded);
    final sourceDeviceEncoded = request.headers.value('x-source-device') ?? 'Remoto';
    final sourceDevice = Uri.decodeComponent(sourceDeviceEncoded);

    // Salvar em pasta temporária segura
    Directory baseDir;
    try {
      baseDir = await getTemporaryDirectory();
    } catch (_) {
      baseDir = Directory.current;
    }
    final deployDir = Directory(p.join(baseDir.path, 'velix_deploy'));
    if (!await deployDir.exists()) {
      await deployDir.create(recursive: true);
    }

    final targetPath = p.join(deployDir.path, fileName);
    final targetFile = File(targetPath);
    final sink = targetFile.openWrite();
    await for (final chunk in request) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();

    debugPrint('[Deploy] Instalador "$fileName" recebido com sucesso de "$sourceDevice". Disparando execução local...');

    final ext = p.extension(fileName).toLowerCase();
    String executionMessage = 'Instalação silenciosa disparada com sucesso no computador!';

    try {
      if (Platform.isWindows) {
        if (ext == '.msi') {
          Process.start('msiexec', ['/i', targetPath, '/quiet', '/qn', '/norestart']);
        } else {
          final customList = argsString.trim().isNotEmpty
              ? argsString.trim().split(' ')
              : ['/S', '/silent', '/quiet', '/qn'];
          Process.start(targetPath, customList);
        }
      } else if (Platform.isLinux) {
        if (ext == '.rpm') {
          // No Fedora/RHEL:
          Process.start('rpm', ['-Uvh', '--replacepkgs', targetPath]);
        } else if (ext == '.deb') {
          // No Ubuntu/Debian:
          Process.start('dpkg', ['-i', targetPath]);
        } else if (ext == '.sh') {
          await Process.run('chmod', ['+x', targetPath]);
          Process.start('bash', [targetPath]);
        } else {
          await Process.run('chmod', ['+x', targetPath]);
          Process.start(targetPath, argsString.trim().isNotEmpty ? argsString.trim().split(' ') : []);
        }
      } else if (Platform.isAndroid) {
        OpenFilex.open(targetPath);
      }
    } catch (e) {
      debugPrint('[Deploy] Erro ao disparar processo: $e');
      executionMessage = 'Instalador salvo com sucesso. Erro ao disparar: $e';
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'success',
      'message': executionMessage,
      'file': fileName,
    }));
    await request.response.close();
  }

  void stopServer() {
    _server?.close(force: true);
    _server = null;
  }
}
