import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../core/utils/error_parser.dart';
import '../../data/admin_repository.dart';

class CreateUserSheet extends ConsumerStatefulWidget {
  const CreateUserSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => const CreateUserSheet(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<CreateUserSheet> {
  final _loginCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String _role = 'TEACHER';
  bool _loading = false;
  String? _error;
  bool _showPass = false;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final login = _loginCtrl.text.trim();
    if (login.isEmpty) {
      setState(() => _error = 'Введите логин');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(adminRepositoryProvider).createUser(
            login: login,
            role: _role,
            teacherName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            password: _passCtrl.text.isEmpty ? null : _passCtrl.text,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось создать пользователя');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Новый пользователь',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: NebulaColors.softWhite,
          ),
        ),
        const SizedBox(height: 20),

        // Login
        _NebulaField(
          controller: _loginCtrl,
          hint: 'Логин (уникальный)',
          icon: Icons.alternate_email_rounded,
        ),
        const SizedBox(height: 12),

        // Display name
        _NebulaField(
          controller: _nameCtrl,
          hint: 'Имя педагога (необязательно)',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),

        // Password
        _NebulaField(
          controller: _passCtrl,
          hint: 'Пароль (можно задать позже)',
          icon: Icons.lock_outline_rounded,
          obscure: !_showPass,
          suffix: IconButton(
            icon: Icon(
              _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: NebulaColors.ghostText, size: 18,
            ),
            onPressed: () => setState(() => _showPass = !_showPass),
          ),
        ),
        const SizedBox(height: 16),

        // Role picker
        Row(
          children: [
            const Text(
              'Роль:',
              style: TextStyle(color: NebulaColors.dimText),
            ),
            const SizedBox(width: 12),
            _RoleChip(
              label: 'Педагог',
              selected: _role == 'TEACHER',
              color: NebulaColors.stellarBlue,
              onTap: () => setState(() => _role = 'TEACHER'),
            ),
            const SizedBox(width: 8),
            _RoleChip(
              label: 'Админ',
              selected: _role == 'ADMIN',
              color: NebulaColors.nebulaPurple,
              onTap: () => setState(() => _role = 'ADMIN'),
            ),
          ],
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(fontSize: 13, color: NebulaColors.errorRose),
          ),
        ],
        const SizedBox(height: 20),

        // Submit
        StellarButton(
          label: 'Создать',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.person_add_rounded,
          color: NebulaColors.stellarBlue,
        ),
      ],
    );
  }
}

class _NebulaField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;

  const _NebulaField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return NebulaInput(
      controller: controller,
      hintText: hint,
      obscureText: obscure,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : NebulaColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? color : NebulaColors.ghostText,
          ),
        ),
      ),
    );
  }
}
