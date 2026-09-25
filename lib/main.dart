import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/mdns_service.dart';
import 'services/chunk_transfer_service.dart';
import 'services/sync_service.dart';
import 'services/pair_service.dart';
import 'models/device.dart';

import 'widgets/sidebar.dart';
import 'screens/home_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/sync_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VelixLocalApp());
}

class VelixLocalApp extends StatelessWidget {
  const VelixLocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SettingsService.instance),
        ChangeNotifierProvider.value(value: MdnsDiscoveryService.instance),
        ChangeNotifierProvider.value(value: ChunkTransferService.instance),
        ChangeNotifierProvider.value(value: SyncService.instance),
        ChangeNotifierProvider.value(value: PairService.instance),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          ThemeMode currentMode;
          if (settings.themeMode == 'light') {
            currentMode = ThemeMode.light;
          } else if (settings.themeMode == 'dark') {
            currentMode = ThemeMode.dark;
          } else {
            currentMode = ThemeMode.system;
          }

          return MaterialApp(
            title: 'Velix Local',
            debugShowCheckedModeBanner: false,
            themeMode: currentMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const AppInitializer(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0078D4),
        brightness: Brightness.light,
        surface: const Color(0xFFF8FAFC),
        surfaceContainerLowest: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      fontFamily: Platform.isWindows ? 'Segoe UI' : null,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0078D4),
        brightness: Brightness.dark,
        surface: const Color(0xFF13171D),
        surfaceContainerLowest: const Color(0xFF0D1117),
      ),
      scaffoldBackgroundColor: const Color(0xFF0E1217),
      fontFamily: Platform.isWindows ? 'Segoe UI' : null,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isReady = false;
  String _statusMessage = 'Inicializando serviços locais...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Conectando ao banco de dados SQLite...';
    });

    try {
      // 1. Inicializar SQLite
      await DatabaseService.instance.database;

      if (mounted) {
        setState(() => _statusMessage = 'Carregando configurações locais...');
      }

      // 2. Inicializar Configurações Locais
      await SettingsService.instance.init();

      if (mounted) {
        setState(() => _statusMessage = 'Iniciando servidor HTTP P2P...');
      }

      // 3. Iniciar Servidor HTTP Local para transferência de blocos
      await ChunkTransferService.instance.startServer();

      if (mounted) {
        setState(() => _statusMessage = 'Iniciando descoberta de rede mDNS...');
      }

      // 4. Iniciar Descoberta Automática de Rede mDNS / UDP
      await MdnsDiscoveryService.instance.startDiscovery();

      // 5. Iniciar Motor do Velix Sync
      await SyncService.instance.init();

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return const MainScaffold();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1217) : const Color(0xFFF1F5F9),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(36),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E242C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0078D4), Color(0xFF00C7FF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.all_inclusive, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Velix Local',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sincronize sem nuvem',
                style: TextStyle(fontSize: 13, color: Color(0xFF0078D4), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),
              if (_errorMessage != null) ...[
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _startInitialization,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                ),
              ] else ...[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0078D4)),
                ),
                const SizedBox(height: 18),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // 0: Dispositivos, 1: Sync, 2: Transferências, 3: Histórico, 4: Configurações, 5: Home (visão inicial)
  int _selectedIndex = 5; // Começa na Home
  Device? _deviceForTransfer;

  @override
  void initState() {
    super.initState();
    // Escuta solicitações de pareamento recebidas para abrir o modal de confirmação
    PairService.instance.onPairRequest.listen((req) {
      if (mounted) {
        _showIncomingPairDialog(req);
      }
    });
  }

  void _showIncomingPairDialog(PairRequestInfo req) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF0078D4)),
            const SizedBox(width: 10),
            const Text('Solicitação de Pareamento'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'O dispositivo "${req.remoteDevice.name}" (${req.remoteDevice.platform.displayName}) deseja parear com seu aparelho.',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text(
                'Confirme se o código abaixo é idêntico em ambos:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0078D4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0078D4).withOpacity(0.3)),
                ),
                child: Text(
                  '${req.pinCode.substring(0, 3)} ${req.pinCode.substring(3)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Color(0xFF0078D4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Após a confirmação, o dispositivo será salvo como confiável e nunca mais solicitará código.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              PairService.instance.rejectIncomingPairRequest();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Recusar', style: TextStyle(color: Colors.redAccent)),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await PairService.instance.acceptIncomingPairRequest();
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
                messenger.showSnackBar(
                  SnackBar(content: Text('Dispositivo "${req.remoteDevice.name}" pareado com sucesso!')),
                );
              }
            },
            child: const Text('Confirmar e Parear'),
          ),
        ],
      ),
    );
  }

  void _onNavigate(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _sendToDevice(Device device) {
    setState(() {
      _deviceForTransfer = device;
      _selectedIndex = 2; // Tela de Transferência
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final mdns = context.watch<MdnsDiscoveryService>();
    final syncService = context.watch<SyncService>();
    final chunkTransfer = context.watch<ChunkTransferService>();
    final settings = context.watch<SettingsService>();

    Widget currentBody;
    switch (_selectedIndex) {
      case 0:
        currentBody = DevicesScreen(onSendToDevice: _sendToDevice);
        break;
      case 1:
        currentBody = const SyncScreen();
        break;
      case 2:
        currentBody = TransferScreen(initialTargetDevice: _deviceForTransfer);
        break;
      case 3:
        currentBody = const HistoryScreen();
        break;
      case 4:
        currentBody = const SettingsScreen();
        break;
      case 5:
      default:
        currentBody = HomeScreen(onNavigate: _onNavigate);
        break;
    }

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            Sidebar(
              selectedIndex: _selectedIndex == 5 ? -1 : _selectedIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  _selectedIndex = idx;
                });
              },
              onlineDevicesCount: mdns.onlineDevices.length,
              activeSyncCount: syncService.folders.length,
              activeTransfersCount: chunkTransfer.activeTransfers.length,
              localDeviceName: settings.deviceName,
              localIp: mdns.devices.isNotEmpty ? mdns.devices.first.ip : '127.0.0.1',
            ),
            Expanded(
              child: Column(
                children: [
                  // Barra de Atalho Superior com botão "Home / Visão Geral"
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => _onNavigate(5),
                          icon: Icon(
                            Icons.dashboard_outlined,
                            size: 18,
                            color: _selectedIndex == 5 ? const Color(0xFF0078D4) : null,
                          ),
                          label: Text(
                            'Visão Geral (Home)',
                            style: TextStyle(
                              fontWeight: _selectedIndex == 5 ? FontWeight.bold : FontWeight.normal,
                              color: _selectedIndex == 5 ? const Color(0xFF0078D4) : null,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            if (syncService.isSyncingAny)
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0078D4).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Sincronizando pastas...',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF0078D4)),
                                    ),
                                  ],
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, size: 20),
                              tooltip: 'Configurações',
                              onPressed: () => _onNavigate(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: currentBody),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Layout Mobile (Android / Telas pequenas)
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0078D4), Color(0xFF00C7FF)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.all_inclusive, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Velix Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Home',
              onPressed: () => _onNavigate(5),
            ),
          ],
        ),
        body: currentBody,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex == 5 ? 0 : (_selectedIndex.clamp(0, 4)),
          onDestinationSelected: (idx) {
            setState(() {
              _selectedIndex = idx;
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.devices_outlined),
              selectedIcon: const Icon(Icons.devices),
              label: 'Dispositivos',
            ),
            NavigationDestination(
              icon: const Icon(Icons.sync_outlined),
              selectedIcon: const Icon(Icons.sync),
              label: 'Sync',
            ),
            NavigationDestination(
              icon: const Icon(Icons.swap_horiz_outlined),
              selectedIcon: const Icon(Icons.swap_horiz),
              label: 'Transferir',
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: 'Histórico',
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      );
    }
  }
}
