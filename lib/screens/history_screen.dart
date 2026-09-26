import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transfer.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/file_action_service.dart';
import '../services/chunk_transfer_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<TransferItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    ChunkTransferService.instance.addListener(_onTransferChange);
  }

  @override
  void dispose() {
    ChunkTransferService.instance.removeListener(_onTransferChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onTransferChange() {
    if (mounted) {
      _loadHistory(_searchController.text);
    }
  }

  Future<void> _loadHistory([String? query]) async {
    setState(() => _isLoading = true);
    final items = await DatabaseService.instance.getTransferHistory(query: query);
    if (mounted) {
      setState(() {
        _history = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Título + Botão de Limpar
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Histórico',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Transferências locais salvas no SQLite.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => FileActionService.openFolder(SettingsService.instance.downloadDirectory, context),
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Downloads', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _loadHistory(_searchController.text),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        tooltip: 'Recarregar Histórico',
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _history.isEmpty ? null : _confirmClearHistory,
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                        tooltip: 'Limpar',
                        visualDensity: VisualDensity.compact,
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
                      const Text(
                        'Histórico de Transferências',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registro completo armazenado localmente em banco SQLite.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _loadHistory(_searchController.text),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Atualizar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => FileActionService.openFolder(SettingsService.instance.downloadDirectory, context),
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: const Text('Pasta de Downloads'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF333C4A) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      if (_history.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _confirmClearHistory,
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: const Text('Limpar Histórico'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Barra de Pesquisa
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome de arquivo, origem ou destino...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadHistory();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E242C) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              onChanged: (val) {
                _loadHistory(val);
              },
            ),

            const SizedBox(height: 20),

            // Tabela / Lista de Itens do Histórico
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 48,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Nenhuma transferência registrada'
                                    : 'Nenhum resultado para "${_searchController.text}"',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Arquivos enviados ou recebidos aparecerão aqui automaticamente.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _loadHistory(_searchController.text),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Atualizar Histórico'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadHistory(_searchController.text),
                          color: const Color(0xFF0078D4),
                          child: ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            final formattedDate = dateFormat.format(item.startTime);

                            // Duração
                            String durationText = '--';
                            if (item.endTime != null) {
                              final diff = item.endTime!.difference(item.startTime);
                              if (diff.inSeconds < 60) {
                                durationText = '${diff.inSeconds}s';
                              } else {
                                durationText = '${diff.inMinutes}m ${diff.inSeconds % 60}s';
                              }
                            }

                            final fileExists = item.localFilePath != null && File(item.localFilePath!).existsSync();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
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
                                  onTap: () => FileActionService.showTransferDetailsModal(context, item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Ícone de Direção
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: item.isIncoming
                                                ? const Color(0xFF10B981).withOpacity(0.12)
                                                : const Color(0xFF0078D4).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              item.isIncoming
                                                  ? Icons.download_rounded
                                                  : Icons.upload_rounded,
                                              color: item.isIncoming
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF0078D4),
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Detalhes do Arquivo
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
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    '${item.sourceDevice} → ${item.targetDevice}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(0xFF94A3B8)
                                                          : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '•',
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(0xFF64748B)
                                                          : const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    formattedDate,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(0xFF94A3B8)
                                                          : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Métricas: Tamanho, Velocidade, Duração
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              item.formattedFileSize,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${item.formattedSpeed} • $durationText',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),

                                        // Botão Ação Rápida 1: Abrir Arquivo
                                        if (fileExists)
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new_rounded, size: 20),
                                            tooltip: 'Abrir Arquivo',
                                            color: const Color(0xFF0078D4),
                                            onPressed: () => FileActionService.openFile(item.localFilePath!, context),
                                          ),

                                        // Botão Ação Rápida 2: Abrir Pasta
                                        IconButton(
                                          icon: const Icon(Icons.folder_open_rounded, size: 20),
                                          tooltip: 'Abrir Pasta',
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          onPressed: () => FileActionService.openFolder(
                                            item.localFilePath ?? SettingsService.instance.downloadDirectory,
                                            context,
                                          ),
                                        ),

                                        const SizedBox(width: 6),

                                        // Status Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: item.status == TransferStatus.completed
                                                ? const Color(0xFF10B981).withOpacity(0.12)
                                                : Colors.redAccent.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            item.status.displayName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: item.status == TransferStatus.completed
                                                  ? const Color(0xFF10B981)
                                                  : Colors.redAccent,
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
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar todo o histórico?'),
        content: const Text(
          'Esta ação removerá todos os registros de transferências anteriores do banco SQLite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await DatabaseService.instance.clearHistory();
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _loadHistory();
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }
}
