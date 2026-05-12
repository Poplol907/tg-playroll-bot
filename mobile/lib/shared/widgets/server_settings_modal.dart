import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/server_config.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'adaptive_modal.dart';
import 'nebula_input.dart';
import 'nebula_surface.dart';
import 'orbit_loader.dart';

class ServerSettingsModal extends ConsumerStatefulWidget {
  const ServerSettingsModal({super.key});

  static Future<void> show(BuildContext context) {
    if (AppPlatform.isDesktop) {
      return AdaptiveModal.show<void>(
        context,
        builder: (_) => const ServerSettingsModal(),
        desktopWidth: 440,
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      useSafeArea: true,
      builder: (_) => const ServerSettingsModal(),
    );
  }

  @override
  ConsumerState<ServerSettingsModal> createState() =>
      _ServerSettingsModalState();
}

class _ServerSettingsModalState extends ConsumerState<ServerSettingsModal> {
  late TextEditingController _ctrl;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(serverUrlProvider));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _saving = true;
      _saved = false;
    });
    await ref.read(serverUrlProvider.notifier).setUrl(url);
    if (mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        _saving = false;
        _saved = true;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;
    final current = ref.watch(serverUrlProvider);
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(NebulaTokens.radiusLG),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 24),
        decoration: const BoxDecoration(
          gradient: NebulaColors.warmGlass,
          border: Border(
            top: BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
            left: BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
            right: BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: NebulaColors.dimText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusXS),
                ),
              ),
            ),

            // ── Title ─────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.wifi_tethering_rounded,
                  color: NebulaColors.stellarBlue,
                  size: 20,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 2,
                    ),
                    Shadow(
                      color: NebulaColors.stellarBlue.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Text(
                  'Адрес сервера',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: NebulaColors.softWhite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Текущий: $current',
              style: const TextStyle(
                fontSize: 11,
                color: NebulaColors.mistWhite,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 20),

            // ── URL input ─────────────────────────────────────────────────
            NebulaInput(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              hintText: 'http://192.168.x.x:8000',
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => _ctrl.clear(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),

            // ── Hint ──────────────────────────────────────────────────────
            NebulaSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: NebulaTokens.radiusSM,
              accent: NebulaColors.stellarBlue,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: NebulaColors.stellarBlue,
                    size: 16,
                    shadows: [
                      Shadow(
                        color: NebulaColors.stellarBlue.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'На Mac: ipconfig getifaddr en0',
                      style: TextStyle(
                        fontSize: 11,
                        color: NebulaColors.mistWhite,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Admin panel button ────────────────────────────────────────
            if (isAdmin) ...[
              NebulaSurface(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: NebulaTokens.radiusMD,
                accent: NebulaColors.nebulaPurple,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  // Переключаем на админ-вкладку через router
                  context.go('/admin');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.manage_accounts_rounded,
                      color: NebulaColors.nebulaPurple,
                      size: 18,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          blurRadius: 2,
                        ),
                        Shadow(
                          color:
                              NebulaColors.nebulaPurple.withValues(alpha: 0.7),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Управление пользователями',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: NebulaColors.softWhite,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Save button ───────────────────────────────────────────────
            GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _saved
                      ? NebulaColors.successMint.withValues(alpha: 0.10)
                      : NebulaColors.stellarBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
                  border: Border.all(
                    color: _saved
                        ? NebulaColors.successMint.withValues(alpha: 0.40)
                        : NebulaColors.stellarBlue.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_saved
                              ? NebulaColors.successMint
                              : NebulaColors.stellarBlue)
                          .withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: Offset.zero,
                    ),
                  ],
                ),
                child: Center(
                  child: _saving
                      ? const OrbitLoader(size: 20)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _saved ? Icons.check_rounded : Icons.save_rounded,
                              color: _saved
                                  ? NebulaColors.successMint
                                  : NebulaColors.stellarBlue,
                              size: 18,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  blurRadius: 2,
                                ),
                                Shadow(
                                  color: (_saved
                                          ? NebulaColors.successMint
                                          : NebulaColors.stellarBlue)
                                      .withValues(alpha: 0.7),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _saved ? 'Сохранено!' : 'Сохранить',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _saved
                                    ? NebulaColors.successMint
                                    : NebulaColors.stellarBlue,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
