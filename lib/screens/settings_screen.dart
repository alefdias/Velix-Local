import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Configurações',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Personalize o comportamento do Velix Local no seu dispositivo.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 28),

            // Card 1: Identificação do Dispositivo
            _buildSectionCard(
              context,
              title: 'Identificação na Rede',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined, color: Color(0xFF0078D4)),
                  title: const Text('Nome do Dispositivo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(settings.deviceName),
                  trailing: OutlinedButton(
                    onPressed: () => _editDeviceName(context, settings),
                    child: const Text('Alterar'),
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fingerprint, color: Color(0xFF0078D4)),
                  title: const Text('ID Exclusivo do Dispositivo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    settings.deviceId,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Card 2: Armazenamento e Downloads
            _buildSectionCard(
              context,
              title: 'Armazenamento',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.download_for_offline_outlined, color: Color(0xFF10B981)),
                  title: const Text('Pasta de Downloads', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    settings.downloadDirectory.isNotEmpty
                        ? settings.downloadDirectory
                        : 'Padrão do Sistema',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final path = await FilePicker.platform.getDirectoryPath();
                      if (path != null) {
                        settings.setDownloadDirectory(path);
                      }
                    },
                    child: const Text('Mudar Pasta'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Card 3: Sincronização & Rede
            _buildSectionCard(
              context,
              title: 'Sincronização & Rede P2P',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.sync_rounded, color: Color(0xFF8B5CF6)),
                  title: const Text('Sincronização Automática Contínua', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Detecta modificações de arquivos em tempo real e sincroniza sem intervenção.'),
                  value: settings.autoSyncEnabled,
                  onChanged: (val) => settings.setAutoSyncEnabled(val),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lan_outlined, color: Color(0xFF8B5CF6)),
                  title: const Text('Porta do Servidor HTTP Local', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${settings.httpPort} (mDNS Broadcast: ${settings.discoveryPort})'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Card 4: Aparência
            _buildSectionCard(
              context,
              title: 'Aparência',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined, color: Color(0xFFF59E0B)),
                  title: const Text('Tema do Aplicativo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    settings.themeMode == 'dark'
                        ? 'Tema Escuro'
                        : (settings.themeMode == 'light' ? 'Tema Claro' : 'Padrão do Sistema'),
                  ),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'system', icon: Icon(Icons.brightness_auto, size: 16)),
                      ButtonSegment(value: 'light', icon: Icon(Icons.light_mode, size: 16)),
                      ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode, size: 16)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (newSelection) {
                      settings.setThemeMode(newSelection.first);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Card 5: Sobre o Velix Local
            _buildSectionCard(
              context,
              title: 'Sobre o Velix Local',
              children: [
                const Row(
                  children: [
                    Text(
                      'Velix Local',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'v1.0.0 (Build Stable)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Velix Local — Sincronize sem nuvem.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0078D4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Software de sincronização e transferência de arquivos peer-to-peer em rede local, totalmente independente da internet, nuvem ou servidores externos.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Licença MIT • Multiplataforma (Windows, Linux e Android)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
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
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  void _editDeviceName(BuildContext context, SettingsService settings) {
    final controller = TextEditingController(text: settings.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar Nome do Dispositivo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome do Dispositivo',
            hintText: 'ex: PC Sala, Notebook Trabalho',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                settings.setDeviceName(controller.text.trim());
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
