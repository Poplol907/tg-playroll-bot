import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../shared/models/lesson.dart';
import '../../../../shared/models/student.dart';
import '../../../../shared/providers/month_provider.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => StudentDetailSheet(student: student),
    );
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
    if (s < 0.05 && !_dismissing) {
      _dismissing = true;
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onSpring() {
    if (!_sheetCtrl.isAttached) return;
    final v = _springCtrl.value;
    if (v <= 0.05 && !_dismissing) {
      _dismissing = true;
      _springCtrl.stop();
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _sheetCtrl.jumpTo(v.clamp(0.0, 1.0));
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_sheetCtrl.isAttached) return;
    _springCtrl.stop();
    final delta = -d.primaryDelta! / MediaQuery.of(context).size.height;
    _sheetCtrl.jumpTo((_sheetCtrl.size + delta).clamp(0.0, 1.0));
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_sheetCtrl.isAttached) return;
    final screenH = MediaQuery.of(context).size.height;
    final velocity = -(d.primaryVelocity ?? 0) / screenH;
    final target = (velocity < -1.2 || (_sheetCtrl.size < 0.4 && velocity <= 0))
        ? 0.0
        : 1.0;
    if (target == 1.0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _springCtrl.value = _sheetCtrl.size;
    _springCtrl.animateWith(
      SpringSimulation(_spring, _sheetCtrl.size, target, velocity),
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

    return DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: 0.65,
      minChildSize: 0.0,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [1.0],
      expand: false,
      builder: (ctx, scrollCtrl) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NebulaTokens.radiusXL)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: NebulaColors.warmGlass,
              border: Border(
                top:
                    BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
                left:
                    BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
                right:
                    BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
              ),
            ),
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
                                color:
                                    NebulaColors.dimText.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(
                                    NebulaTokens.radiusXS),
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
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: NebulaColors.softWhite,
                                    ),
                                  ),
                                  if (student.phone != null)
                                    Text(
                                      student.phone!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: NebulaColors.dimText,
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
          ),
        );
      },
    );
  }
}
