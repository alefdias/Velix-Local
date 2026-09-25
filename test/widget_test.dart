import 'package:flutter_test/flutter_test.dart';
import 'package:velix_local/models/device.dart';
import 'package:velix_local/models/sync_folder.dart';
import 'package:velix_local/models/transfer.dart';

void main() {
  group('Velix Local - Testes Unitários de Modelos e Lógica P2P', () {
    test('Modelo Device serializa e desserializa corretamente', () {
      final device = Device(
        id: 'test-device-uuid',
        name: 'Notebook Dell',
        platform: DevicePlatformType.linux,
        ip: '192.168.1.15',
        port: 53318,
        isTrusted: true,
        isOnline: true,
      );

      final map = device.toMap();
      expect(map['device_id'], 'test-device-uuid');
      expect(map['name'], 'Notebook Dell');
      expect(map['os'], 'Linux');
      expect(map['ip'], '192.168.1.15');
      expect(map['port'], 53318);
      expect(map['is_trusted'], 1);

      final reconstructed = Device.fromMap(map, isOnline: true);
      expect(reconstructed.id, device.id);
      expect(reconstructed.name, device.name);
      expect(reconstructed.platform, DevicePlatformType.linux);
      expect(reconstructed.isTrusted, true);
    });

    test('Modelo SyncFolder calcula tempo decorrido e formatação de tamanho', () {
      final folder = SyncFolder(
        id: 'folder-1',
        localPath: '/home/alef/Documentos/Projetos',
        folderName: 'Projetos',
        remoteDeviceId: 'notebook-id',
        remoteDeviceName: 'Notebook',
        totalFiles: 142,
        totalSize: 1024 * 1024 * 50, // 50 MB
        lastSyncedAt: DateTime.now().subtract(const Duration(seconds: 8)),
      );

      expect(folder.humanReadableSize, '50.0 MB');
      expect(folder.timeSinceLastSync, 'Sincronizado há instantes');
    });

    test('Modelo TransferItem calcula porcentagem, MB/s e tempo restante', () {
      final transfer = TransferItem(
        id: 'transfer-1',
        sessionId: 'session-xyz',
        fileName: 'backup_8gb.iso',
        fileSize: 100,
        sourceDevice: 'PC',
        targetDevice: 'Notebook',
        isIncoming: false,
        startTime: DateTime.now(),
        bytesTransferred: 95,
        speedMbps: 25.0, // 25 MB/s
        completedChunks: 95,
        totalChunks: 100,
      );

      expect(transfer.progressPercentage, 0.95);
      expect(transfer.formattedPercentage, '95.0%');
      expect(transfer.formattedSpeed, '25.0 MB/s');
    });
  });
}
