import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../network/api_client.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';

// ── Текущая версия приложения ─────────────────────────────────────────────────
// Увеличивай kAppBuild при каждой новой сборке (iOS / Android / Desktop).
const int kAppBuild = 1;
const String kAppVersion = '1.0.0';

// Платформа передаётся на сервер чтобы получить правильную ссылку для установки.
String get _currentPlatform {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  return 'unknown';
}

// ─────────────────────────────────────────────────────────────────────────────

class UpdateInfo {
  final String version;
  final int build;
  final String? installUrl;

  const UpdateInfo({
    required this.version,
    required this.build,
    this.installUrl,
  });
}

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get(
      '/system/version',
      queryParameters: {
        'current_build': kAppBuild,
        'platform': _currentPlatform,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final hasUpdate = data['has_update'] as bool? ?? false;
    if (!hasUpdate) return null;
    return UpdateInfo(
      version: data['version'] as String,
      build: data['build'] as int,
      installUrl: data['install_url'] as String?,
    );
  } catch (_) {
    return null;
  }
});

// ─────────────────────────────────────────────────────────────────────────────
//  Показывает диалог обновления
// ─────────────────────────────────────────────────────────────────────────────

class UpdateChecker extends ConsumerWidget {
  final Widget child;
  const UpdateChecker({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<UpdateInfo?>>(updateInfoProvider, (_, next) {
      next.whenData((info) {
        if (info != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUpdateDialog(context, info);
          });
        }
      });
    });
    return child;
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (ctx) => _UpdateDialog(info: info),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(NebulaTokens.radiusXL)),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: NebulaColors.warmGlass,
          borderRadius: BorderRadius.circular(NebulaTokens.radiusXL),
          border: Border.all(
            color: NebulaColors.warmPearlBorder,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: NebulaColors.auroraCyan.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──────────────────────────────────────────────────
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NebulaColors.auroraCyan.withValues(alpha: 0.08),
                border: Border.all(
                    color: NebulaColors.auroraCyan.withValues(alpha: 0.30)),
                boxShadow: [
                  BoxShadow(
                    color: NebulaColors.auroraCyan.withValues(alpha: 0.20),
                    blurRadius: 20,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: NebulaColors.auroraCyan,
                size: 28,
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 2,
                  ),
                  Shadow(
                    color: NebulaColors.auroraCyan.withValues(alpha: 0.7),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ─────────────────────────────────────────────────
            const Text(
              'Доступно обновление',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: NebulaColors.softWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Версия ${info.version} (build ${info.build})',
              style: const TextStyle(
                fontSize: 13,
                color: NebulaColors.auroraCyan,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Установи обновление чтобы получить последние изменения.',
              style: TextStyle(
                fontSize: 13,
                color: NebulaColors.mistWhite,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Install button ────────────────────────────────────────
            if (info.installUrl != null)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _openInstallUrl(info.installUrl!);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: NebulaColors.auroraCyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
                    border: Border.all(
                        color: NebulaColors.auroraCyan.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: NebulaColors.auroraCyan.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: NebulaColors.auroraCyan,
                        size: 18,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 2,
                          ),
                          Shadow(
                            color:
                                NebulaColors.auroraCyan.withValues(alpha: 0.7),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Установить',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: NebulaColors.auroraCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Позже',
                style: TextStyle(
                  color: NebulaColors.mistWhite,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInstallUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
