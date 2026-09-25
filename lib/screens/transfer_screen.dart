import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;

import '../models/device.dart';
import '../services/chunk_transfer_service.dart';
import '../services/mdns_service.dart';
import '../widgets/progress_widget.dart';

class TransferScreen extends StatefulWidget {
  final Device? initialTargetDevice;

  const TransferScreen({super.key, this.initialTargetDevice});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  Device? _selectedDevice;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _selectedDevice = widget.initialTargetDevice;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mdns = context.watch<MdnsDiscoveryService>();
    final chunkTransfer = context.watch<ChunkTransferService>();
    final onlineDevices = mdns.onlineDevices;

    if (_selectedDevice == null && onlineDevices.isNotEmpty) {
      _selectedDevice = onlineDevices.first;
    }

    final activeList = chunkTransfer.activeTransfers;

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
                          'Transferência Inteligente',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.bolt, color: Color(0xFF0078D4), size: 24),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Envio manual em alta velocidade com retomada automática por blocos (Chunk Transfer).',
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

            // Seleção de Dispositivo Destino
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: Color(0xFF0078D4), size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Destinatário:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  if (onlineDevices.isEmpty)
                    const Expanded(
                      child: Text(
                        'Nenhum dispositivo online na rede. Abra o Velix Local em outro aparelho.',
                        style: TextStyle(color: Colors.amber, fontSize: 13),
                      ),
                    )
                  else
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Device>(
                          value: onlineDevices.contains(_selectedDevice)
                              ? _selectedDevice
                              : onlineDevices.first,
                          isExpanded: true,
                          items: onlineDevices.map((dev) {
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
                                  Text(
                                    '${dev.resolvedName} • ${dev.platform.displayName} (${dev.ip})',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (dev) {
                            setState(() {
                              _selectedDevice = dev;
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Área de Drag & Drop de Arquivos
            DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                final files = details.files.map((x) => File(x.path)).toList();
                _handleSelectedFiles(files);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: _isDragging
                      ? const Color(0xFF0078D4).withOpacity(0.08)
                      : (isDark ? const Color(0xFF1E242C) : Colors.white),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isDragging
                        ? const Color(0xFF0078D4)
                        : (isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0)),
                    width: _isDragging ? 2.0 : 1.5,
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
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFF0078D4),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Arraste e solte arquivos aqui',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Suporta qualquer tipo de arquivo, pastas inteiras ou textos. Sem limites de tamanho.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botões de Seleção: Múltiplos Arquivos, Pasta, Imagens, Texto
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.file_copy_outlined, size: 16),
                          label: const Text('Selecionar Arquivos'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickFolder,
                          icon: const Icon(Icons.folder_outlined, size: 16),
                          label: const Text('Enviar Pasta'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Imagens'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _sendQuickText,
                          icon: const Icon(Icons.text_fields_rounded, size: 16),
                          label: const Text('Enviar Texto'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Lista de Transferências Ativas / Em Progresso
            if (activeList.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transferências em Andamento (${activeList.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeList.length,
                itemBuilder: (context, index) {
                  final item = activeList[index];
                  return ProgressWidget(
                    item: item,
                    onCancel: () => chunkTransfer.cancelTransfer(item.sessionId),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.paths.isNotEmpty) {
      final files = result.paths
          .where((p) => p != null)
          .map((p) => File(p!))
          .where((f) => f.existsSync())
          .toList();
      _handleSelectedFiles(files);
    }
  }

  Future<void> _pickFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath != null) {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        final List<File> files = [];
        try {
          final entities = dir.listSync(recursive: true);
          for (final e in entities) {
            if (e is File) files.add(e);
          }
        } catch (_) {}
        _handleSelectedFiles(files);
      }
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.paths.isNotEmpty) {
      final files = result.paths
          .where((p) => p != null)
          .map((p) => File(p!))
          .where((f) => f.existsSync())
          .toList();
      _handleSelectedFiles(files);
    }
  }

  Future<void> _sendQuickText() async {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enviar Texto / Recorte'),
        content: TextField(
          controller: textController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Cole links, códigos, mensagens ou notas para enviar diretamente ao outro dispositivo...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogCtx);
                final tempDir = Directory.systemTemp;
                final textFile = File(p.join(
                  tempDir.path,
                  'texto_${DateTime.now().millisecondsSinceEpoch}.txt',
                ));
                await textFile.writeAsString(text);
                _handleSelectedFiles([textFile]);
              }
            },
            child: const Text('Enviar Texto'),
          ),
        ],
      ),
    );
  }

  void _handleSelectedFiles(List<File> files) {
    if (files.isEmpty) return;

    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um dispositivo destinatário antes de enviar.')),
      );
      return;
    }

    final target = _selectedDevice!;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Enviando ${files.length} arquivo(s) para ${target.resolvedName}...')),
    );

    for (final file in files) {
      ChunkTransferService.instance.sendFile(
        targetDevice: target,
        file: file,
      );
    }
  }
}
