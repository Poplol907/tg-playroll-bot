import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../core/utils/error_parser.dart';
import '../../data/students_repository.dart';

// ─────────────────────────────────────────────
//  AddStudentModal
// ─────────────────────────────────────────────

class AddStudentModal extends ConsumerStatefulWidget {
  const AddStudentModal({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => const AddStudentModal(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AddStudentModal> createState() => _AddStudentModalState();
}

class _AddStudentModalState extends ConsumerState<AddStudentModal> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isForeign = false;
  int? _selectedTeacherId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Введите имя и фамилию');
      return;
    }

    final user = ref.read(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;

    if (isAdmin && _selectedTeacherId == null) {
      setState(() => _error = 'Выберите педагога');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(studentsRepositoryProvider).createStudent(
            firstName: firstName,
            lastName: lastName,
            phone: _phoneCtrl.text.trim(),
            isForeign: _isForeign,
            teacherUserId: isAdmin ? _selectedTeacherId : null,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось сохранить ученика');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Новый ученик',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: NebulaColors.softWhite,
          ),
        ),
        const SizedBox(height: 20),

        // First name
        _NebulaTextField(
          controller: _firstNameCtrl,
          hint: 'Имя',
          label: 'Имя ученика',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),

        // Last name
        _NebulaTextField(
          controller: _lastNameCtrl,
          hint: 'Фамилия',
          label: 'Фамилия ученика',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),

        // Phone
        _NebulaTextField(
          controller: _phoneCtrl,
          hint: 'Телефон (необязательно)',
          label: 'Телефон ученика',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        // Admin: teacher selector
        if (isAdmin) ...[
          _TeacherPicker(
            selectedId: _selectedTeacherId,
            onSelected: (id) => setState(() => _selectedTeacherId = id),
          ),
          const SizedBox(height: 16),
        ],

        // Foreign toggle
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isForeign = !_isForeign);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _isForeign
                  ? NebulaColors.warningAmber.withValues(alpha: 0.08)
                  : NebulaColors.nebulaSurface,
              borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
              border: Border.all(
                color: _isForeign
                    ? NebulaColors.warningAmber.withValues(alpha: 0.4)
                    : NebulaColors.surfaceBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 18,
                  color: _isForeign
                      ? NebulaColors.warningAmber
                      : NebulaColors.ghostText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Иностранный ученик (EN тариф)',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isForeign
                          ? NebulaColors.warningAmber
                          : NebulaColors.dimText,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _isForeign
                        ? NebulaColors.warningAmber.withValues(alpha: 0.3)
                        : NebulaColors.surfaceBorder,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: _isForeign
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isForeign
                            ? NebulaColors.warningAmber
                            : NebulaColors.ghostText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Error
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 13,
              color: NebulaColors.errorRose,
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Submit button
        StellarButton(
          label: 'Добавить ученика',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.person_add_rounded,
          color: NebulaColors.stellarBlue,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Teacher picker (admin only)
// ─────────────────────────────────────────────

class _TeacherPicker extends ConsumerWidget {
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _TeacherPicker({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(teachersPickerProvider);

    return teachersAsync.when(
      loading: () => const SizedBox(
        height: 52,
        child: Center(child: OrbitLoader()),
      ),
      error: (_, __) => const Text(
        'Не удалось загрузить педагогов',
        style: TextStyle(color: NebulaColors.ghostText),
      ),
      data: (teachers) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: NebulaColors.nebulaSurface,
          borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
          border: Border.all(
            color: selectedId != null
                ? NebulaColors.stellarBlue.withValues(alpha: 0.4)
                : NebulaColors.surfaceBorder,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: selectedId,
            hint: const Text(
              'Выберите педагога',
              style: TextStyle(
                fontSize: 14,
                color: NebulaColors.ghostText,
              ),
            ),
            dropdownColor: NebulaColors.spaceBlack,
            icon: const Icon(Icons.expand_more_rounded,
                color: NebulaColors.ghostText),
            isExpanded: true,
            style: const TextStyle(
              fontSize: 14,
              color: NebulaColors.softWhite,
            ),
            items: teachers
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name),
                    ))
                .toList(),
            onChanged: onSelected,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Text field
// ─────────────────────────────────────────────

class _NebulaTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _NebulaTextField({
    required this.controller,
    required this.hint,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      textField: true,
      child: NebulaInput(
        controller: controller,
        hintText: hint,
        keyboardType: keyboardType,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}
