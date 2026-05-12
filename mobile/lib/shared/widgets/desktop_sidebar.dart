import 'package:flutter/material.dart';
import '../../core/theme/app_visual_mode.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';

/// Боковая панель навигации для десктопа (macOS / Windows).
/// Используется вместо нижней навигации на больших экранах.
class DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onThemeTap;
  final AppVisualMode? visualMode;
  final List<DesktopSidebarItem> items;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onSettingsTap,
    this.onThemeTap,
    this.visualMode,
    required this.items,
  });

  static IconData _modeIcon(AppVisualMode? mode) => switch (mode) {
        AppVisualMode.lightLite => Icons.light_mode_rounded,
        _ => Icons.dark_mode_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: NebulaColors.depthMid.withValues(alpha: 0.95),
        border: Border(
          right: BorderSide(
            color: NebulaColors.surfaceBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Top safe area ─────────────────────────────────────────────
          SizedBox(height: MediaQuery.of(context).padding.top + 16),

          // ── App mark — gradient circle ────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [NebulaColors.nebulaPurple, NebulaColors.stellarBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(height: 24),

          // ── Nav items ─────────────────────────────────────────────────
          for (int i = 0; i < items.length; i++) ...[
            _SidebarNavItem(
              item: items[i],
              selected: currentIndex == i,
              onTap: () => onTap(i),
            ),
            const SizedBox(height: 4),
          ],

          const Spacer(),

          // ── Theme toggle ─────────────────────────────────────────────
          if (onThemeTap != null) ...[
            _SidebarNavItem(
              item: DesktopSidebarItem(
                icon: _modeIcon(visualMode),
                label: 'Тема',
              ),
              selected: false,
              onTap: onThemeTap!,
            ),
            const SizedBox(height: 4),
          ],

          // ── Settings ─────────────────────────────────────────────────
          _SidebarNavItem(
            item: const DesktopSidebarItem(
              icon: Icons.settings_outlined,
              label: 'Настройки',
            ),
            selected: false,
            onTap: onSettingsTap,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class DesktopSidebarItem {
  final IconData icon;
  final String label;

  const DesktopSidebarItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────

class _SidebarNavItem extends StatefulWidget {
  final DesktopSidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;

    final color = active
        ? NebulaColors.nebulaPurple
        : _hovered
            ? NebulaColors.mistWhite
            : NebulaColors.dimText;

    final activeBg = NebulaColors.nebulaPurple.withValues(alpha: 0.18);
    final hoverBg = NebulaColors.nebulaSurface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NebulaTokens.tapRelease,
          curve: Curves.easeInOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
            color: active ? activeBg : (_hovered ? hoverBg : Colors.transparent),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: NebulaColors.nebulaPurple.withValues(alpha: 0.30),
                      blurRadius: 14,
                    )
                  ]
                : null,
          ),
          child: Icon(widget.item.icon, color: color, size: 20),
        ),
      ),
    );
  }
}
