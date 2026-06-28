import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../shared/widgets/nebula_segmented_control.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../data/admin_repository.dart';
import 'teacher_students_screen.dart';

/// Admin search hub: teachers (with drill to their students) and a studio-wide
/// student search, behind a segmented control.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  int _segment = 0; // 0 = Педагоги, 1 = Ученики

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AppScreenHeader(
                title: 'Поиск',
                subtitle: 'Педагоги и ученики студии',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NebulaSegmentedControl(
                segments: const ['Педагоги', 'Ученики'],
                selectedIndex: _segment,
                onChanged: (i) => setState(() => _segment = i),
              ),
            ),
            Expanded(
              child: _segment == 0
                  ? const _TeachersSearchTab()
                  : const _StudentsSearchTab(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Педагоги segment — teacher list, tap drills to their students
// ─────────────────────────────────────────────

class _TeachersSearchTab extends ConsumerStatefulWidget {
  const _TeachersSearchTab();

  @override
  ConsumerState<_TeachersSearchTab> createState() => _TeachersSearchTabState();
}

class _TeachersSearchTabState extends ConsumerState<_TeachersSearchTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(studioStatsProvider);
    final usersAsync = ref.watch(orgUsersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SearchField(
            hintText: 'Поиск по педагогам...',
            onChanged: (s) => setState(() => _query = s.trim()),
          ),
        ),
        Expanded(
          child: _TeacherSearchList(
            statsAsync: statsAsync,
            usersAsync: usersAsync,
            query: _query,
            onChanged: () {
              ref.invalidate(orgUsersProvider);
              ref.invalidate(studioStatsProvider);
            },
          ),
        ),
      ],
    );
  }
}

class _TeacherSearchList extends ConsumerWidget {
  final AsyncValue<StudioStats> statsAsync;
  final AsyncValue<List<OrgUser>> usersAsync;
  final String query;
  final VoidCallback onChanged;

  const _TeacherSearchList({
    required this.statsAsync,
    required this.usersAsync,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (usersAsync.isLoading) {
      return const Center(child: OrbitLoader());
    }
    if (usersAsync.hasError) {
      return Center(
        child: AppErrorCard(
          message: parseApiError(usersAsync.error!,
              fallback: 'Ошибка загрузки списка'),
          onRetry: onChanged,
          isConnectionError: isConnectionError(usersAsync.error!),
        ),
      );
    }

    final users = usersAsync.value ?? [];
    final teachers = users.where((u) => !u.isAdmin).toList();

    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? teachers
        : teachers.where((t) {
            final name = (t.teacherName ?? '').toLowerCase();
            final login = t.login.toLowerCase();
            return name.contains(q) || login.contains(q);
          }).toList();

    final statsByTeacher = <int, TeacherStats>{};
    statsAsync.whenData((s) {
      for (final t in s.teachers) {
        statsByTeacher[t.teacherId] = t;
      }
    });

    if (filtered.isEmpty) {
      return AppEmptyState(
        message: q.isEmpty ? 'Нет педагогов' : 'Никого не нашли',
        subtitle: q.isEmpty ? null : 'Попробуй другой запрос',
        icon: Icons.school_outlined,
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
      itemCount: filtered.length,
      itemBuilder: (context, i) => _TeacherSearchTile(
        user: filtered[i],
        stats: statsByTeacher[filtered[i].id],
      ),
    );
  }
}

class _TeacherSearchTile extends StatelessWidget {
  final OrgUser user;
  final TeacherStats? stats;

  const _TeacherSearchTile({required this.user, required this.stats});

  @override
  Widget build(BuildContext context) {
    final lessonsDone = stats?.lessonsDone ?? 0;
    final totalAmount = stats?.totalAmount ?? 0;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NebulaSurface(
        padding: EdgeInsets.zero,
        child: IconCallout(
          icon: Icons.school_outlined,
          title: user.displayName,
          subtitle:
              '${user.login} · $lessonsDone уроков · ${Money.format(totalAmount)}',
          intent: SemanticIntent.info,
          onTap: () => Navigator.of(context).push(
            SpacePageRoute(
              builder: (_) => TeacherStudentsScreen(user: user),
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded,
              color: tokens.mutedText, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared search field look (mirrors admin_screen.dart's _SearchField)
// ─────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hintText, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Container(
      decoration: BoxDecoration(
        color: NebulaColors.nebulaSurface,
        borderRadius: NebulaRadii.cardBorder,
        border: Border.all(color: NebulaColors.surfaceBorder),
      ),
      child: TextField(
        onChanged: onChanged,
        style: NebulaTypography.of(context)
            .bodyM
            .copyWith(color: tokens.primaryText),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: NebulaTypography.of(context)
              .bodyM
              .copyWith(color: tokens.mutedText),
          prefixIcon:
              Icon(Icons.search_rounded, color: tokens.mutedText, size: 18),
        ),
      ),
    );
  }
}

// Placeholder tab — filled in by Task 3.
class _StudentsSearchTab extends StatelessWidget {
  const _StudentsSearchTab();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Ученики'));
}
