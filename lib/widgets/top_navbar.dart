import 'package:flutter/material.dart';

class TopNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;

  const TopNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

class TopNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final int onlineDevicesCount;
  final int activeSyncCount;
  final int activeTransfersCount;
  final String localDeviceName;
  final String localIp;
  final bool isSyncingAny;

  const TopNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onlineDevicesCount = 0,
    this.activeSyncCount = 0,
    this.activeTransfersCount = 0,
    required this.localDeviceName,
    required this.localIp,
    this.isSyncingAny = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = [
      TopNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Início',
      ),
      TopNavItem(
        icon: Icons.devices_outlined,
        activeIcon: Icons.devices_rounded,
        label: 'Dispositivos',
        badgeCount: onlineDevicesCount > 0 ? onlineDevicesCount : null,
      ),
      TopNavItem(
        icon: Icons.sync_outlined,
        activeIcon: Icons.sync_rounded,
        label: 'Sync',
        badgeCount: activeSyncCount > 0 ? activeSyncCount : null,
      ),
      TopNavItem(
        icon: Icons.swap_horiz_outlined,
        activeIcon: Icons.swap_horiz_rounded,
        label: 'Transferir',
        badgeCount: activeTransfersCount > 0 ? activeTransfersCount : null,
      ),
      const TopNavItem(
        icon: Icons.rocket_launch_outlined,
        activeIcon: Icons.rocket_launch_rounded,
        label: 'Deploy',
      ),
      const TopNavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
        label: 'Histórico',
      ),
      const TopNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Ajustes',
      ),
    ];

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13171D) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Logo & Slogan à Esquerda
          InkWell(
            onTap: () => onDestinationSelected(5),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF0078D4).withOpacity(0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0078D4).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset('assets/logo.png', width: 28, height: 28, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Velix Local',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Sincronize sem nuvem',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),
          const VerticalDivider(width: 1, indent: 14, endIndent: 14, color: Color(0x1F94A3B8)),
          const SizedBox(width: 16),

          // Navegação Central: Ícone em cima e Nome embaixo
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(items.length, (index) {
                  int targetScreenIndex;
                  switch (index) {
                    case 0:
                      targetScreenIndex = 5; // Início
                      break;
                    case 1:
                      targetScreenIndex = 0; // Dispositivos
                      break;
                    case 2:
                      targetScreenIndex = 1; // Sync
                      break;
                    case 3:
                      targetScreenIndex = 2; // Transferir
                      break;
                    case 4:
                      targetScreenIndex = 6; // Deploy
                      break;
                    case 5:
                      targetScreenIndex = 3; // Histórico
                      break;
                    case 6:
                      targetScreenIndex = 4; // Ajustes
                      break;
                    default:
                      targetScreenIndex = 5;
                  }
                  final isSelected = selectedIndex == targetScreenIndex;
                  final item = items[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onDestinationSelected(targetScreenIndex),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? const Color(0xFF0078D4).withOpacity(0.2)
                                    : const Color(0xFF0078D4).withOpacity(0.09))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: const Color(0xFF0078D4).withOpacity(0.35),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Ícone em cima
                                  Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    size: 22,
                                    color: isSelected
                                        ? const Color(0xFF0078D4)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 3),
                                  // Nome embaixo
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF0078D4)
                                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.badgeCount != null)
                                Positioned(
                                  top: -4,
                                  right: -8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0078D4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${item.badgeCount}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Lado Direito: Sincronização Ativa + Chip do Dispositivo Local
          if (isSyncingAny)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0078D4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0078D4)),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Sincronizando...',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0078D4)),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E242C) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF2C3542) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        localDeviceName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      localIp.isNotEmpty ? localIp : 'Rede Local',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
