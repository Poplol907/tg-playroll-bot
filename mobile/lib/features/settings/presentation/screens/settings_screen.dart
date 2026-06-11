import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/theme/app_visual_mode.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../features/admin/presentation/providers/view_as_teacher_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/primitives/primitives.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _saved = false);
    }
  }

  void _cycleTheme() {
    HapticFeedback.selectionClick();
    final mode = ref.read(appVisualModeProvider);
    ref.read(appVisualModeProvider.notifier).state = switch (mode) {
      AppVisualMode.darkInternals => AppVisualMode.lightLite,
      AppVisualMode.lightLite => AppVisualMode.darkInternals,
    };
  }

  Future<void> _logout() async {
    HapticFeedback.lightImpact();
    // Сбрасываем view-as, чтобы следующий пользователь не наследовал контекст.
    ref.read(viewAsTeacherProvider.notifier).state = null;
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(serverUrlProvider);
    final mode = ref.watch(appVisualModeProvider);
    final user = ref.watch(currentUserProvider);
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: AppScrollView(
          padding: AppSafeInsets.screen(
            context,
            top: 16,
            bottom: 24,
            includeKeyboard: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ────────────────────────────────────────────────────
              Text(
                'Настройки',
                style: type.displayM.copyWith(color: tokens.primaryText),
              ),
              const SizedBox(height: 4),
              Text(
                user != null ? '@${user.login}' : '',
                style: type.labelM.copyWith(color: tokens.mutedText),
              ),
              const SizedBox(height: 24),

              // ── Server URL section ───────────────────────────────────────
              const _SectionLabel(label: 'СЕРВЕР'),
              NebulaSurface(
                padding: const EdgeInsets.all(16),
                borderRadius: NebulaTokens.radiusMD,
                accent: NebulaColors.stellarBlue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi_tethering_rounded,
                            color: NebulaColors.stellarBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Адрес сервера',
                          style: type.titleS
                              .copyWith(color: tokens.primaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Текущий: $current',
                      style: type.labelS.copyWith(color: tokens.mutedText),
                    ),
                    const SizedBox(height: 14),
                    NebulaInput(
                      controller: _ctrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      hintText: 'http://5.223.55.57',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _saved
                              ? NebulaColors.successMint
                                  .withValues(alpha: NebulaAlpha.surface)
                              : NebulaColors.stellarBlue
                                  .withValues(alpha: NebulaAlpha.surface),
                          borderRadius:
                              BorderRadius.circular(NebulaTokens.radiusMD),
                          border: Border.all(
                            color: _saved
                                ? NebulaColors.successMint
                                    .withValues(alpha: NebulaAlpha.medium)
                                : NebulaColors.stellarBlue
                                    .withValues(alpha: NebulaAlpha.accent),
                          ),
                        ),
                        child: Center(
                          child: _saving
                              ? const OrbitLoader(size: 18)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _saved
                                          ? Icons.check_rounded
                                          : Icons.save_rounded,
                                      color: _saved
                                          ? NebulaColors.successMint
                                          : NebulaColors.stellarBlue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _saved ? 'Сохранено' : 'Сохранить',
                                      style: type.bodyM.copyWith(
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

              const SizedBox(height: 24),

              // ── Theme section ────────────────────────────────────────────
              const _SectionLabel(label: 'ИНТЕРФЕЙС'),
              NebulaSurface(
                padding: EdgeInsets.zero,
                borderRadius: NebulaTokens.radiusMD,
                child: IconCallout(
                  icon: mode == AppVisualMode.lightLite
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  title: 'Тема',
                  subtitle: 'Тапни чтобы переключить',
                  intent: SemanticIntent.warning,
                  onTap: _cycleTheme,
                  trailing: StatusBadge(
                    label: _modeLabel(mode),
                    intent: SemanticIntent.warning,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Account section ──────────────────────────────────────────
              const _SectionLabel(label: 'АККАУНТ'),
              NebulaSurface(
                padding: EdgeInsets.zero,
                borderRadius: NebulaTokens.radiusMD,
                child: ActionRow(
                  icon: Icons.logout_rounded,
                  label: 'Выйти из аккаунта',
                  destructive: true,
                  onTap: _logout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeLabel(AppVisualMode mode) => switch (mode) {
        AppVisualMode.darkInternals => 'ТЁМНАЯ',
        AppVisualMode.lightLite => 'СВЕТЛАЯ',
      };
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: type.overline.copyWith(color: tokens.mutedText),
      ),
    );
  }
}
