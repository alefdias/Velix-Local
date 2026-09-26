import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

import '../services/sync_service.dart';
import '../services/settings_service.dart';
import '../services/mdns_service.dart';
import '../models/device.dart';
import '../models/sync_folder.dart';
import '../widgets/sync_card.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final syncService = context.watch<SyncService>();
    final settings = context.watch<SettingsService>();
    final folders = syncService.folders;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Título + Botões Responsivos
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Velix Sync',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.star, color: Colors.amber, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sincronização bidirecional em tempo real.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (folders.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: syncService.isSyncingAny
                                ? null
                                : () => syncService.syncAllActiveFolders(),
                            icon: syncService.isSyncingAny
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: const Text('Sincronizar', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddFolderDialog(context),
                          icon: const Icon(Icons.create_new_folder_rounded, size: 16),
                          label: const Text('Nova Pasta', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0078D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Velix Sync',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.star, color: Colors.amber, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sincronização bidirecional em tempo real entre computadores e celulares.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (folders.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: syncService.isSyncingAny
                              ? null
                              : () => syncService.syncAllActiveFolders(),
                          icon: syncService.isSyncingAny
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('Sincronizar Todas'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddFolderDialog(context),
                        icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                        label: const Text('Adicionar Pasta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0078D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Card informativo de recursos do Sync
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F2E) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF0078D4), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detecção Automática e Resolução de Conflitos',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qualquer alteração em um dispositivo sincroniza automaticamente com o outro. Conflitos geram cópias "arquivo (Dispositivo).ext".',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (folders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E242C) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0078D4).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.folder_shared_rounded, color: Color(0xFF0078D4), size: 36),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Nenhuma pasta configurada',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Text(
                        'Escolha uma pasta (ex: Documentos/Projetos, Fotos ou Downloads) para mantê-la sempre idêntica em seus computadores e notebooks.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () => _showAddFolderDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Configurar Primeira Pasta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return SyncCard(
                    folder: folder,
                    localDeviceName: settings.deviceName,
                    onSyncNow: () => syncService.syncFolder(folder.id),
                    onTogglePause: () => syncService.togglePauseFolder(folder.id),
                    onRemove: () => _confirmRemoveFolder(context, folder),
                    onOpenFolder: () {
                      try {
                        OpenFilex.open(folder.localPath);
                      } catch (_) {}
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveFolder(BuildContext context, SyncFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover sincronização?'),
        content: Text(
          'Deseja interromper a sincronização da pasta "${folder.folderName}"? Os arquivos locais serão mantidos intactos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              SyncService.instance.removeFolder(folder.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context) {
    final mdns = MdnsDiscoveryService.instance;
    final availableDevices = mdns.devices;

    String folderPath = '';
    String folderName = '';
    Device? selectedDevice = availableDevices.isNotEmpty ? availableDevices.first : null;

    final pathController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.create_new_folder, color: Color(0xFF0078D4)),
                  SizedBox(width: 10),
                  Text('Adicionar Pasta no Velix Sync'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecione a pasta que deseja manter sincronizada com outro dispositivo:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Seleção da Pasta Local
                    TextField(
                      controller: pathController,
                      decoration: InputDecoration(
                        labelText: 'Caminho da Pasta Local',
                        hintText: '/home/usuario/Documentos/Projetos',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Navegar',
                          onPressed: () async {
                            final result = await FilePicker.platform.getDirectoryPath();
                            if (result != null) {
                              setDialogState(() {
                                folderPath = result;
                                pathController.text = result;
                                if (folderName.isEmpty) {
                                  folderName = p.basename(result);
                                  nameController.text = folderName;
                                }
                              });
                            }
                          },
                        ),
                      ),
                      onChanged: (val) {
                        folderPath = val;
                        if (folderName.isEmpty && val.isNotEmpty) {
                          folderName = p.basename(val);
                          nameController.text = folderName;
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Nome Amigável
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome da Pasta (ex: Projetos, Fotos)',
                        hintText: 'Projetos',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => folderName = val,
                    ),

                    const SizedBox(height: 16),

                    // Atalhos Rápidos
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildQuickFolderChip('Projetos', setDialogState, nameController),
                        _buildQuickFolderChip('Documentos', setDialogState, nameController),
                        _buildQuickFolderChip('Fotos', setDialogState, nameController),
                        _buildQuickFolderChip('Downloads', setDialogState, nameController),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Dispositivo Parceiro
                    const Text(
                      'Sincronizar com o dispositivo:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    if (availableDevices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nenhum outro dispositivo Velix online. Você pode configurar a pasta e a sincronização começará assim que o dispositivo aparecer na rede.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<Device>(
                        value: selectedDevice,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        items: availableDevices.map((dev) {
                          return DropdownMenuItem<Device>(
                            value: dev,
                            child: Row(
                              children: [
                                Icon(
                                  dev.platform == DevicePlatformType.windows
                                      ? Icons.laptop_windows
                                      : (dev.platform == DevicePlatformType.android
                                          ? Icons.phone_android
                                          : Icons.computer),
                                  size: 18,
                                  color: const Color(0xFF0078D4),
                                ),
                                const SizedBox(width: 10),
                                Text('${dev.name} (${dev.platform.displayName})'),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newDev) {
                          setDialogState(() {
                            selectedDevice = newDev;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (folderPath.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor, selecione ou digite uma pasta válida.')),
                      );
                      return;
                    }

                    final finalName = folderName.trim().isNotEmpty
                        ? folderName.trim()
                        : p.basename(folderPath);

                    final partnerDevice = selectedDevice ??
                        Device(
                          id: 'pending-partner',
                          name: 'Dispositivo na Rede',
                          platform: DevicePlatformType.unknown,
                          ip: '',
                          port: 53318,
                        );

                    await SyncService.instance.addSyncFolder(
                      localPath: folderPath.trim(),
                      folderName: finalName,
                      targetDevice: partnerDevice,
                    );

                    if (context.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Pasta "$finalName" adicionada ao Velix Sync com sucesso!')),
                      );
                    }
                  },
                  child: const Text('Salvar e Sincronizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickFolderChip(
    String label,
    StateSetter setDialogState,
    TextEditingController nameController,
  ) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setDialogState(() {
          nameController.text = label;
        });
      },
    );
  }
}
