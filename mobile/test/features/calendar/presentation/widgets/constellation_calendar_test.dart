import 'package:cosmo_studio/features/calendar/presentation/widgets/constellation_calendar.dart';
import 'package:cosmo_studio/shared/models/lesson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ConstellationCalendar keeps ambient motion off by default',
      (tester) async {
    var ticks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 360,
          child: ConstellationCalendar(
            month: DateTime(2026, 5),
            lessons: [_lesson(DateTime(2026, 5, 4))],
            onDebugAnimationTick: () => ticks++,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));

    expect(ticks, 0);
    expect(find.byType(ConstellationCalendar), findsOneWidget);
  });

  testWidgets('ConstellationCalendar can opt into ambient motion',
      (tester) async {
    var ticks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 360,
          child: ConstellationCalendar(
            month: DateTime(2026, 5),
            lessons: [_lesson(DateTime(2026, 5, 4))],
            enableAmbientMotion: true,
            onDebugAnimationTick: () => ticks++,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));

    expect(ticks, greaterThan(0));
  });
}

LessonModel _lesson(DateTime date) {
  return LessonModel(
    id: 1,
    orgId: 1,
    studentTeacherId: 1,
    scheduledDate: date,
    status: 'attended',
    makeupStatus: 'none',
    paymentCounted: true,
  );
}
