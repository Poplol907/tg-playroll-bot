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
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../shared/widgets/nebula_surface.dart';
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

  // Nav glow colours come from theme tokens so both themes get the SAME
  // semantic hue at the right saturation. The old static consts mixed a
  // legacy dim off-orange border token with dark pastels that washed out
  // on white.
  GlowMenuItem _settingsMenuItem(CosmoThemeTokens t) => GlowMenuItem(
        icon: Icons.settings_outlined,
        label: 'Настройки',
        glowColor: t.warning,
      );

  GlowMenuItem _adminMenuItem(CosmoThemeTokens t) => GlowMenuItem(
        icon: Icons.shield_outlined,
        label: 'Студия',
        glowColor: t.primaryAccent,
      );

  List<GlowMenuItem> _teacherMenuItems(CosmoThemeTokens t) => [
        GlowMenuItem(
          icon: Icons.calendar_month_rounded,
          label: 'Календарь',
          glowColor: t.primaryAccent,
        ),
        GlowMenuItem(
          icon: Icons.people_outline_rounded,
          label: 'Ученики',
          glowColor: t.secondaryAccent,
        ),
        GlowMenuItem(
          icon: Icons.payments_outlined,
          label: 'Зарплата',
          glowColor: t.success,
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
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final navItems = showAdminTabs
        ? [_adminMenuItem(tokens), _settingsMenuItem(tokens)]
        : [..._teacherMenuItems(tokens), _settingsMenuItem(tokens)];
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
            child: Stack(
              children: [
                DesktopContentFrame(
                  header: monthBar,
                  child: widget.child,
                ),
                const ViewAsOverlay(),
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
      body: Stack(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                monthBar,
                Expanded(child: widget.child),
              ],
            ),
          ),
          // Поверх всего: оранжевая окантовка экрана + овальная кнопка
          // выхода из режима «смотрю как педагог».
          const ViewAsOverlay(),
        ],
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
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    // Floating glass islands instead of a full-width strip: an oval month
    // pill in the middle, circular arrow pucks on the sides. The bar chrome
    // itself is transparent — the background breathes between the islands.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _MonthArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),

          // Month pill — tappable to jump to today
          Expanded(
            child: Center(
              child: MouseRegion(
                cursor: isCurrentMonth
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: NebulaSurface(
                  borderRadius: 999,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
                  onTap: isCurrentMonth ? null : onToday,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.primaryText,
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
                            color: tokens.primaryAccent
                                .withValues(alpha: NebulaAlpha.high),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

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
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    // Circular glass puck — same canonical surface as the month pill, with a
    // soft diffused accent halo on hover (wide blur, low alpha = scattered
    // light, not a hard ring).
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: NebulaSurface(
        borderRadius: 999,
        width: 38,
        height: 38,
        padding: EdgeInsets.zero,
        onTap: widget.onTap,
        glow: _hovered
            ? [
                BoxShadow(
                  color: tokens.focusAccent
                      .withValues(alpha: NebulaAlpha.subtle),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ]
            : null,
        child: Center(
          child: Icon(
            widget.icon,
            color: _hovered ? tokens.focusAccent : tokens.mutedText,
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
