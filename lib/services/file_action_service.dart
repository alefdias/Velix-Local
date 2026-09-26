import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import '../models/transfer.dart';
import '../models/device.dart';
import 'settings_service.dart';
import 'chunk_transfer_service.dart';

class FileActionService {
  FileActionService._();

  /// Abre o arquivo no aplicativo padrão do sistema
  static Future<void> openFile(String filePath, BuildContext context) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Arquivo não encontrado no disco:\n$filePath',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        // Fallbacks para Linux e Windows se OpenFilex retornar erro
        if (Platform.isLinux) {
          await Process.run('xdg-open', [filePath]);
        } else if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '""', filePath]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [filePath]);
        }
      }
    } catch (e) {
      if (Platform.isLinux) {
        try {
          await Process.run('xdg-open', [filePath]);
          return;
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('Não foi possível abrir o arquivo: $e'),
          ),
        );
      }
    }
  }

  /// Abre a pasta no gerenciador de arquivos do sistema
  static Future<void> openFolder(String pathOrFile, BuildContext context) async {
    String folderPath = pathOrFile;

    // Se o caminho for um arquivo, pegar a pasta pai
    if (FileSystemEntity.isFileSync(pathOrFile) || (!Directory(pathOrFile).existsSync() && File(pathOrFile).existsSync())) {
      folderPath = p.dirname(pathOrFile);
    }

    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      // Tentar a pasta de download padrão se a pasta específica não existir
      folderPath = SettingsService.instance.downloadDirectory;
    }

    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [folderPath]);
        return;
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [folderPath]);
        return;
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
        return;
      } else if (Platform.isAndroid) {
        // No Android, abrir o gerenciador nativo de Downloads/Arquivos diretamente
        try {
          const platform = MethodChannel('com.velix.local/platform');
          final success = await platform.invokeMethod<bool>('openDownloadsFolder');
          if (success == true) return;
        } catch (e) {
          debugPrint('[FileActionService] Erro ao invocar openDownloadsFolder: $e');
        }

        // Se o gerenciador não abriu diretamente, exibir aviso explicativo com caminho legível
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0078D4),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_special_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Pasta de Downloads', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Salvo em: $folderPath', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  const Text('Abra o app "Files do Google" ou "Downloads" do seu celular para ver.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pasta: $folderPath'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Dispara a indexação do arquivo no MediaStore do Android para aparecer de imediato no Files/Galeria
  static Future<void> scanMedia(String filePath) async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.velix.local/platform');
        await platform.invokeMethod('scanFile', {'path': filePath});
      } catch (e) {
        debugPrint('[FileActionService] Erro scanFile: $e');
      }
    }
  }

  /// Verifica e solicita permissão de gerenciamento de armazenamento no Android se necessário
  static Future<void> checkAndRequestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.velix.local/platform');
        final hasPermission = await platform.invokeMethod<bool>('checkStoragePermission');
        if (hasPermission == false) {
          await platform.invokeMethod('requestStoragePermission');
        }
      } catch (e) {
        debugPrint('[FileActionService] Erro checkStoragePermission: $e');
      }
    }
  }

  /// Copia o caminho para a área de transferência
  static void copyPath(String path, BuildContext context) {
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Caminho copiado para a área de transferência!'),
          ],
        ),
      ),
    );
  }

  /// Exibe um modal completo de detalhes e ações sobre o arquivo transferido
  static void showTransferDetailsModal(BuildContext context, TransferItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filePath = item.localFilePath ?? '';
    final fileExists = filePath.isNotEmpty && File(filePath).existsSync();
    final folderPath = filePath.isNotEmpty
        ? (fileExists ? p.dirname(filePath) : filePath)
        : SettingsService.instance.downloadDirectory;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E242C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arraste
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cabeçalho com Ícone e Nome do Arquivo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getFileTypeColor(item.fileName).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        _getFileTypeIcon(item.fileName),
                        color: _getFileTypeColor(item.fileName),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.fileName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.status == TransferStatus.completed
                                    ? const Color(0xFF10B981).withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.status.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.status == TransferStatus.completed
                                      ? const Color(0xFF10B981)
                                      : Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.formattedFileSize,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Detalhes da Transferência
              _buildInfoRow(
                context,
                icon: Icons.swap_horiz_rounded,
                label: 'Fluxo',
                value: '${item.sourceDevice}  ➔  ${item.targetDevice}',
              ),
              const SizedBox(height: 10),

              _buildInfoRow(
                context,
                icon: Icons.speed_rounded,
                label: 'Velocidade',
                value: item.formattedSpeed,
              ),
              const SizedBox(height: 10),

              // Onde está salvo (Caminho e Destino Claro)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (item.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4)).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (item.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4)).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.isIncoming ? Icons.download_done_rounded : Icons.upload_file_rounded,
                          color: item.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.isIncoming ? 'Salvo no seu dispositivo em:' : 'Destino da transferência:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: item.isIncoming ? const Color(0xFF10B981) : const Color(0xFF0078D4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.isIncoming
                          ? (filePath.isNotEmpty ? filePath : 'Downloads/VelixLocal/${item.fileName}')
                          : 'Enviado para ${item.targetDevice} (Salvo na pasta Downloads dele)',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: item.isIncoming ? 'monospace' : null,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botões de Ação Imediata
              Row(
                children: [
                  // Botão 1: Abrir Arquivo (se disponível localmente)
                  if (fileExists) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          openFile(filePath, context);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Abrir Arquivo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0078D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Botão 2: Abrir Pasta de Downloads
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openFolder(folderPath, context);
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Abrir Downloads'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF333C4A) : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (filePath.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () => copyPath(filePath, context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copiar caminho',
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isPath = false,
    VoidCallback? onCopy,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: isPath ? 'monospace' : null,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            maxLines: isPath ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Copiar caminho',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onCopy,
          ),
      ],
    );
  }

  static IconData _getFileTypeIcon(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
        return Icons.image_rounded;
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
      case '.webm':
        return Icons.video_file_rounded;
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.m4a':
      case '.ogg':
        return Icons.audio_file_rounded;
      case '.pdf':
        return Icons.picture_as_pdf_rounded;
      case '.zip':
      case '.tar':
      case '.gz':
      case '.rar':
      case '.7z':
        return Icons.folder_zip_rounded;
      case '.apk':
        return Icons.android_rounded;
      case '.exe':
      case '.msi':
      case '.deb':
      case '.rpm':
        return Icons.terminal_rounded;
      case '.txt':
      case '.md':
      case '.json':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color _getFileTypeColor(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
        return const Color(0xFF3B82F6);
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
        return const Color(0xFFEF4444);
      case '.mp3':
      case '.wav':
      case '.flac':
        return const Color(0xFF8B5CF6);
      case '.pdf':
        return const Color(0xFFDC2626);
      case '.zip':
      case '.tar':
      case '.gz':
      case '.rar':
        return const Color(0xFFF59E0B);
      case '.apk':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF0078D4);
    }
  }

  /// Abre a câmera do celular/dispositivo, tira foto e envia imediatamente ao dispositivo de destino
  static Future<void> takePhotoAndSend(BuildContext context, Device targetDevice) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (photo != null) {
        final file = File(photo.path);
        if (await file.exists()) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Enviando foto da câmera para ${targetDevice.resolvedName}...'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
          await ChunkTransferService.instance.sendFile(
            targetDevice: targetDevice,
            file: file,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível abrir a câmera: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
