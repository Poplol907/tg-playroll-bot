import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/admin/presentation/providers/view_as_teacher_provider.dart';
import '../../features/admin/presentation/screens/admin_screen.dart';
import '../../features/admin/presentation/screens/search_screen.dart';
import '../../features/admin/presentation/widgets/view_as_banner.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/students/presentation/screens/students_screen.dart';
import '../../features/salary/presentation/screens/salary_screen.dart';
import '../../shared/providers/bottom_bar_visibility_provider.dart';
import '../../shared/providers/month_provider.dart';
import '../../shared/widgets/app_background_host.dart';
import '../../shared/widgets/app_chrome_metrics.dart';
import '../../shared/widgets/space_page_transition.dart';
import '../../shared/widgets/glow_menu_bar.dart';
import '../../shared/widgets/desktop_sidebar.dart';
import '../../shared/widgets/desktop_content_frame.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_surface_profile.dart';
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

  // True while the user is actively dragging the pill. Drives the "loupe"
  // grow on the capsule and disables the inert follower visuals.
  final ValueNotifier<bool> _pillDragActive = ValueNotifier<bool>(false);

  // Cached at drag start so the speed conversion stays consistent even if
  // the viewport reports zero mid-gesture.
  double _dragPagePx = 0;
  double _dragTabPx = 0;

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
    _pillDragActive.value = true;

    // Snapshot the page→tab speed conversion. The pill travels across the
    // bar at tab-width per tab; PageView travels at viewportSize per page.
    // So one pixel of finger motion on the bar = (viewport / tabWidth) px
    // on the pager. Tab width = (bar width - 2·sp8) / N, but bar width is
    // close enough to viewport width on mobile, so we approximate using N.
    final media = MediaQuery.of(context);
    _dragPagePx = controller.position.viewportDimension > 0
        ? controller.position.viewportDimension
        : media.size.width;
    final n = _pageCount > 0 ? _pageCount : 1;
    _dragTabPx = (media.size.width - 16) / n; // 16 = sp8 * 2 outer padding
  }

  void _onNavDragUpdate(DragUpdateDetails details) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;

    // Direct mapping: finger moves the pill RIGHT → pager goes to NEXT page
    // (offset grows). Scale by viewport/tabWidth so dragging one tab worth
    // of distance lands the user exactly on the next page — same feel as
    // grabbing the iOS / Telegram tab bar handle.
    final scale = _dragTabPx > 0 ? (_dragPagePx / _dragTabPx) : 1.0;
    final position = controller.position;
    final nextOffset = (controller.offset + details.delta.dx * scale).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.jumpTo(nextOffset);
  }

  void _onNavDragEnd(DragEndDetails details) {
    _pillDragActive.value = false;
    // Direct mapping: pixels/sec of finger → pages/sec on the pager,
    // converted via the same scale as during the drag.
    final scale = _dragTabPx > 0 ? (_dragPagePx / _dragTabPx) : 1.0;
    _settleNavDrag(details.velocity.pixelsPerSecond.dx * scale);
  }

  void _onNavDragCancel() {
    _pillDragActive.value = false;
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
    _pillDragActive.dispose();
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
    if (isAdmin && !viewingAs) return ['/admin', '/search', '/settings'];
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

  GlowMenuItem _searchMenuItem(CosmoThemeTokens t) => GlowMenuItem(
        icon: Icons.search_rounded,
        label: 'Поиск',
        glowColor: t.secondaryAccent,
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

  static const _searchSidebarItem = DesktopSidebarItem(
    icon: Icons.search_rounded,
    label: 'Поиск',
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
    void selectPreviousMonth() {
      HapticFeedback.selectionClick();
      ref.read(globalMonthProvider.notifier).state =
          DateTime(month.year, month.month - 1);
    }

    void selectNextMonth() {
      HapticFeedback.selectionClick();
      ref.read(globalMonthProvider.notifier).state =
          DateTime(month.year, month.month + 1);
    }

    void selectCurrentMonth() {
      HapticFeedback.lightImpact();
      ref.read(globalMonthProvider.notifier).state =
          DateTime(now.year, now.month);
    }

    final monthBar = AppPlatform.isDesktop
        ? _DesktopMonthBar(
            month: month,
            isCurrentMonth: isCurrentMonth,
            onPrev: selectPreviousMonth,
            onNext: selectNextMonth,
            onToday: selectCurrentMonth,
          )
        : _MobileMonthBar(
            month: month,
            isCurrentMonth: isCurrentMonth,
            onPrev: selectPreviousMonth,
            onNext: selectNextMonth,
            onToday: selectCurrentMonth,
          );

    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final viewingAs = ref.watch(viewAsTeacherProvider) != null;
    // В режиме view-as админ видит вкладки педагога.
    final showAdminTabs = isAdmin && !viewingAs;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final navItems = showAdminTabs
        ? [_adminMenuItem(tokens), _searchMenuItem(tokens), _settingsMenuItem(tokens)]
        : [..._teacherMenuItems(tokens), _settingsMenuItem(tokens)];
    final sidebarItems = showAdminTabs
        ? [_adminSidebarItem, _searchSidebarItem, _settingsSidebarItem]
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
        final delta = (widget.currentIndex - page).abs();
        // Tap on a neighbouring tab → animate so the pill glides into place.
        // Tap on a far-away tab → jump, so we don't physically scroll through
        // every intermediate page (and the pill still appears to "land").
        if (delta == 1) {
          controller.animateToPage(
            widget.currentIndex,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        } else {
          controller.jumpToPage(widget.currentIndex);
        }
      }
    });

    // Detail/push screens flip bottomBarVisibleProvider to false in initState,
    // back to true in dispose. The bar slides off the bottom in those cases
    // and the content reclaims the full screen.
    final barVisible = ref.watch(bottomBarVisibleProvider);
    // Top month island has its own visibility signal — driven by a sheet
    // crossing the full-expand threshold (see HideTopIslandOnFullSheetExpand),
    // NOT by "any modal is open". A half-open sheet still wants the month
    // pill in reach; only a full-screen take-over makes it slide away.
    final topIslandVisible = ref.watch(topIslandVisibleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The bar floats over the content (Apple TabView / Instagram pattern),
      // so it must NOT live in `bottomNavigationBar` (which would steal space
      // from the body). It's the last child of the overlay Stack instead.
      body: Stack(
        children: [
          // Content layer — PageView starts just below the Dynamic Island
          // (SafeArea top:true) so nothing readable hides behind it. The
          // bottom is intentionally NOT inset so the matte glass nav bar
          // floats over the page tail and scroll content fades softly into
          // it (matched by AppSafeInsets, which consumes AppChromeMetrics for
          // both the month island and floating navigation reservations).
          SafeArea(
            top: true,
            bottom: false,
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
              // Off-screen pages build lazily during a swipe. Stable
              // per-route keys prevent PageView from treating an unrelated
              // rebuild (theme toggle) as a page swap.
              itemBuilder: (_, i) => KeyedSubtree(
                key: ValueKey('shell-page-${routes[i]}'),
                child: i == widget.currentIndex
                    ? widget.child
                    : _screenForRoute(routes[i]),
              ),
            ),
          ),

          // Floating top island — month pill + arrow pucks, glass overlay.
          // The status-bar inset lives here (top SafeArea around just the
          // bar) so the content below isn't squeezed out of those pixels.
          // Slides upward off the screen when a draggable sheet is dragged
          // to full-screen extent (mirrors the bottom nav's downward slide).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              ignoring: !topIslandVisible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                offset: topIslandVisible ? Offset.zero : const Offset(0, -1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: topIslandVisible ? 1.0 : 0.0,
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    child: monthBar,
                  ),
                ),
              ),
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
                    dragActive: _pillDragActive,
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
//  Global month controls
// ─────────────────────────────────────────────────────────────────────────────

class _MobileMonthBar extends StatelessWidget {
  final DateTime month;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MobileMonthBar({
    required this.month,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('mobile-top-island'),
      height: AppChromeMetrics.mobileTopIslandExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppChromeMetrics.mobileTopIslandHorizontalInset,
          vertical: AppChromeMetrics.mobileTopIslandOuterVerticalGap,
        ),
        child: _MonthControls(
          month: month,
          isCurrentMonth: isCurrentMonth,
          onPrev: onPrev,
          onNext: onNext,
          onToday: onToday,
          showTooltip: false,
          maxPillWidth: AppChromeMetrics.monthPillMaxWidth,
        ),
      ),
    );
  }
}

class _DesktopMonthBar extends StatelessWidget {
  final DateTime month;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _DesktopMonthBar({
    required this.month,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _MonthControls(
        month: month,
        isCurrentMonth: isCurrentMonth,
        onPrev: onPrev,
        onNext: onNext,
        onToday: onToday,
        showTooltip: true,
      ),
    );
  }
}

class _MonthControls extends StatelessWidget {
  final DateTime month;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final bool showTooltip;
  final double? maxPillWidth;

  const _MonthControls({
    required this.month,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.showTooltip,
    this.maxPillWidth,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'ru').format(month);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final semanticsLabel = isCurrentMonth
        ? 'Текущий месяц: $label'
        : 'Выбран $label. Нажмите, чтобы вернуться к текущему месяцу';
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: tokens.primaryText,
      ),
    );

    Widget pill = NebulaSurface(
      key: const ValueKey('month-pill'),
      profile: NebulaSurfaceProfile.nav,
      radiusRole: NebulaRadiusRole.pill,
      height: AppChromeMetrics.monthControlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: isCurrentMonth ? null : onToday,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (maxPillWidth != null) Flexible(child: labelText) else labelText,
          if (!isCurrentMonth) ...[
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tokens.primaryAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );

    pill = Semantics(
      button: !isCurrentMonth,
      label: semanticsLabel,
      child: pill,
    );
    if (showTooltip && !isCurrentMonth) {
      pill = Tooltip(
        message: 'Вернуться к текущему месяцу',
        child: pill,
      );
    }

    Widget centeredPill = pill;
    if (maxPillWidth != null) {
      centeredPill = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxPillWidth!),
        child: SizedBox(width: double.infinity, child: pill),
      );
    }

    return SizedBox(
      height: AppChromeMetrics.monthControlHeight,
      child: Row(
        children: [
          _MonthArrow(
            key: const ValueKey('previous-month-arrow'),
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
          ),
          Expanded(
            child: Center(
              child: centeredPill,
            ),
          ),
          _MonthArrow(
            key: const ValueKey('next-month-arrow'),
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MonthArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrow({super.key, required this.icon, required this.onTap});

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
        // Same nav-profile glass recipe → arrow pucks match the month pill
        // and the floating bottom bar.
        profile: NebulaSurfaceProfile.nav,
        shape: BoxShape.circle,
        width: AppChromeMetrics.monthControlHeight,
        height: AppChromeMetrics.monthControlHeight,
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
    // BottomBarHideObserver auto-hides the floating nav bar while any
    // modal/sheet/dialog is on the route stack — covers every show*()
    // call site without per-modal plumbing.
    observers: [
      RepaintPulseObserver(),
      BottomBarHideObserver((visible) {
        final notifier = ref.read(bottomBarVisibleProvider.notifier);
        if (notifier.state != visible) notifier.state = visible;
      }),
    ],
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
      if (isAuth &&
          !isAdmin &&
          (state.matchedLocation.startsWith('/admin') ||
              state.matchedLocation.startsWith('/search'))) {
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
            index = loc.startsWith('/settings')
                ? 2
                : loc.startsWith('/search')
                    ? 1
                    : 0;
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
            path: '/search',
            pageBuilder: (context, state) => shellPage(
              key: state.pageKey,
              child: const SearchScreen(),
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
