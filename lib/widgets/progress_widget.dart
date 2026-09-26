import 'dart:io';
import 'package:flutter/material.dart';
import '../models/transfer.dart';
import '../services/settings_service.dart';
import '../services/file_action_service.dart';

class ProgressWidget extends StatelessWidget {
  final TransferItem item;
  final VoidCallback? onCancel;
  final VoidCallback? onResume;

  const ProgressWidget({
    super.key,
    required this.item,
    this.onCancel,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = item.progressPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.status == TransferStatus.transferring
              ? const Color(0xFF0078D4).withOpacity(0.5)
              : (isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.status == TransferStatus.completed
              ? () => FileActionService.showTransferDetailsModal(context, item)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome do Arquivo + Direção + Ação
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.isIncoming
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : const Color(0xFF0078D4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    item.isIncoming ? Icons.download_rounded : Icons.upload_rounded,
                    color: item.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.sourceDevice} → ${item.targetDevice}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Porcentagem
              Text(
                item.formattedPercentage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0078D4),
                ),
              ),

              const SizedBox(width: 8),
              if (item.status == TransferStatus.transferring && onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Cancelar',
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de Progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                item.status == TransferStatus.failed
                    ? Colors.redAccent
                    : (item.status == TransferStatus.completed
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0078D4)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Informações Inferiores: Bytes transferidos / Total • MB/s • Tempo Restante • Blocos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.formattedTransferredSize} de ${item.formattedFileSize}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              if (item.status == TransferStatus.transferring) ...[
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.formattedSpeed,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.remainingTimeFormatted,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  item.status.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.status == TransferStatus.completed
                        ? const Color(0xFF10B981)
                        : (item.status == TransferStatus.failed ? Colors.redAccent : Colors.grey),
                  ),
                ),
              ],
            ],
          ),

          // Exibição dos blocos de chunk
          if (item.totalChunks > 1 && item.status == TransferStatus.transferring) ...[
            const SizedBox(height: 6),
            Text(
              'Bloco ${item.completedChunks} de ${item.totalChunks} (Recuperável automaticamente)',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],

          // Painel de Ações Rápidas quando Concluído
          if (item.status == TransferStatus.completed) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (item.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4)).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isIncoming ? Icons.check_circle_rounded : Icons.cloud_done_rounded,
                    color: item.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.isIncoming
                          ? 'Salvo em: ${item.localFilePath ?? "Downloads/VelixLocal"}'
                          : 'Enviado para ${item.targetDevice} (Pasta Downloads)',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: item.isIncoming ? 'monospace' : null,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (item.localFilePath != null && File(item.localFilePath!).existsSync()) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => FileActionService.openFile(item.localFilePath!, context),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Abrir Arquivo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => FileActionService.openFolder(
                      item.localFilePath ?? SettingsService.instance.downloadDirectory,
                      context,
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Abrir Downloads'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  ),
),
);
}
}
