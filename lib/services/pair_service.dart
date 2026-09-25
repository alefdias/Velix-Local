import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import 'database_service.dart';
import 'settings_service.dart';
import 'mdns_service.dart';

class PairRequestInfo {
  final String requestId;
  final Device remoteDevice;
  final String pinCode;
  final DateTime createdAt;

  PairRequestInfo({
    required this.requestId,
    required this.remoteDevice,
    required this.pinCode,
    required this.createdAt,
  });
}

class PairService extends ChangeNotifier {
  static final PairService instance = PairService._internal();
  PairService._internal();

  PairRequestInfo? _incomingPairRequest;
  PairRequestInfo? get incomingPairRequest => _incomingPairRequest;

  // Callback ou Stream para abrir diálogo na interface quando receber solicitação
  final _pairRequestController = StreamController<PairRequestInfo>.broadcast();
  Stream<PairRequestInfo> get onPairRequest => _pairRequestController.stream;

  // Gera código aleatório de 6 dígitos (ex: "482910")
  String generateSixDigitPin() {
    final random = Random();
    final pin = 100000 + random.nextInt(900000);
    return pin.toString();
  }

  // Chamado quando outro dispositivo pede pareamento via HTTP
  void handleIncomingPairRequest(Map<String, dynamic> data) {
    final remoteDevice = Device(
      id: data['device_id'] as String,
      name: data['name'] as String,
      platform: DevicePlatformType.fromString(data['os'] as String? ?? 'unknown'),
      ip: data['ip'] as String? ?? '',
      port: data['port'] as int? ?? 53318,
      isTrusted: false,
      isOnline: true,
      lastSeen: DateTime.now(),
    );

    final pinCode = data['pin_code'] as String;
    final requestId = data['request_id'] as String;

    _incomingPairRequest = PairRequestInfo(
      requestId: requestId,
      remoteDevice: remoteDevice,
      pinCode: pinCode,
      createdAt: DateTime.now(),
    );

    _pairRequestController.add(_incomingPairRequest!);
    notifyListeners();
  }

  // Inicia solicitação de pareamento para um dispositivo remoto
  Future<bool> initiatePairing(Device targetDevice) async {
    final pin = generateSixDigitPin();
    final settings = SettingsService.instance;
    final requestId = '${DateTime.now().millisecondsSinceEpoch}';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);

    try {
      final url = Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/api/pair/request');
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'request_id': requestId,
        'device_id': settings.deviceId,
        'name': settings.deviceName,
        'os': DevicePlatformType.currentPlatform().displayName,
        'port': settings.httpPort,
        'ip': '',
        'pin_code': pin,
      });

      request.write(body);
      final response = await request.close();

      if (response.statusCode == 200) {
        final respBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> result = jsonDecode(respBody);
        if (result['status'] == 'accepted') {
          await _saveAsTrusted(targetDevice);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[PairService] Falha ao parear: $e');
      return false;
    } finally {
      client.close();
    }
  }

  // Aceitar solicitação de pareamento recebida
  Future<bool> acceptIncomingPairRequest() async {
    if (_incomingPairRequest == null) return false;

    final request = _incomingPairRequest!;
    final targetDevice = request.remoteDevice;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);

    try {
      final url = Uri.parse('http://${targetDevice.ip}:${targetDevice.port}/api/pair/confirm');
      final httpRequest = await client.postUrl(url);
      httpRequest.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'request_id': request.requestId,
        'status': 'accepted',
        'pin_code': request.pinCode,
        'device_id': SettingsService.instance.deviceId,
        'name': SettingsService.instance.deviceName,
        'os': DevicePlatformType.currentPlatform().displayName,
        'port': SettingsService.instance.httpPort,
      });

      httpRequest.write(body);
      final response = await httpRequest.close();

      if (response.statusCode == 200) {
        await _saveAsTrusted(targetDevice);
        _incomingPairRequest = null;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[PairService] Erro ao aceitar pareamento: $e');
    } finally {
      client.close();
    }

    _incomingPairRequest = null;
    notifyListeners();
    return false;
  }

  // Rejeitar solicitação de pareamento recebida
  void rejectIncomingPairRequest() {
    _incomingPairRequest = null;
    notifyListeners();
  }

  Future<void> _saveAsTrusted(Device device) async {
    final trustedDevice = device.copyWith(
      isTrusted: true,
      pairedAt: DateTime.now(),
    );
    await DatabaseService.instance.saveTrustedDevice(trustedDevice);
    MdnsDiscoveryService.instance.markDeviceAsTrusted(device.id);
  }

  Future<void> unpairDevice(String deviceId) async {
    await DatabaseService.instance.removeTrustedDevice(deviceId);
    await MdnsDiscoveryService.instance.startDiscovery();
    notifyListeners();
  }
}
