import 'package:flutter/material.dart';
import '../models/sync_folder.dart';

class SyncCard extends StatelessWidget {
  final SyncFolder folder;
  final String localDeviceName;
  final VoidCallback onSyncNow;
  final VoidCallback onTogglePause;
  final VoidCallback onRemove;
  final VoidCallback? onOpenFolder;

  const SyncCard({
    super.key,
    required this.folder,
    required this.localDeviceName,
    required this.onSyncNow,
    required this.onTogglePause,
    required this.onRemove,
    this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: folder.isSyncing
              ? const Color(0xFF0078D4)
              : (isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: Ícone de Pasta + Nome + Dispositivos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: folder.isPaused
                        ? Colors.grey.withOpacity(0.15)
                        : const Color(0xFF0078D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: folder.isSyncing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF0078D4),
                            ),
                          )
                        : Icon(
                            folder.isPaused ? Icons.folder_off_outlined : Icons.folder_rounded,
                            color: folder.isPaused ? Colors.grey : const Color(0xFF0078D4),
                            size: 26,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              folder.folderName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (folder.isPaused)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Pausado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // PC <-> Notebook
                      Row(
                        children: [
                          Icon(
                            Icons.devices,
                            size: 14,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$localDeviceName ↔ ${folder.remoteDeviceName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (onOpenFolder != null)
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 20),
                    tooltip: 'Abrir pasta local',
                    onPressed: onOpenFolder,
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: Color(0x1F94A3B8)),
            const SizedBox(height: 12),

            // Status e Estatísticas
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status:',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        folder.isSyncing
                            ? 'Sincronizando em segundo plano...'
                            : (folder.isPaused ? 'Pausado pelo usuário' : folder.timeSinceLastSync),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: folder.isSyncing
                              ? const Color(0xFF0078D4)
                              : (folder.isPaused
                                  ? Colors.amber.shade700
                                  : (isDark ? Colors.white : const Color(0xFF1E293B))),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${folder.totalFiles} arquivos • ${folder.humanReadableSize}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Barra de Botões: Sincronizar, Pausar, Remover
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: folder.isSyncing || folder.isPaused ? null : onSyncNow,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sincronizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: onTogglePause,
                  icon: Icon(
                    folder.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 16,
                  ),
                  label: Text(folder.isPaused ? 'Retomar' : 'Pausar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Spacer(),

                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remover sincronização',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
