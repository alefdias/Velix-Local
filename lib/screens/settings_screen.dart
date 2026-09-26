import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import '../services/file_action_service.dart';
import '../services/i18n_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsService>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              I18n.t('settings_title'),
              style: TextStyle(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              I18n.t('settings_desc'),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 20),

            // Card 0: Seleção de Idioma (12 Idiomas Mundiais)
            _buildSectionCard(
              context,
              title: I18n.t('language_section'),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF0078D4)),
                  title: Text(I18n.t('language_select'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    I18n.supportedLanguages[settings.language] ?? settings.language,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0078D4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: I18n.supportedLanguages.containsKey(settings.language) ? settings.language : 'auto',
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0078D4)),
                      dropdownColor: isDark ? const Color(0xFF1E242C) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      items: I18n.supportedLanguages.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: entry.key == settings.language ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newLang) {
                        if (newLang != null) {
                          settings.setLanguage(newLang);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Card 1: Identificação do Dispositivo
            _buildSectionCard(
              context,
              title: I18n.t('device_id_section'),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined, color: Color(0xFF0078D4)),
                  title: Text(I18n.t('device_name'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(settings.deviceName, style: const TextStyle(fontSize: 13)),
                  trailing: OutlinedButton(
                    onPressed: () => _editDeviceName(context, settings),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(I18n.t('btn_change'), style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fingerprint, color: Color(0xFF0078D4)),
                  title: Text(I18n.t('device_id'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.deviceId,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Card 2: Armazenamento e Downloads
            _buildSectionCard(
              context,
              title: I18n.t('storage_section'),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_for_offline_outlined, color: Color(0xFF10B981), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(I18n.t('download_folder'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 36.0),
                      child: Text(
                        settings.downloadDirectory.isNotEmpty
                            ? settings.downloadDirectory
                            : I18n.t('default_system'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => FileActionService.openFolder(settings.downloadDirectory, context),
                          icon: const Icon(Icons.folder_open_rounded, size: 14),
                          label: Text(I18n.t('btn_open'), style: const TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0078D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final path = await FilePicker.platform.getDirectoryPath();
                            if (path != null) {
                              settings.setDownloadDirectory(path);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: Text(I18n.t('btn_edit'), style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Card 3: Sincronização & Rede
            _buildSectionCard(
              context,
              title: I18n.t('sync_network_section'),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.sync_rounded, color: Color(0xFF8B5CF6)),
                  title: Text(I18n.t('auto_sync_title'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(I18n.t('auto_sync_desc')),
                  value: settings.autoSyncEnabled,
                  onChanged: (val) => settings.setAutoSyncEnabled(val),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lan_outlined, color: Color(0xFF8B5CF6)),
                  title: Text(I18n.t('http_port_title'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${settings.httpPort} (mDNS Broadcast: ${settings.discoveryPort})'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Card 4: Aparência
            _buildSectionCard(
              context,
              title: I18n.t('appearance_section'),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined, color: Color(0xFFF59E0B)),
                  title: Text(I18n.t('theme_title'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    settings.themeMode == 'dark'
                        ? I18n.t('theme_dark')
                        : (settings.themeMode == 'light' ? I18n.t('theme_light') : I18n.t('theme_system')),
                  ),
                  trailing: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'system', icon: const Icon(Icons.brightness_auto, size: 16), label: Text(I18n.t('theme_system'))),
                      ButtonSegment(value: 'light', icon: const Icon(Icons.light_mode, size: 16), label: Text(I18n.t('theme_light'))),
                      ButtonSegment(value: 'dark', icon: const Icon(Icons.dark_mode, size: 16), label: Text(I18n.t('theme_dark'))),
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
              title: I18n.t('about_section'),
              children: [
                const Row(
                  children: [
                    Text(
                      'Velix Local',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'v1.0.16 (Build Stable)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Velix Local — ${I18n.t('slogan')}.',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0078D4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  I18n.t('about_desc'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.t('license_info'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
