import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_layout.dart';
import '../../core/theme/nebula_surface_profile.dart';
import '../../core/theme/nebula_tokens.dart';

/// Боковая панель навигации для десктопа (macOS / Windows).
/// Используется вместо нижней навигации на больших экранах.
class DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DesktopSidebarItem> items;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final surface = NebulaSurfaceProfile.nav.resolve(context);
    final layout = NebulaLayout.of(context);
    return Container(
      key: const ValueKey('desktop-sidebar-surface'),
      width: layout.sidebarWidth,
      decoration: BoxDecoration(
        color: surface.fill,
        gradient: surface.sheen,
        border: Border(
          right: BorderSide(
            color: surface.border,
            width: surface.borderWidth,
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [NebulaColors.nebulaPurple, NebulaColors.stellarBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child:
                  Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
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
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = tokens.primaryAccent;

    final color = active
        ? accent
        : _hovered
            ? tokens.primaryText
            : tokens.mutedText;

    final activeBg = accent.withValues(alpha: isLight ? 0.12 : 0.18);
    final hoverBg = tokens.surface;

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
            color:
                active ? activeBg : (_hovered ? hoverBg : Colors.transparent),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isLight ? 0.14 : 0.30),
                      blurRadius: isLight ? 10 : 14,
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
