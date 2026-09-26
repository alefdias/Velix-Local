import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mdns_service.dart';
import '../services/sync_service.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/chunk_transfer_service.dart';
import '../services/file_action_service.dart';
import '../models/transfer.dart';
import '../widgets/device_card.dart';
import '../widgets/sync_card.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TransferItem> _recentTransfers = [];

  @override
  void initState() {
    super.initState();
    _loadRecentTransfers();
  }

  Future<void> _loadRecentTransfers() async {
    final history = await DatabaseService.instance.getTransferHistory();
    if (mounted) {
      setState(() {
        _recentTransfers = history.take(4).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mdns = context.watch<MdnsDiscoveryService>();
    final syncService = context.watch<SyncService>();
    final settings = context.watch<SettingsService>();
    final onlineDevices = mdns.onlineDevices;

    // Calcular estatísticas totais
    int totalSyncedFiles = 0;
    int totalSyncedBytes = 0;
    for (final f in syncService.folders) {
      totalSyncedFiles += f.totalFiles;
      totalSyncedBytes += f.totalSize;
    }

    String formattedSyncedSize = _formatBytes(totalSyncedBytes);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Boas-vindas / Hero com gradiente sutil
            Container(
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF161F2E), const Color(0xFF131822)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
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
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroInfo(isDark, settings),
                        const SizedBox(height: 16),
                        _buildHeroActions(isDark, settings, mdns, fullWidth: true),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildHeroInfo(isDark, settings)),
                        const SizedBox(width: 16),
                        _buildHeroActions(isDark, settings, mdns, fullWidth: false),
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // Métricas em Cards de Estatísticas
            isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatCard(
                          context,
                          title: 'Dispositivos Online',
                          value: '${onlineDevices.length}',
                          subtitle: '${mdns.devices.length} na vizinhança',
                          icon: Icons.devices_rounded,
                          color: const Color(0xFF0078D4),
                          isExpanded: false,
                          width: 165,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          context,
                          title: 'Pastas Sincronizadas',
                          value: '${syncService.folders.length}',
                          subtitle: syncService.isSyncingAny ? 'Sincronizando' : 'Em tempo real',
                          icon: Icons.folder_special_rounded,
                          color: const Color(0xFF10B981),
                          isExpanded: false,
                          width: 165,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          context,
                          title: 'Espaço Sincronizado',
                          value: formattedSyncedSize,
                          subtitle: '$totalSyncedFiles arquivos',
                          icon: Icons.pie_chart_rounded,
                          color: const Color(0xFF8B5CF6),
                          isExpanded: false,
                          width: 165,
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      _buildStatCard(
                        context,
                        title: 'Dispositivos Online',
                        value: '${onlineDevices.length}',
                        subtitle: '${mdns.devices.length} na vizinhança',
                        icon: Icons.devices_rounded,
                        color: const Color(0xFF0078D4),
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        context,
                        title: 'Pastas Sincronizadas',
                        value: '${syncService.folders.length}',
                        subtitle: syncService.isSyncingAny ? 'Sincronizando agora' : 'Em tempo real',
                        icon: Icons.folder_special_rounded,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        context,
                        title: 'Espaço Sincronizado',
                        value: formattedSyncedSize,
                        subtitle: '$totalSyncedFiles arquivos gerenciados',
                        icon: Icons.pie_chart_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // Seção: Pastas Sincronizadas Recentes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pastas Sincronizadas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => widget.onNavigate(1), // Aba Sync
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Gerenciar Pastas'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (syncService.folders.isEmpty)
              _buildEmptyState(
                context,
                title: 'Nenhuma pasta sincronizada ainda',
                subtitle: 'Adicione uma pasta para sincronizar automaticamente com outro computador ou celular na rede.',
                buttonText: 'Adicionar Pasta no Velix Sync',
                icon: Icons.folder_open_rounded,
                onAction: () => widget.onNavigate(1),
              )
            else
              Column(
                children: syncService.folders.take(2).map((folder) {
                  return SyncCard(
                    folder: folder,
                    localDeviceName: settings.deviceName,
                    onSyncNow: () => syncService.syncFolder(folder.id),
                    onTogglePause: () => syncService.togglePauseFolder(folder.id),
                    onRemove: () => syncService.removeFolder(folder.id),
                  );
                }).toList(),
              ),

            const SizedBox(height: 28),

            // Seção: Dispositivos Conectados
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dispositivos na Rede Local',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => widget.onNavigate(0), // Aba Dispositivos
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Ver Todos'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (mdns.devices.isEmpty)
              _buildEmptyState(
                context,
                title: 'Nenhum dispositivo encontrado no momento',
                subtitle: 'Certifique-se de que os outros dispositivos estão na mesma rede Wi-Fi ou cabo e com o Velix aberto.',
                buttonText: 'Buscar Dispositivos',
                icon: Icons.wifi_find_rounded,
                onAction: () => mdns.triggerManualScan(),
              )
            else
              Column(
                children: mdns.devices.take(3).map((device) {
                  return DeviceCard(
                    device: device,
                    onRename: () => _showRenameDialog(context, device, mdns),
                    onPair: () => widget.onNavigate(0),
                    onSendFiles: () => widget.onNavigate(2),
                  );
                }).toList(),
              ),

            const SizedBox(height: 28),

            // Seção: Últimas Atividades
            if (_recentTransfers.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Últimas Atividades',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.onNavigate(4),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Ver Histórico'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTransfers.length,
                itemBuilder: (ctx, i) {
                  final t = _recentTransfers[i];
                  final fileExists = t.localFilePath != null && File(t.localFilePath!).existsSync();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E242C) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => FileActionService.showTransferDetailsModal(context, t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Ícone do tipo de arquivo / direção
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: t.isIncoming
                                      ? const Color(0xFF10B981).withOpacity(0.12)
                                      : const Color(0xFF0078D4).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(
                                    t.isIncoming ? Icons.download_rounded : Icons.upload_rounded,
                                    size: 20,
                                    color: t.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Informações do Arquivo
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.fileName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.sourceDevice} → ${t.targetDevice} • ${t.formattedFileSize}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Botão Ação Rápida 1: Abrir Arquivo (se existir)
                              if (fileExists)
                                IconButton(
                                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                                  tooltip: 'Abrir Arquivo',
                                  color: const Color(0xFF0078D4),
                                  onPressed: () => FileActionService.openFile(t.localFilePath!, context),
                                ),

                              // Botão Ação Rápida 2: Abrir Pasta
                              IconButton(
                                icon: const Icon(Icons.folder_open_rounded, size: 20),
                                tooltip: 'Abrir Pasta',
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                onPressed: () => FileActionService.openFolder(
                                  t.localFilePath ?? settings.downloadDirectory,
                                  context,
                                ),
                              ),

                              const SizedBox(width: 4),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: t.status == TransferStatus.completed
                                      ? const Color(0xFF10B981).withOpacity(0.12)
                                      : Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t.status.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: t.status == TransferStatus.completed
                                        ? const Color(0xFF10B981)
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroInfo(bool isDark, SettingsService settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0078D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_tethering, size: 14, color: Color(0xFF0078D4)),
                  SizedBox(width: 6),
                  Text(
                    'P2P Local Ativo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0078D4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Olá, ${settings.deviceName}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          'Sincronize arquivos na mesma rede local de forma instantânea, contínua e sem internet.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroActions(bool isDark, SettingsService settings, MdnsDiscoveryService mdns, {required bool fullWidth}) {
    final buttons = [
      OutlinedButton.icon(
        onPressed: () => FileActionService.openFolder(settings.downloadDirectory, context),
        icon: const Icon(Icons.folder_open_rounded, size: 18),
        label: const Text('Downloads'),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
          side: BorderSide(
            color: isDark ? const Color(0xFF333C4A) : const Color(0xFFCBD5E1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      ElevatedButton.icon(
        onPressed: () => mdns.triggerManualScan(),
        icon: mdns.isSearching
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.refresh_rounded, size: 18),
        label: Text(mdns.isSearching ? 'Buscando...' : 'Buscar Rede'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0078D4),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ];

    if (fullWidth) {
      return Row(
        children: [
          Expanded(child: buttons[0]),
          const SizedBox(width: 10),
          Expanded(child: buttons[1]),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: buttons,
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isExpanded = true,
    double? width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (isExpanded) {
      return Expanded(child: card);
    }
    return card;
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    required VoidCallback onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242C).withOpacity(0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _showRenameDialog(BuildContext context, dynamic device, MdnsDiscoveryService mdns) {
    final controller = TextEditingController(text: device.customAlias ?? device.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF0078D4)),
            SizedBox(width: 10),
            Text('Renomear Computador'),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Defina um apelido para identificar este computador na empresa:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Apelido (ex: Computador X, Sala 3)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                mdns.renameDevice(device.id, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
