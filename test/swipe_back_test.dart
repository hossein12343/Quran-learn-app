import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';

Future<void> _openSecondPage(WidgetTester tester, TextDirection dir) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) =>
        Directionality(textDirection: dir, child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Center(child: Text('second'))),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('second'), findsOneWidget);
}

/// Drags from the middle of the screen, far from either edge.
Future<void> _drag(WidgetTester tester, double dx,
    {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
  final gesture = await tester.startGesture(const Offset(400, 300), kind: kind);
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(Offset(dx / 10, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('left-to-right: swiping right from mid-screen goes back',
      (tester) async {
    await _openSecondPage(tester, TextDirection.ltr);
    await _drag(tester, 500);
    expect(find.text('second'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('right-to-left: swiping left from mid-screen goes back',
      (tester) async {
    await _openSecondPage(tester, TextDirection.rtl);
    await _drag(tester, -500);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('right-to-left: swiping the other way does not go back',
      (tester) async {
    await _openSecondPage(tester, TextDirection.rtl);
    await _drag(tester, 500);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('a short, slow drag springs back instead of going back',
      (tester) async {
    await _openSecondPage(tester, TextDirection.ltr);
    final gesture = await tester.startGesture(const Offset(400, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('dragging with a mouse does not go back', (tester) async {
    await _openSecondPage(tester, TextDirection.ltr);
    await _drag(tester, 500, kind: PointerDeviceKind.mouse);
    expect(find.text('second'), findsOneWidget);
  });
}
