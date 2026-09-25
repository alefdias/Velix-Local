import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../services/mdns_service.dart';
import '../services/pair_service.dart';
import '../widgets/device_card.dart';

class DevicesScreen extends StatelessWidget {
  final Function(Device)? onSendToDevice;

  const DevicesScreen({super.key, this.onSendToDevice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mdns = context.watch<MdnsDiscoveryService>();
    final pairService = context.watch<PairService>();
    final devices = mdns.devices;

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
                    const Text(
                      'Dispositivos na Rede',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Descoberta automática via mDNS e varredura corporativa de sub-rede para grandes empresas.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: mdns.isScanningSubnet ? null : () => mdns.scanSubnet(),
                      icon: mdns.isScanningSubnet
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.corporate_fare_rounded, size: 18),
                      label: Text(
                        mdns.isScanningSubnet
                            ? 'Varrendo Sub-rede (${(mdns.subnetScanProgress * 100).toInt()}%)'
                            : 'Varredura Corporativa',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: mdns.isSearching ? null : () => mdns.triggerManualScan(),
                      icon: mdns.isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(mdns.isSearching ? 'Buscando...' : 'Escanear Rede'),
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

            if (mdns.isScanningSubnet) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: mdns.subnetScanProgress > 0 ? mdns.subnetScanProgress : null,
                color: const Color(0xFF0078D4),
                backgroundColor: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
              ),
            ],

            const SizedBox(height: 24),

            // Card informativo de Recursos Corporativos e Pareamento Seguro
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242C) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_center_outlined, color: Color(0xFF0078D4), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modo Corporativo & Identificação Personalizada',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Você pode renomear qualquer computador da empresa (ex: "Computador X", "Servidor TI", "Financeiro"). Use a Varredura Corporativa para achar todos os computadores da sub-rede mesmo com roteadores restritivos.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (devices.isEmpty)
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
                    const Icon(Icons.radar, size: 48, color: Color(0xFF0078D4)),
                    const SizedBox(height: 16),
                    const Text(
                      'Buscando dispositivos na mesma rede...',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        'Abra o Velix Local no seu outro computador ou use o botão "Varredura Corporativa" para escanear ativamente toda a faixa de IPs da empresa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return DeviceCard(
                    device: device,
                    onRename: () => _showRenameDeviceDialog(context, device, mdns),
                    onPair: () => _initiatePairingModal(context, device),
                    onSendFiles: () {
                      if (onSendToDevice != null) {
                        onSendToDevice!(device);
                      }
                    },
                    onUnpair: () => pairService.unpairDevice(device.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDeviceDialog(BuildContext context, Device device, MdnsDiscoveryService mdns) {
    final controller = TextEditingController(text: device.customAlias ?? device.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: Color(0xFF0078D4)),
            const SizedBox(width: 10),
            const Text('Renomear Computador'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Defina um apelido claro para este computador (ótimo para redes com muitos PCs em empresas):',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Apelido do Computador',
                  hintText: 'ex: Computador X, Estação Financeiro, Servidor Projetos',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hostname original: ${device.name} • IP: ${device.ip}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          if (device.customAlias != null && device.customAlias!.isNotEmpty)
            TextButton(
              onPressed: () {
                mdns.renameDevice(device.id, '');
                Navigator.pop(ctx);
              },
              child: const Text('Restaurar Original', style: TextStyle(color: Colors.redAccent)),
            ),
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
            child: const Text('Salvar Apelido'),
          ),
        ],
      ),
    );
  }

  void _initiatePairingModal(BuildContext context, Device device) async {
    final pin = PairService.instance.generateSixDigitPin();
    bool isPairing = true;
    bool isSuccess = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (isPairing) {
              PairService.instance.initiatePairing(device).then((success) {
                if (ctx.mounted) {
                  setModalState(() {
                    isPairing = false;
                    isSuccess = success;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFF0078D4)),
                  const SizedBox(width: 10),
                  Text('Parear com ${device.resolvedName}'),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Código de Confirmação de 6 dígitos:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0078D4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0078D4).withOpacity(0.3)),
                      ),
                      child: Text(
                        '${pin.substring(0, 3)} ${pin.substring(3)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Color(0xFF0078D4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isPairing) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        'Aguardando confirmação no outro dispositivo...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (isSuccess) ...[
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'Dispositivo pareado com sucesso!',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ] else ...[
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'Falha ao parear ou solicitação recusada.',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(isPairing ? 'Cancelar' : 'Concluir'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
