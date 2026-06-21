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
import '../../shared/providers/bottom_bar_visibility_provider.dart';
import '../../shared/providers/month_provider.dart';
import '../../shared/widgets/app_background_host.dart';
import '../../shared/widgets/space_page_transition.dart';
import '../../shared/widgets/glow_menu_bar.dart';
import '../../shared/widgets/desktop_sidebar.dart';
import '../../shared/widgets/desktop_content_frame.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_tokens.dart';
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
  // ── Swipe navigation (mobile) ───────────────────────────────────────────
  // The mobile shell renders the role's section screens in a PageView. Direct
  // content swipes are disabled; only a horizontal drag on GlowMenuBar drives
  // the pager. The PageView and router remain synchronized for deep links and
  // direct tab taps.
  PageController? _pageController;
  int _pageCount = 0;
  // Live fractional page position — feeds the nav bar's dock magnification.
  // ValueNotifier (not setState) so only the nav bar repaints per scroll frame.
  final ValueNotifier<double> _navPos = ValueNotifier<double>(0);

  void _ensureController(int index, int count) {
    if (_pageController == null || _pageCount != count) {
      _pageController?.removeListener(_onPageScroll);
      _pageController?.dispose();
      _pageController = PageController(initialPage: index);
      _pageController!.addListener(_onPageScroll);
      _pageCount = count;
      _navPos.value = index.toDouble();
    }
  }

  void _onPageScroll() {
    final p = _pageController?.page;
    if (p != null) _navPos.value = p;
  }

  void _onNavDragStart(DragStartDetails details) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    controller.jumpTo(controller.offset);
  }

  void _onNavDragUpdate(DragUpdateDetails details) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;

    final position = controller.position;
    final nextOffset = (controller.offset - details.delta.dx).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.jumpTo(nextOffset);
  }

  void _onNavDragEnd(DragEndDetails details) {
    _settleNavDrag(-details.velocity.pixelsPerSecond.dx);
  }

  void _onNavDragCancel() {
    _settleNavDrag(0);
  }

  void _settleNavDrag(double pageVelocity) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients || _pageCount == 0) return;

    final page = controller.page ?? widget.currentIndex.toDouble();
    const flingThreshold = 420.0;
    final int target;
    if (pageVelocity > flingThreshold) {
      target = page.floor() + 1;
    } else if (pageVelocity < -flingThreshold) {
      target = page.ceil() - 1;
    } else {
      target = page.round();
    }

    controller.animateToPage(
      target.clamp(0, _pageCount - 1),
      duration: NebulaTokens.feedback,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController?.removeListener(_onPageScroll);
    _pageController?.dispose();
    _navPos.dispose();
    super.dispose();
  }

  Widget _screenForRoute(String route) {
    switch (route) {
      case '/admin':
        return const AdminScreen();
      case '/calendar':
        return const CalendarScreen();
      case '/students':
        return const StudentsScreen();
      case '/salary':
        return const SalaryScreen();
      case '/settings':
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  // Маршруты в порядке вкладок:
  // - Педагог: Календарь + Ученики + Зарплата + Настройки.
  // - Админ в обычном режиме: Студия + Настройки.
  // - Админ в view-as: те же вкладки что у педагога (он смотрит данные педагога).
  List<String> _routesForRole(
      {required bool isAdmin, required bool viewingAs}) {
    if (isAdmin && !viewingAs) return ['/admin', '/settings'];
    return ['/calendar', '/students', '/salary', '/settings'];
  }

  void _onTabTap(int index, {required bool isAdmin, required bool viewingAs}) {
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
            onTap: (i) => _onTabTap(i, isAdmin: isAdmin, viewingAs: viewingAs),
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

  // ── Мобайл: нижний таббар + свайп между разделами ────────────────────────────
  Widget _buildMobileLayout(
    Widget monthBar,
    List<GlowMenuItem> items,
    bool isAdmin,
    bool viewingAs,
  ) {
    final routes = _routesForRole(isAdmin: isAdmin, viewingAs: viewingAs);
    _ensureController(widget.currentIndex, routes.length);

    // Sync the PageView to the router when the active index changed elsewhere
    // (tab tap, deep link). Do not animate here: animateToPage physically
    // scrolls through every intermediate tab (for example Settings ->
    // Calendar), building those screens and fighting the route crossfade.
    // Horizontal section drags are owned exclusively by GlowMenuBar.
    final controller = _pageController!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      final page = controller.page?.round() ?? widget.currentIndex;
      if (page != widget.currentIndex) {
        controller.jumpToPage(widget.currentIndex);
      }
    });

    // Detail/push screens flip bottomBarVisibleProvider to false in initState,
    // back to true in dispose. The bar slides off the bottom in those cases
    // and the content reclaims the full screen.
    final barVisible = ref.watch(bottomBarVisibleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The bar floats over the content (Apple TabView / Instagram pattern),
      // so it must NOT live in `bottomNavigationBar` (which would steal space
      // from the body). It's the last child of the overlay Stack instead.
      body: Stack(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                monthBar,
                Expanded(
                  child: PageView.builder(
                    controller: controller,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: routes.length,
                    onPageChanged: (i) {
                      if (i != widget.currentIndex) {
                        HapticFeedback.selectionClick();
                        _onTabTap(i, isAdmin: isAdmin, viewingAs: viewingAs);
                      }
                    },
                    // Active page = the screen GoRouter already built
                    // (widget.child) so routing/state stay authoritative.
                    // Off-screen pages build lazily during a swipe.
                    // Stable per-route keys prevent PageView from treating
                    // an unrelated rebuild (e.g. theme toggle) as a page
                    // swap and scrolling through every intermediate tab.
                    itemBuilder: (_, i) => KeyedSubtree(
                      key: ValueKey('shell-page-${routes[i]}'),
                      child: i == widget.currentIndex
                          ? widget.child
                          : _screenForRoute(routes[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Поверх всего: оранжевая окантовка экрана + овальная кнопка
          // выхода из режима «смотрю как педагог».
          const ViewAsOverlay(),

          // Floating nav island — slides off the bottom when a detail screen
          // requests the bar hidden via bottomBarVisibleProvider.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !barVisible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                offset: barVisible ? Offset.zero : const Offset(0, 1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: barVisible ? 1.0 : 0.0,
                  child: GlowMenuBar(
                    currentIndex: widget.currentIndex,
                    magnify: _navPos,
                    onTap: (i) =>
                        _onTabTap(i, isAdmin: isAdmin, viewingAs: viewingAs),
                    onHorizontalDragStart: _onNavDragStart,
                    onHorizontalDragUpdate: _onNavDragUpdate,
                    onHorizontalDragEnd: _onNavDragEnd,
                    onHorizontalDragCancel: _onNavDragCancel,
                    items: items,
                  ),
                ),
              ),
            ),
          ),
        ],
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
                  color:
                      tokens.focusAccent.withValues(alpha: NebulaAlpha.subtle),
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
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const AdminScreen(),
            ),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const CalendarScreen(),
            ),
          ),
          GoRoute(
            path: '/students',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const StudentsScreen(),
            ),
          ),
          GoRoute(
            path: '/salary',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const SalaryScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
