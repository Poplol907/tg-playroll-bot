import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/server_config.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_typography.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/bottom_bar_visibility_provider.dart';
import 'adaptive_modal.dart';
import 'app_safe_layout.dart';
import 'frosted_sheet.dart';
import 'nebula_modal_surface.dart';
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
    return runWithBottomBarHidden(context, () {
      return showFrostedSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const ServerSettingsModal(),
      );
    });
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
    final current = ref.watch(serverUrlProvider);
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaModalSurface(
      containerKey: const ValueKey('server-settings-modal-surface'),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: AppSafeInsets.modal(context,
            left: 24, top: 0, right: 24, bottom: 24),
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
                  color: tokens.mutedText.withValues(alpha: NebulaAlpha.strong),
                  borderRadius: NebulaRadii.compactControlBorder,
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
                      color: Colors.white.withValues(alpha: NebulaAlpha.strong),
                      blurRadius: 2,
                    ),
                    Shadow(
                      color: NebulaColors.stellarBlue
                          .withValues(alpha: NebulaAlpha.strong),
                      blurRadius: 10,
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Text(
                  'Адрес сервера',
                  style: NebulaTypography.of(context)
                      .titleL
                      .copyWith(color: tokens.primaryText),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Текущий: $current',
              style: NebulaTypography.of(context)
                  .labelS
                  .copyWith(color: tokens.secondaryText),
            ),
            const SizedBox(height: 20),

            // ── URL input ─────────────────────────────────────────────────
            NebulaInput(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              hintText: 'https://api.cosmo-studio.com',
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
              radiusRole: NebulaRadiusRole.control,
              accent: NebulaColors.stellarBlue,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: NebulaColors.stellarBlue,
                    size: 16,
                    shadows: [
                      Shadow(
                        color: NebulaColors.stellarBlue
                            .withValues(alpha: NebulaAlpha.strong),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'На Mac: ipconfig getifaddr en0',
                      style: NebulaTypography.of(context)
                          .labelS
                          .copyWith(color: tokens.secondaryText),
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
                          color: Colors.white
                              .withValues(alpha: NebulaAlpha.medium),
                          blurRadius: 2,
                        ),
                        Shadow(
                          color: NebulaColors.nebulaPurple
                              .withValues(alpha: NebulaAlpha.high),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Управление пользователями',
                      style: NebulaTypography.of(context).bodyM.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tokens.primaryText,
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
                      ? NebulaColors.successMint
                          .withValues(alpha: NebulaAlpha.surface)
                      : NebulaColors.stellarBlue
                          .withValues(alpha: NebulaAlpha.surface),
                  borderRadius: NebulaRadii.cardBorder,
                  border: Border.all(
                    color: _saved
                        ? NebulaColors.successMint
                            .withValues(alpha: NebulaAlpha.medium)
                        : NebulaColors.stellarBlue
                            .withValues(alpha: NebulaAlpha.accent),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_saved
                              ? NebulaColors.successMint
                              : NebulaColors.stellarBlue)
                          .withValues(alpha: NebulaAlpha.subtle),
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
                                  color: Colors.white
                                      .withValues(alpha: NebulaAlpha.strong),
                                  blurRadius: 2,
                                ),
                                Shadow(
                                  color: (_saved
                                          ? NebulaColors.successMint
                                          : NebulaColors.stellarBlue)
                                      .withValues(alpha: NebulaAlpha.high),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _saved ? 'Сохранено!' : 'Сохранить',
                              style:
                                  NebulaTypography.of(context).titleS.copyWith(
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
