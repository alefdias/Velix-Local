import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import 'settings_service.dart';
import 'database_service.dart';

class MdnsDiscoveryService extends ChangeNotifier {
  static final MdnsDiscoveryService instance = MdnsDiscoveryService._internal();
  MdnsDiscoveryService._internal();

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Map<String, Device> _discoveredDevices = {};
  bool _isSearching = false;
  bool _isScanningSubnet = false;
  double _subnetScanProgress = 0.0;

  List<Device> get devices => _discoveredDevices.values.toList();
  List<Device> get onlineDevices => _discoveredDevices.values.where((d) => d.isOnline).toList();
  bool get isSearching => _isSearching;
  bool get isScanningSubnet => _isScanningSubnet;
  double get subnetScanProgress => _subnetScanProgress;

  Future<void> startDiscovery() async {
    if (_socket != null) return;

    final settings = SettingsService.instance;
    final port = settings.discoveryPort;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _socket!.broadcastEnabled = true;
      _socket!.listen(_handleIncomingDatagram);

      // Carregar dispositivos confiáveis conhecidos do banco de dados
      await _loadKnownTrustedDevices();

      // Iniciar broadcast periódico a cada 2.5 segundos
      _broadcastTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        broadcastPresence();
      });

      // Checagem de dispositivos offline a cada 4 segundos
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _checkOfflineDevices();
      });

      // Anunciar presença imediatamente
      await broadcastPresence();
    } catch (e) {
      debugPrint('[MdnsDiscoveryService] Erro ao iniciar socket UDP: $e');
    }
  }

  Future<void> _loadKnownTrustedDevices() async {
    final trustedList = await DatabaseService.instance.getTrustedDevices();
    final aliases = await DatabaseService.instance.getAllDeviceAliases();

    for (final dev in trustedList) {
      final alias = aliases[dev.id];
      _discoveredDevices[dev.id] = dev.copyWith(
        isOnline: false,
        customAlias: alias,
      );
    }
    notifyListeners();
  }

  void _handleIncomingDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram == null) return;

      try {
        final message = utf8.decode(datagram.data);
        final Map<String, dynamic> data = jsonDecode(message);

        final myId = SettingsService.instance.deviceId;
        final senderId = data['id'] as String?;

        if (senderId == null || senderId == myId) {
          // Ignora mensagens do próprio dispositivo
          return;
        }

        final senderType = data['type'] as String?;
        final remoteIp = datagram.address.address;

        if (senderType == 'velix_announcement' || senderType == 'velix_response') {
          _registerDiscoveredDevice(data, remoteIp);
        } else if (senderType == 'velix_query') {
          // Responder diretamente para quem perguntou
          _sendResponseTo(datagram.address, datagram.port);
        }
      } catch (e) {
        debugPrint('[MdnsDiscoveryService] Erro decodificando pacote UDP: $e');
      }
    }
  }

  Future<void> _registerDiscoveredDevice(Map<String, dynamic> data, String remoteIp) async {
    final id = data['id'] as String;
    final name = data['name'] as String? ?? 'Dispositivo Velix';
    final osString = data['os'] as String? ?? 'Linux';
    final port = data['port'] as int? ?? 53318;

    final isTrusted = await DatabaseService.instance.isDeviceTrusted(id);
    final savedAlias = await DatabaseService.instance.getDeviceAlias(id);

    final existing = _discoveredDevices[id];

    final device = Device(
      id: id,
      name: name,
      customAlias: savedAlias ?? existing?.customAlias,
      platform: DevicePlatformType.fromString(osString),
      ip: remoteIp,
      port: port,
      isTrusted: true,
      isOnline: true,
      lastSeen: DateTime.now(),
    );

    _discoveredDevices[id] = device;
    notifyListeners();
  }

  Future<void> broadcastPresence() async {
    if (_socket == null) return;

    final settings = SettingsService.instance;
    final payload = jsonEncode({
      'type': 'velix_announcement',
      'id': settings.deviceId,
      'name': settings.deviceName,
      'os': DevicePlatformType.currentPlatform().displayName,
      'port': settings.httpPort,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(payload);

    try {
      // Broadcast para 255.255.255.255
      _socket!.send(bytes, InternetAddress('255.255.255.255'), settings.discoveryPort);

      // Também envia nos broadcasts das interfaces de rede locais ativas
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
            try {
              _socket!.send(bytes, InternetAddress(subnetBroadcast), settings.discoveryPort);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[MdnsDiscoveryService] Erro ao enviar broadcast: $e');
    }
  }

  void _sendResponseTo(InternetAddress targetAddress, int targetPort) {
    if (_socket == null) return;
    final settings = SettingsService.instance;
    final payload = jsonEncode({
      'type': 'velix_response',
      'id': settings.deviceId,
      'name': settings.deviceName,
      'os': DevicePlatformType.currentPlatform().displayName,
      'port': settings.httpPort,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      _socket!.send(utf8.encode(payload), targetAddress, targetPort);
    } catch (_) {}
  }

  Future<void> triggerManualScan() async {
    _isSearching = true;
    notifyListeners();

    if (_socket != null) {
      final settings = SettingsService.instance;
      final payload = jsonEncode({
        'type': 'velix_query',
        'id': settings.deviceId,
      });
      final bytes = utf8.encode(payload);

      try {
        _socket!.send(bytes, InternetAddress('255.255.255.255'), settings.discoveryPort);
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    _isSearching = false;
    notifyListeners();
  }

  // --- Varredura Ativa de Sub-rede Corporativa (Ideal para Grandes Empresas) ---
  Future<void> scanSubnet() async {
    if (_isScanningSubnet) return;
    _isScanningSubnet = true;
    _subnetScanProgress = 0.0;
    notifyListeners();

    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final myId = SettingsService.instance.deviceId;
      final defaultPort = SettingsService.instance.httpPort;

      final List<String> targetIps = [];

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            for (int i = 1; i <= 254; i++) {
              final testIp = '$subnetPrefix.$i';
              if (testIp != addr.address) {
                targetIps.add(testIp);
              }
            }
          }
        }
      }

      int scanned = 0;
      final total = targetIps.length;
      const batchSize = 35; // Lotes simultâneos para alta performance

      for (int i = 0; i < total; i += batchSize) {
        final batch = targetIps.skip(i).take(batchSize).toList();
        await Future.wait(batch.map((ip) async {
          final client = HttpClient();
          client.connectionTimeout = const Duration(milliseconds: 900);
          try {
            final uri = Uri.parse('http://$ip:$defaultPort/api/ping');
            final req = await client.getUrl(uri);
            final resp = await req.close();
            if (resp.statusCode == HttpStatus.ok) {
              final body = await utf8.decoder.bind(resp).join();
              final Map<String, dynamic> data = jsonDecode(body);
              final remoteId = data['device_id'] as String?;
              if (remoteId != null && remoteId != myId) {
                await _registerDiscoveredDevice({
                  'id': remoteId,
                  'name': data['device_name'] ?? 'Computador Corporativo',
                  'os': data['os'] ?? 'Linux',
                  'port': defaultPort,
                }, ip);
              }
            }
          } catch (_) {} finally {
            client.close();
          }
        }));

        scanned += batch.length;
        _subnetScanProgress = (scanned / (total > 0 ? total : 1)).clamp(0.0, 1.0);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MdnsDiscoveryService] Erro no scan de sub-rede: $e');
    } finally {
      _isScanningSubnet = false;
      _subnetScanProgress = 1.0;
      notifyListeners();
    }
  }

  // --- Renomear Computador na Rede (Apelido Local Corporativo) ---
  Future<void> renameDevice(String deviceId, String newAlias) async {
    await DatabaseService.instance.saveDeviceAlias(deviceId, newAlias);

    final current = _discoveredDevices[deviceId];
    if (current != null) {
      _discoveredDevices[deviceId] = current.copyWith(
        customAlias: newAlias.trim().isEmpty ? null : newAlias.trim(),
      );
      notifyListeners();
    }
  }

  void _checkOfflineDevices() {
    final now = DateTime.now();
    bool changed = false;

    _discoveredDevices.forEach((id, device) {
      if (device.isOnline && device.lastSeen != null) {
        if (now.difference(device.lastSeen!).inSeconds > 10) {
          _discoveredDevices[id] = device.copyWith(isOnline: false);
          changed = true;
        }
      }
    });

    if (changed) {
      notifyListeners();
    }
  }

  void markDeviceAsTrusted(String deviceId) {
    if (_discoveredDevices.containsKey(deviceId)) {
      _discoveredDevices[deviceId] = _discoveredDevices[deviceId]!.copyWith(isTrusted: true);
      notifyListeners();
    }
  }

  void stopDiscovery() {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
  }
}
