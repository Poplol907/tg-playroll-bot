import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/admin/presentation/providers/view_as_teacher_provider.dart';
import '../../features/admin/presentation/screens/admin_screen.dart';
import '../../features/admin/presentation/widgets/view_as_banner.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/students/presentation/screens/students_screen.dart';
import '../../features/salary/presentation/screens/salary_screen.dart';
import '../../shared/providers/month_provider.dart';
import '../../shared/widgets/app_background_host.dart';
import '../../shared/widgets/space_page_transition.dart';
import '../../shared/widgets/glow_menu_bar.dart';
import '../../shared/widgets/desktop_sidebar.dart';
import '../../shared/widgets/desktop_content_frame.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';
import '../../core/services/update_service.dart';
import '../../core/services/repaint_pulse.dart';

// ─────────────────────────────────────────────
//  App Shell — адаптируется под мобайл/десктоп
// ─────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final int currentIndex;

  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Маршруты в порядке вкладок:
  // - Педагог: Календарь + Ученики + Зарплата + Настройки.
  // - Админ в обычном режиме: Студия + Настройки.
  // - Админ в view-as: те же вкладки что у педагога (он смотрит данные педагога).
  List<String> _routesForRole({required bool isAdmin, required bool viewingAs}) {
    if (isAdmin && !viewingAs) return ['/admin', '/settings'];
    return ['/calendar', '/students', '/salary', '/settings'];
  }

  void _onTabTap(int index,
      {required bool isAdmin, required bool viewingAs}) {
    final routes = _routesForRole(isAdmin: isAdmin, viewingAs: viewingAs);
    if (index < routes.length) context.go(routes[index]);
  }

  static const _settingsMenuItem = GlowMenuItem(
    icon: Icons.settings_outlined,
    label: 'Настройки',
    glowColor: NebulaColors.warmPearlBorder,
  );

  static const _adminMenuItem = GlowMenuItem(
    icon: Icons.shield_outlined,
    label: 'Студия',
    glowColor: NebulaColors.warningAmber,
  );

  static const _teacherMenuItems = [
    GlowMenuItem(
      icon: Icons.calendar_month_rounded,
      label: 'Календарь',
      glowColor: NebulaColors.stellarBlue,
    ),
    GlowMenuItem(
      icon: Icons.people_outline_rounded,
      label: 'Ученики',
      glowColor: NebulaColors.nebulaPurple,
    ),
    GlowMenuItem(
      icon: Icons.payments_outlined,
      label: 'Зарплата',
      glowColor: NebulaColors.successMint,
    ),
  ];

  static const _settingsSidebarItem =
      DesktopSidebarItem(icon: Icons.settings_outlined, label: 'Настройки');

  static const _adminSidebarItem = DesktopSidebarItem(
    icon: Icons.shield_outlined,
    label: 'Студия',
  );

  static const _teacherSidebarItems = [
    DesktopSidebarItem(icon: Icons.calendar_month_rounded, label: 'Календарь'),
    DesktopSidebarItem(icon: Icons.people_outline_rounded, label: 'Ученики'),
    DesktopSidebarItem(icon: Icons.payments_outlined, label: 'Зарплата'),
  ];

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(globalMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    final monthBar = _GlobalMonthBar(
      month: month,
      isCurrentMonth: isCurrentMonth,
      onPrev: () {
        HapticFeedback.selectionClick();
        ref.read(globalMonthProvider.notifier).state =
            DateTime(month.year, month.month - 1);
      },
      onNext: () {
        HapticFeedback.selectionClick();
        ref.read(globalMonthProvider.notifier).state =
            DateTime(month.year, month.month + 1);
      },
      onToday: () {
        HapticFeedback.lightImpact();
        ref.read(globalMonthProvider.notifier).state =
            DateTime(now.year, now.month);
      },
    );

    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final viewingAs = ref.watch(viewAsTeacherProvider) != null;
    // В режиме view-as админ видит вкладки педагога.
    final showAdminTabs = isAdmin && !viewingAs;
    final navItems = showAdminTabs
        ? [_adminMenuItem, _settingsMenuItem]
        : [..._teacherMenuItems, _settingsMenuItem];
    final sidebarItems = showAdminTabs
        ? [_adminSidebarItem, _settingsSidebarItem]
        : [..._teacherSidebarItems, _settingsSidebarItem];

    return UpdateChecker(
      child: AppBackgroundHost(
        darkBackground: AppDarkBackground.asciiWater,
        child: AppPlatform.isDesktop
            ? _buildDesktopLayout(monthBar, sidebarItems, isAdmin, viewingAs)
            : _buildMobileLayout(monthBar, navItems, isAdmin, viewingAs),
      ),
    );
  }

  // ── Десктоп: боковая панель + контент ───────────────────────────────────────
  Widget _buildDesktopLayout(
    Widget monthBar,
    List<DesktopSidebarItem> items,
    bool isAdmin,
    bool viewingAs,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          DesktopSidebar(
            currentIndex: widget.currentIndex,
            onTap: (i) =>
                _onTabTap(i, isAdmin: isAdmin, viewingAs: viewingAs),
            items: items,
          ),
          Expanded(
            child: Column(
              children: [
                const ViewAsBanner(),
                Expanded(
                  child: DesktopContentFrame(
                    header: monthBar,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Мобайл: нижний таббар ───────────────────────────────────────────────────
  Widget _buildMobileLayout(
    Widget monthBar,
    List<GlowMenuItem> items,
    bool isAdmin,
    bool viewingAs,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // SafeArea here is the SINGLE source of the top inset (status bar /
      // Dynamic Island). Everything below — banner, month bar, screens —
      // starts beneath the island. Individual widgets must NOT re-apply
      // MediaQuery.padding.top, or insets double up.
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            const ViewAsBanner(),
            monthBar,
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: GlowMenuBar(
        currentIndex: widget.currentIndex,
        onTap: (i) =>
            _onTabTap(i, isAdmin: isAdmin, viewingAs: viewingAs),
        items: items,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Global month bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlobalMonthBar extends StatelessWidget {
  final DateTime month;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _GlobalMonthBar({
    required this.month,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'ru').format(month);

    return Container(
      // Top inset is owned by the shell's SafeArea — keep a flat 8px here.
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        // Frosted glass: white tint base + specular sheen
        color: const Color(0x18FFFFFF),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.03),
            Colors.black.withValues(alpha: 0.06),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        border: Border(
          // Bright top edge (specular) + dim bottom separator
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.20), width: 0.8),
          bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _MonthArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
          const SizedBox(width: 12),

          // Month label — tappable to jump to today
          Expanded(
            child: MouseRegion(
              cursor: isCurrentMonth
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: isCurrentMonth ? null : onToday,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: NebulaColors.softWhite,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (!isCurrentMonth) ...[
                      const SizedBox(height: 1),
                      Text(
                        'нажмите для возврата',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color:
                              NebulaColors.stellarBlue.withValues(alpha: 0.7),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),
          _MonthArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MonthArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrow({required this.icon, required this.onTap});

  @override
  State<_MonthArrow> createState() => _MonthArrowState();
}

class _MonthArrowState extends State<_MonthArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: NebulaTokens.tapRelease,
          curve: Curves.easeInOut,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered
                ? NebulaColors.nebulaSurface.withValues(alpha: 0.3)
                : NebulaColors.nebulaSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: _hovered
                  ? NebulaColors.auroraCyan.withValues(alpha: 0.45)
                  : NebulaColors.surfaceBorder,
              width: 0.8,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: NebulaColors.auroraCyan.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            color: _hovered ? NebulaColors.auroraCyan : NebulaColors.dimText,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Router
// ─────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/calendar',
    // Wakes idle animated backgrounds after any modal/dialog/sheet closes,
    // so the screen doesn't linger dimmed until the user taps.
    observers: [RepaintPulseObserver()],
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isInit = authState.status == AuthStatus.initial;
      final isLoading = authState.status == AuthStatus.loading;
      final onLogin = state.matchedLocation == '/login';
      final isAdmin = authState.user?.isAdmin ?? false;
      final viewingAs = ref.read(viewAsTeacherProvider) != null;

      if (isInit || isLoading) return null;
      if (!isAuth && !onLogin) return '/login';
      // После логина: админа кидаем на /admin, педагога — на /calendar
      if (isAuth && onLogin) return isAdmin ? '/admin' : '/calendar';
      // Педагог не может зайти в /admin
      if (isAuth && !isAdmin && state.matchedLocation.startsWith('/admin')) {
        return '/calendar';
      }
      // Админ в обычном режиме не может зайти в /calendar, /students, /salary —
      // только когда в режиме view-as педагога. Тогда — пропускаем.
      if (isAuth &&
          isAdmin &&
          !viewingAs &&
          (state.matchedLocation.startsWith('/calendar') ||
              state.matchedLocation.startsWith('/students') ||
              state.matchedLocation.startsWith('/salary'))) {
        return '/admin';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => spaceTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final loc = state.matchedLocation;
          final isAdmin = authState.user?.isAdmin ?? false;
          final viewingAs = ref.watch(viewAsTeacherProvider) != null;
          // Когда админ в обычном режиме — у него только {Студия, Настройки}.
          // В view-as — те же вкладки что у педагога.
          final showAdminTabs = isAdmin && !viewingAs;
          final int index;
          if (showAdminTabs) {
            index = loc.startsWith('/settings') ? 1 : 0;
          } else {
            index = loc.startsWith('/students')
                ? 1
                : loc.startsWith('/salary')
                    ? 2
                    : loc.startsWith('/settings')
                        ? 3
                        : 0;
          }
          return AppShell(currentIndex: index, child: child);
        },
        routes: [
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => nebulaFadePage(
              key: state.pageKey,
              child: const AdminScreen(),
            ),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => nebulaFadePage(
              key: state.pageKey,
              child: const CalendarScreen(),
            ),
          ),
          GoRoute(
            path: '/students',
            pageBuilder: (context, state) => nebulaFadePage(
              key: state.pageKey,
              child: const StudentsScreen(),
            ),
          ),
          GoRoute(
            path: '/salary',
            pageBuilder: (context, state) => nebulaFadePage(
              key: state.pageKey,
              child: const SalaryScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => nebulaFadePage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
