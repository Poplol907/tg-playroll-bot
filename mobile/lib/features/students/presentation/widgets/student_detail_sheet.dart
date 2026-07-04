import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_component_styles.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/models/lesson.dart';
import '../../../../shared/models/student.dart';
import '../../../../shared/providers/month_provider.dart';
import '../../../../shared/widgets/nebula_modal_surface.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/providers/bottom_bar_visibility_provider.dart';
import '../../../../shared/widgets/frosted_sheet.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../data/students_repository.dart';
import '../providers/student_lessons_provider.dart';
import 'schedule_builder_modal.dart';

part 'student_detail_content.dart';
part 'student_status_toggle.dart';
part 'student_detail_components.dart';

class StudentDetailSheet extends ConsumerStatefulWidget {
  final StudentModel student;

  const StudentDetailSheet({super.key, required this.student});

  static Future<void> show(BuildContext context, StudentModel student) {
    return runWithBottomBarHidden(context, () {
      return showFrostedSheet(
        context: context,
        isScrollControlled: true,
        // БЕЗ useSafeArea: обёртка SafeArea оставляла над шитом «отрезанный»
        // прямоугольник высотой статус-бара поверх month island. Высоту
        // ограничивает сам DraggableScrollableSheet, а барьер-блюр теперь
        // доходит до физического края экрана.
        useSafeArea: false,
        // enableDrag:false — Flutter's built-in drag conflicts with our custom
        // spring dismiss and leaves the barrier stuck mid-fade ("dark overlay
        // until tap"). We drive the drag ourselves and pop in _onDragEnd.
        enableDrag: false,
        builder: (_) => StudentDetailSheet(student: student),
      );
    });
  }

  @override
  ConsumerState<StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends ConsumerState<StudentDetailSheet>
    with TickerProviderStateMixin {
  bool _showAllLessons = false;
  late bool _isActive;
  bool _updatingStatus = false;

  late final DraggableScrollableController _sheetCtrl;
  late final AnimationController _springCtrl;
  bool _dismissing = false;
  bool _hapticOpenFired = false;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 600.0,
    damping: 38.0,
  );

  @override
  void initState() {
    super.initState();
    _isActive =
        widget.student.status == 'active' || widget.student.status == 'ACTIVE';
    _sheetCtrl = DraggableScrollableController();
    _sheetCtrl.addListener(_onSheetSize);
    _springCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onSpring);
  }

  void _onSheetSize() {
    if (!_sheetCtrl.isAttached) return;
    final s = _sheetCtrl.size;
    if (s >= 0.97 && !_hapticOpenFired) {
      _hapticOpenFired = true;
      HapticFeedback.mediumImpact();
    } else if (s < 0.97) {
      _hapticOpenFired = false;
    }
    // Pop is handled directly in _onDragEnd — never from this listener.
    // Popping mid-spring left the modal barrier stuck half-faded.
  }

  void _onSpring() {
    // Only snaps the sheet back to full size; never dismisses.
    if (!_sheetCtrl.isAttached) return;
    _sheetCtrl.jumpTo(_springCtrl.value.clamp(0.0, 1.0));
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_sheetCtrl.isAttached || _dismissing) return;
    _springCtrl.stop();
    final delta = -d.primaryDelta! / MediaQuery.of(context).size.height;
    _sheetCtrl.jumpTo((_sheetCtrl.size + delta).clamp(0.0, 1.0));
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_sheetCtrl.isAttached || _dismissing) return;
    final screenH = MediaQuery.of(context).size.height;
    final velocity = -(d.primaryVelocity ?? 0) / screenH;
    final shouldClose =
        velocity < -1.2 || (_sheetCtrl.size < 0.4 && velocity <= 0);
    if (shouldClose) {
      // Pop immediately — the route's barrier fades out cleanly because we
      // don't fight it with a simultaneous spring-to-zero animation.
      _dismissing = true;
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    HapticFeedback.mediumImpact();
    _springCtrl.value = _sheetCtrl.size;
    _springCtrl.animateWith(
      SpringSimulation(_spring, _sheetCtrl.size, 1.0, velocity),
    );
  }

  @override
  void dispose() {
    _sheetCtrl.removeListener(_onSheetSize);
    _springCtrl.removeListener(_onSpring);
    _springCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus() async {
    if (_updatingStatus) return;
    HapticFeedback.mediumImpact();
    final newStatus = _isActive ? 'inactive' : 'active';
    setState(() {
      _isActive = !_isActive;
      _updatingStatus = true;
    });
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/students/${widget.student.id}/status',
        data: {'status': newStatus},
      );
      ref.invalidate(studentsProvider);
    } catch (_) {
      setState(() => _isActive = !_isActive);
      if (mounted) {
        showNebulaSnackBar(
          context,
          title: 'Не удалось изменить статус',
          tone: NebulaSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    return HideTopIslandOnFullSheetExpand(
      child: DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: 0.65,
      minChildSize: 0.0,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [1.0],
      expand: false,
      builder: (ctx, scrollCtrl) {
        return NebulaModalSurface(
          containerKey: const ValueKey('student-detail-modal-surface'),
          borderRadius: NebulaRadii.sheetTopBorder,
          child: Column(
            children: [
              // ── Handle + header ──
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 10),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: tokens.mutedText.withValues(alpha: 0.5),
                              borderRadius: NebulaRadii.compactControlBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _Avatar(student: student, size: 54),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.fullName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.primaryText,
                                  ),
                                ),
                                if (student.phone != null)
                                  Text(
                                    student.phone!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.secondaryText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (_) {},
                            onVerticalDragEnd: (_) {},
                            child: _StatusToggle(
                              isActive: _isActive,
                              loading: _updatingStatus,
                              onToggle: _toggleStatus,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: NebulaColors.surfaceBorder),

              Expanded(
                child: _ContentLoader(
                  student: student,
                  scrollCtrl: scrollCtrl,
                  showAllLessons: _showAllLessons,
                  onToggleAll: () =>
                      setState(() => _showAllLessons = !_showAllLessons),
                  bottomPad: bottomPad,
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }
}
