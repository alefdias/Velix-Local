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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

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
        padding: EdgeInsets.all(isMobile ? 12.0 : 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: Ícone de Pasta + Nome + Dispositivos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 40 : 48,
                  height: isMobile ? 40 : 48,
                  decoration: BoxDecoration(
                    color: folder.isPaused
                        ? Colors.grey.withOpacity(0.15)
                        : const Color(0xFF0078D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: folder.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0078D4),
                            ),
                          )
                        : Icon(
                            folder.isPaused ? Icons.folder_off_outlined : Icons.folder_rounded,
                            color: folder.isPaused ? Colors.grey : const Color(0xFF0078D4),
                            size: isMobile ? 22 : 26,
                          ),
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              folder.folderName,
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (folder.isPaused)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Pausado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // PC <-> Celular
                      Row(
                        children: [
                          Icon(
                            Icons.devices,
                            size: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$localDeviceName ↔ ${folder.remoteDeviceName}',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                    visualDensity: VisualDensity.compact,
                    onPressed: onOpenFolder,
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: Color(0x1F94A3B8)),
            const SizedBox(height: 10),

            // Status e Estatísticas
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.isSyncing
                            ? 'Sincronizando em segundo plano...'
                            : (folder.isPaused ? 'Pausado pelo usuário' : folder.timeSinceLastSync),
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w600,
                          color: folder.isSyncing
                              ? const Color(0xFF0078D4)
                              : (folder.isPaused
                                  ? Colors.amber.shade700
                                  : (isDark ? Colors.white : const Color(0xFF1E293B))),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${folder.totalFiles} arqs • ${folder.humanReadableSize}',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Barra de Botões: Sincronizar, Pausar, Remover
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: folder.isSyncing || folder.isPaused ? null : onSyncNow,
                  icon: const Icon(Icons.sync, size: 14),
                  label: Text('Sincronizar', style: TextStyle(fontSize: isMobile ? 12 : 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),

                OutlinedButton.icon(
                  onPressed: onTogglePause,
                  icon: Icon(
                    folder.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 14,
                  ),
                  label: Text(folder.isPaused ? 'Retomar' : 'Pausar', style: TextStyle(fontSize: isMobile ? 12 : 13)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Spacer(),

                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remover sincronização',
                  visualDensity: VisualDensity.compact,
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
