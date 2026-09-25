import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onPair;
  final VoidCallback? onSendFiles;
  final VoidCallback? onUnpair;
  final VoidCallback? onRename;

  const DeviceCard({
    super.key,
    required this.device,
    this.onPair,
    this.onSendFiles,
    this.onUnpair,
    this.onRename,
  });

  IconData _getPlatformIcon(DevicePlatformType platform) {
    switch (platform) {
      case DevicePlatformType.windows:
        return Icons.laptop_windows;
      case DevicePlatformType.linux:
        return Icons.terminal;
      case DevicePlatformType.android:
        return Icons.phone_android;
      case DevicePlatformType.macos:
        return Icons.laptop_mac;
      case DevicePlatformType.ios:
        return Icons.phone_iphone;
      default:
        return Icons.devices;
    }
  }

  Color _getPlatformColor(DevicePlatformType platform) {
    switch (platform) {
      case DevicePlatformType.windows:
        return const Color(0xFF0078D4);
      case DevicePlatformType.linux:
        return const Color(0xFFF58220);
      case DevicePlatformType.android:
        return const Color(0xFF3DDC84);
      case DevicePlatformType.macos:
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF00B4D8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasAlias = device.customAlias != null && device.customAlias!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: device.isOnline
              ? (isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0))
              : (isDark ? const Color(0xFF1A1F26) : const Color(0xFFF1F5F9)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Ícone da Plataforma
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _getPlatformColor(device.platform).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  _getPlatformIcon(device.platform),
                  color: _getPlatformColor(device.platform),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Informações do Dispositivo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          device.resolvedName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onRename != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Renomear este computador',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onRename,
                        ),
                      ],
                      const SizedBox(width: 8),
                      // Dot de status online/offline
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: device.isOnline ? const Color(0xFF10B981) : Colors.grey.shade500,
                          boxShadow: device.isOnline
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        device.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: device.isOnline ? const Color(0xFF10B981) : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (hasAlias) ...[
                        Text(
                          'Hostname: ${device.name} • ',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                      Text(
                        '${device.platform.displayName} • ${device.ip}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      if (device.isTrusted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0078D4).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: Color(0xFF0078D4)),
                              SizedBox(width: 4),
                              Text(
                                'Confiável',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0078D4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Ações do Card
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonalIcon(
                  onPressed: device.isOnline ? onSendFiles : null,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Enviar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4).withOpacity(0.12),
                    foregroundColor: const Color(0xFF0078D4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  tooltip: 'Renomear Dispositivo',
                  onPressed: onRename,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
