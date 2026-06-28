import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/models/student.dart';
import '../../../../shared/widgets/app_background_host.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/nebula_text_button.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../../students/data/students_repository.dart';
import '../../../students/presentation/widgets/student_detail_sheet.dart';
import '../../data/admin_repository.dart';
import 'admin_screen.dart';

/// Drill screen: students of one teacher, reached from the Педагоги segment
/// of Поиск. A "Профиль" button reaches the full teacher profile.
class TeacherStudentsScreen extends ConsumerWidget {
  final OrgUser user;

  const TeacherStudentsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final studentsAsync = ref.watch(studentsByTeacherProvider(user.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundHost(
        interactive: false,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppScreenHeader(
                  title: user.displayName,
                  subtitle: 'Ученики педагога',
                  leading: IconButton(
                    tooltip: 'Назад',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: tokens.mutedText),
                  ),
                  trailing: NebulaTextButton(
                    label: 'Профиль',
                    icon: Icons.person_outline_rounded,
                    compact: true,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      TeacherProfileEntry.open(
                        context,
                        user: user,
                        stats: null,
                        onUpdated: () {},
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: _StudentsList(
                  teacherId: user.id,
                  studentsAsync: studentsAsync,
                  ref: ref,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentsList extends StatelessWidget {
  final int teacherId;
  final AsyncValue<List<StudentModel>> studentsAsync;
  final WidgetRef ref;

  const _StudentsList({
    required this.teacherId,
    required this.studentsAsync,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return studentsAsync.when(
      loading: () => const Center(child: OrbitLoader()),
      error: (e, _) => Center(
        child: AppErrorCard(
          message: parseApiError(e, fallback: 'Ошибка загрузки учеников'),
          onRetry: () => ref.invalidate(studentsByTeacherProvider(teacherId)),
          isConnectionError: isConnectionError(e),
        ),
      ),
      data: (students) {
        if (students.isEmpty) {
          return const AppEmptyState(
            message: 'Нет учеников',
            subtitle: 'У этого педагога пока нет учеников',
            icon: Icons.people_outline_rounded,
          );
        }
        return AppListView.builder(
          includeKeyboardInset: true,
          padding: AppSafeInsets.list(
            context,
            top: 4,
            bottom: 24,
            includeKeyboard: true,
          ),
          itemCount: students.length,
          itemBuilder: (context, i) => _StudentTile(student: students[i]),
        );
      },
    );
  }
}

class _StudentTile extends StatelessWidget {
  final StudentModel student;

  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NebulaSurface(
        padding: EdgeInsets.zero,
        child: IconCallout(
          icon: Icons.person_outline_rounded,
          title: student.fullName,
          subtitle: student.phone,
          intent: SemanticIntent.info,
          onTap: () => StudentDetailSheet.show(context, student),
          trailing:
              Icon(Icons.chevron_right_rounded, color: tokens.mutedText, size: 20),
        ),
      ),
    );
  }
}
