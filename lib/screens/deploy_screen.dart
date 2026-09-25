import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/device.dart';
import '../services/mdns_service.dart';
import '../services/deploy_service.dart';

class DeployScreen extends StatefulWidget {
  const DeployScreen({super.key});

  @override
  State<DeployScreen> createState() => _DeployScreenState();
}

class _DeployScreenState extends State<DeployScreen> {
  File? _selectedFile;
  final TextEditingController _argsController = TextEditingController();
  final Set<String> _selectedDeviceIds = {};

  void _pickInstallerFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione o instalador (.exe, .msi, .rpm, .deb, .sh, .apk)',
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _selectedFile = file;
        _argsController.text = DeployService.suggestSilentArguments(file.path);
      });
    }
  }

  void _toggleSelectAll(List<Device> onlineDevices) {
    setState(() {
      if (_selectedDeviceIds.length == onlineDevices.length) {
        _selectedDeviceIds.clear();
      } else {
        _selectedDeviceIds.clear();
        for (final d in onlineDevices) {
          _selectedDeviceIds.add(d.id);
        }
      }
    });
  }

  void _startDeploy(List<Device> onlineDevices) async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um arquivo instalador primeiro.')),
      );
      return;
    }

    final targets = onlineDevices.where((d) => _selectedDeviceIds.contains(d.id)).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um computador de destino.')),
      );
      return;
    }

    try {
      await DeployService.instance.deployInstaller(
        installerFile: _selectedFile!,
        customArguments: _argsController.text.trim(),
        targetDevices: targets,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar deploy: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mdns = context.watch<MdnsDiscoveryService>();
    final deployService = context.watch<DeployService>();
    final onlineDevices = mdns.onlineDevices;

    // Se a lista de selecionados estiver vazia e houver computadores, pré-seleciona todos
    if (_selectedDeviceIds.isEmpty && onlineDevices.isNotEmpty && !deployService.isDeploying) {
      for (final d in onlineDevices) {
        _selectedDeviceIds.add(d.id);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Deploy & Instalação em Massa',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.rocket_launch_rounded, color: Color(0xFF0078D4), size: 24),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dispare a instalação de softwares em múltiplos computadores da rede simultaneamente sem precisar encostar neles.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Card 1: Seleção do Instalador
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Selecione o Instalador',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: deployService.isDeploying ? null : _pickInstallerFile,
                        icon: const Icon(Icons.file_open_outlined, size: 18),
                        label: const Text('Escolher Instalador (.exe, .msi, .rpm, .deb, .sh)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0078D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_selectedFile != null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF13171D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p.basename(_selectedFile!.path),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(_selectedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _argsController,
                    enabled: !deployService.isDeploying,
                    decoration: InputDecoration(
                      labelText: 'Argumentos de Instalação Silenciosa (Silent Install)',
                      hintText: 'ex: /S, /quiet /qn, -y (ou deixe o padrão sugerido)',
                      helperText: 'O Velix preenche automaticamente os parâmetros ideais de acordo com a extensão do instalador.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Card 2: Seleção dos Computadores Alvo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '2. Selecione os Computadores de Destino',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (onlineDevices.isNotEmpty)
                        TextButton.icon(
                          onPressed: deployService.isDeploying ? null : () => _toggleSelectAll(onlineDevices),
                          icon: Icon(
                            _selectedDeviceIds.length == onlineDevices.length
                                ? Icons.deselect_outlined
                                : Icons.select_all_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _selectedDeviceIds.length == onlineDevices.length
                                ? 'Desmarcar Todos'
                                : 'Selecionar Todos da Rede',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (onlineDevices.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF13171D) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.devices_other, size: 36, color: Colors.grey),
                          SizedBox(height: 10),
                          Text(
                            'Nenhum outro computador online encontrado na rede no momento.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Certifique-se de que o Velix Local esteja aberto nos outros computadores.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: onlineDevices.map((dev) {
                        final isSelected = _selectedDeviceIds.contains(dev.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0078D4).withOpacity(isDark ? 0.15 : 0.06)
                                : (isDark ? const Color(0xFF13171D) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0078D4).withOpacity(0.4)
                                  : (isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            enabled: !deployService.isDeploying,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedDeviceIds.add(dev.id);
                                } else {
                                  _selectedDeviceIds.remove(dev.id);
                                }
                              });
                            },
                            title: Text(
                              dev.resolvedName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text('${dev.platform.displayName} • ${dev.ip}'),
                            secondary: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0078D4).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                dev.platform == DevicePlatformType.windows
                                    ? Icons.laptop_windows
                                    : (dev.platform == DevicePlatformType.linux
                                        ? Icons.terminal
                                        : Icons.devices),
                                color: const Color(0xFF0078D4),
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botão de Disparo
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: (deployService.isDeploying || onlineDevices.isEmpty || _selectedFile == null)
                    ? null
                    : () => _startDeploy(onlineDevices),
                icon: deployService.isDeploying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.rocket_launch_rounded, size: 20),
                label: Text(
                  deployService.isDeploying
                      ? 'Instalando nos computadores selecionados...'
                      : 'Disparar Instalação em Massa (${_selectedDeviceIds.length} selecionado${_selectedDeviceIds.length != 1 ? 's' : ''})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Card 3: Monitoramento em Tempo Real
            if (deployService.currentTasks.isNotEmpty) ...[
              const Text(
                'Status do Deploy em Tempo Real',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: deployService.currentTasks.map((task) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E242C) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: task.status == DeployStatus.success
                            ? const Color(0xFF10B981)
                            : (task.status == DeployStatus.error
                                ? Colors.redAccent
                                : (isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0))),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  task.status == DeployStatus.success
                                      ? Icons.check_circle_rounded
                                      : (task.status == DeployStatus.error
                                          ? Icons.error_rounded
                                          : Icons.sync),
                                  color: task.status == DeployStatus.success
                                      ? const Color(0xFF10B981)
                                      : (task.status == DeployStatus.error
                                          ? Colors.redAccent
                                          : const Color(0xFF0078D4)),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  task.targetDevice.resolvedName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${task.targetDevice.ip})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: task.status == DeployStatus.success
                                    ? const Color(0xFF10B981).withOpacity(0.12)
                                    : (task.status == DeployStatus.error
                                        ? Colors.redAccent.withOpacity(0.12)
                                        : const Color(0xFF0078D4).withOpacity(0.12)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.status == DeployStatus.success
                                    ? 'Sucesso'
                                    : (task.status == DeployStatus.error
                                        ? 'Falha'
                                        : (task.status == DeployStatus.uploading
                                            ? 'Enviando (${(task.progress * 100).toInt()}%)'
                                            : 'Instalando...')),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: task.status == DeployStatus.success
                                      ? const Color(0xFF10B981)
                                      : (task.status == DeployStatus.error
                                          ? Colors.redAccent
                                          : const Color(0xFF0078D4)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (task.status == DeployStatus.uploading) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: task.progress,
                              color: const Color(0xFF0078D4),
                              backgroundColor: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                              minHeight: 6,
                            ),
                          ),
                        ],
                        if (task.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            task.message!,
                            style: TextStyle(
                              fontSize: 12,
                              color: task.status == DeployStatus.error
                                  ? Colors.redAccent
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
