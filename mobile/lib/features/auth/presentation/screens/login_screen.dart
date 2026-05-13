import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../shared/widgets/app_background_host.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../shared/widgets/server_settings_modal.dart';
import '../providers/auth_provider.dart';
import '../widgets/cosmo_login_sphere.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authProvider.notifier)
        .login(_loginCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated) context.go('/calendar');
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackgroundHost(
        darkBackground: AppDarkBackground.asciiWater,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // On desktop the form stays compact in the center of the window
              constraints: BoxConstraints(
                maxWidth: AppPlatform.isDesktop ? 460 : double.infinity,
              ),
              child: AppScrollView(
                padding: AppSafeInsets.screen(
                  context,
                  left: 28,
                  top: 0,
                  right: 28,
                  bottom: 40,
                  includeKeyboard: true,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // ── ASCII Planet — dark blurred core backdrop ──
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Blurred dark oval — pushes ASCII water behind the planet
                        ClipOval(
                          child: SizedBox(
                            width: 230,
                            height: 230,
                            child: BackdropFilter(
                              filter:
                                  ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xDD0B1838), // deep void 87%
                                      Color(0xAA0B1838), // 67%
                                      Color(0x660B1838), // 40%
                                      Color(0x000B1838), // transparent
                                    ],
                                    stops: [0.0, 0.38, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        CosmoLoginSphere(tokens: tokens, size: 220),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'COSMO STUDIO',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: NebulaColors.softWhite,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Управление музыкальной школой',
                      style: TextStyle(
                        fontSize: 13,
                        color: NebulaColors.dimText,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 52),
                    // ── Login Form ──
                    NebulaSurface(
                      dense: true,
                      padding: const EdgeInsets.all(24),
                      borderRadius: NebulaTokens.radiusLG,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Вход',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: NebulaColors.softWhite,
                              ),
                            ),
                            const SizedBox(height: 24),
                            NebulaInput(
                              controller: _loginCtrl,
                              isFormField: true,
                              autocorrect: false,
                              labelText: 'Логин',
                              prefixIcon:
                                  const Icon(Icons.person_outline_rounded),
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Введите логин'
                                  : null,
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 16),
                            NebulaInput(
                              controller: _passCtrl,
                              isFormField: true,
                              obscureText: _obscure,
                              labelText: 'Пароль',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: NebulaColors.dimText,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                              textInputAction: TextInputAction.done,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Введите пароль'
                                  : null,
                              onSubmitted: (_) => _submit(),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: NebulaColors.errorRose
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(
                                      NebulaTokens.radiusSM),
                                  border: Border.all(
                                      color: NebulaColors.errorRose
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: NebulaColors.errorRose,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        auth.error!,
                                        style: const TextStyle(
                                          color: NebulaColors.errorRose,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            StellarButton(
                              label: 'Войти',
                              loading: auth.isLoading,
                              onPressed: auth.isLoading ? null : _submit,
                              icon: Icons.rocket_launch_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ), // SingleChildScrollView
            ), // ConstrainedBox
          ), // Center
        ), // SafeArea
      ), // AppBackgroundHost
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => ServerSettingsModal.show(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NebulaColors.nebulaSurface,
              shape: BoxShape.circle,
              border: Border.all(color: NebulaColors.surfaceBorder),
            ),
            child: const Icon(
              Icons.settings_ethernet_rounded,
              color: NebulaColors.ghostText,
              size: 18,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
