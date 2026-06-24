import 'package:cosmo_studio/shared/widgets/app_safe_layout.dart';
import 'package:cosmo_studio/shared/widgets/app_screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in const [320.0, 430.0]) {
    testWidgets('AppScreenHeader fits long content at ${width}px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AppScreenHeader(
                title: 'Очень длинное название раздела',
                subtitle: 'Очень длинное имя преподавателя для узкого экрана',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Badge(label: Text('24')),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Очень длинное название раздела'), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AppCustomScrollView moves header and lazy content together',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCustomScrollView(
            header: const AppScreenHeader(title: 'Ученики'),
            slivers: [
              SliverList.builder(
                itemCount: 30,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey('item-$index'),
                  height: 72,
                  child: Text('Ученик $index'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final header = find.byType(AppScreenHeader);
    final initialHeaderY = tester.getTopLeft(header).dy;
    final initialItemY =
        tester.getTopLeft(find.byKey(const ValueKey('item-0'))).dy;

    await tester.drag(
      find.byKey(const ValueKey('app-custom-scroll-view')),
      const Offset(0, -48),
    );
    await tester.pump();

    expect(tester.getTopLeft(header).dy, lessThan(initialHeaderY));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('item-0'))).dy,
      lessThan(initialItemY),
    );

    await tester.drag(
      find.byKey(const ValueKey('app-custom-scroll-view')),
      const Offset(0, -220),
    );
    await tester.pump();
    expect(find.byType(AppScreenHeader), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppCustomScrollView supports fill-remaining states',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppCustomScrollView(
            header: AppScreenHeader(title: 'Календарь'),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Загрузка')),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Календарь'), findsOneWidget);
    expect(find.text('Загрузка'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
