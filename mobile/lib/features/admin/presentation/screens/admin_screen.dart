import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../shared/widgets/app_background_host.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/nebula_text_button.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../../../core/utils/error_parser.dart';
import '../../data/admin_repository.dart';
import '../widgets/create_user_sheet.dart';
import '../widgets/set_password_sheet.dart';

// ─────────────────────────────────────────────
//  AdminScreen — user management for ADMIN role
// ─────────────────────────────────────────────

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      SpacePageRoute(builder: (_) => const AdminScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(orgUsersProvider);

    return Scaffold(
      body: AppBackgroundHost(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: NebulaColors.nebulaSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: NebulaColors.surfaceBorder),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: NebulaColors.dimText, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Пользователи',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: NebulaColors.softWhite,
                          ),
                        ),
                        Text(
                          'Управление аккаунтами',
                          style: TextStyle(
                            fontSize: 12,
                            color: NebulaColors.dimText,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Add user button
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final ok = await CreateUserSheet.show(context);
                        if (ok) ref.invalidate(orgUsersProvider);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              NebulaColors.stellarBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: NebulaColors.stellarBlue
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.person_add_outlined,
                            color: NebulaColors.stellarBlue, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── User list ──
              Expanded(
                child: usersAsync.when(
                  loading: () => const Center(child: OrbitLoader()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            color: NebulaColors.ghostText, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Ошибка загрузки',
                          style: TextStyle(
                            color: NebulaColors.dimText,
                          ),
                        ),
                        NebulaTextButton(
                          label: 'Повторить',
                          icon: Icons.refresh_rounded,
                          onPressed: () => ref.invalidate(orgUsersProvider),
                        ),
                      ],
                    ),
                  ),
                  data: (users) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: users.length,
                    itemBuilder: (context, i) => _UserTile(
                      user: users[i],
                      onUpdated: () => ref.invalidate(orgUsersProvider),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  User tile
// ─────────────────────────────────────────────

class _UserTile extends ConsumerWidget {
  final OrgUser user;
  final VoidCallback onUpdated;

  const _UserTile({required this.user, required this.onUpdated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NebulaSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: NebulaTokens.radiusMD,
        child: Row(
          children: [
            // Role icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: user.isAdmin
                    ? NebulaColors.nebulaPurple.withValues(alpha: 0.12)
                    : NebulaColors.stellarBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: user.isAdmin
                      ? NebulaColors.nebulaPurple.withValues(alpha: 0.3)
                      : NebulaColors.stellarBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                user.isAdmin ? Icons.shield_outlined : Icons.school_outlined,
                color: user.isAdmin
                    ? NebulaColors.nebulaPurple
                    : NebulaColors.stellarBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: NebulaColors.softWhite,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: user.isAdmin
                              ? NebulaColors.nebulaPurple
                                  .withValues(alpha: 0.12)
                              : NebulaColors.stellarBlue.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(NebulaTokens.radiusXS),
                        ),
                        child: Text(
                          user.isAdmin ? 'ADMIN' : 'TEACHER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: user.isAdmin
                                ? NebulaColors.nebulaPurple
                                : NebulaColors.stellarBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.login,
                    style: const TextStyle(
                      fontSize: 12,
                      color: NebulaColors.ghostText,
                    ),
                  ),
                ],
              ),
            ),

            // Password indicator
            if (!user.hasPassword)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: NebulaColors.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusXS),
                  border: Border.all(
                      color: NebulaColors.warningAmber.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'нет пароля',
                  style: TextStyle(
                    fontSize: 9,
                    color: NebulaColors.warningAmber,
                  ),
                ),
              ),

            // Actions menu
            PopupMenuButton<String>(
              color: NebulaColors.spaceBlack,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
                side: const BorderSide(color: NebulaColors.surfaceBorder),
              ),
              icon: const Icon(Icons.more_vert_rounded,
                  color: NebulaColors.ghostText, size: 18),
              onSelected: (action) => _handleAction(context, ref, action),
              itemBuilder: (_) => [
                _menuItem('password', Icons.lock_outline_rounded,
                    'Установить пароль', NebulaColors.stellarBlue),
                _menuItem('delete', Icons.person_remove_outlined, 'Удалить',
                    NebulaColors.errorRose),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'password':
        final ok = await SetPasswordSheet.show(context, user);
        if (ok) onUpdated();
      case 'delete':
        final confirm = await _confirmDelete(context);
        if (confirm == true) {
          try {
            await ref.read(adminRepositoryProvider).deleteUser(user.id);
            HapticFeedback.mediumImpact();
            onUpdated();
          } on Exception catch (e) {
            if (context.mounted) {
              showNebulaSnackBar(
                context,
                title: 'Не удалось удалить',
                message: parseApiError(e,
                    fallback: 'Проверь подключение и попробуй ещё раз'),
                tone: NebulaSnackTone.error,
              );
            }
          }
        }
    }
  }

  Future<bool> _confirmDelete(BuildContext context) {
    return NebulaDialog.confirm(
      context,
      title: 'Удалить ${user.displayName}?',
      message: 'Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
  }
}
