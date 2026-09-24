import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/motion/browser_back.dart';
import 'package:quran_learn_app/core/motion/page_transitions.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';

final _key = GlobalKey<NavigatorState>();

/// The app is Persian (right-to-left) in every test; [phone] is the
/// phone's own language, which decides the swipe direction.
Future<void> _openSecondPage(WidgetTester tester,
    {String phone = 'en', Widget? second}) async {
  tester.platformDispatcher.localeTestValue = Locale(phone);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  await tester.pumpWidget(MaterialApp(
    navigatorKey: _key,
    theme: AppTheme.light(),
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  second ?? const Scaffold(body: Center(child: Text('second'))),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
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
  group('swipe back', () {
    testWidgets('English phone: swiping right goes back, like Safari',
        (tester) async {
      await _openSecondPage(tester);
      await _drag(tester, 500);
      expect(find.text('second'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('Persian phone: swiping left goes back', (tester) async {
      await _openSecondPage(tester, phone: 'fa');
      await _drag(tester, -500);
      expect(find.text('second'), findsNothing);
    });

    testWidgets('swiping the other way does not go back', (tester) async {
      await _openSecondPage(tester);
      await _drag(tester, -500);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('a short, slow drag springs back instead of going back',
        (tester) async {
      await _openSecondPage(tester);
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
      await _openSecondPage(tester);
      await _drag(tester, 500, kind: PointerDeviceKind.mouse);
      expect(find.text('second'), findsOneWidget);
    });
  });

  group('top-level screens (RootRoute)', () {
    Future<void> pumpRootApp(WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (rs) => RootRoute<void>(
          settings: rs,
          builder: (context) => rs.name == '/'
              ? Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/other'),
                      child: const Text('open'),
                    ),
                  ),
                )
              : const Scaffold(body: Center(child: Text('other'))),
        ),
      ));
    }

    testWidgets('switching screens fades in place instead of sliding',
        (tester) async {
      await pumpRootApp(tester);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final fade = tester.widget<FadeTransition>(find
          .ancestor(
              of: find.text('other'), matching: find.byType(FadeTransition))
          .first);
      expect(fade.opacity.value, inExclusiveRange(0.0, 1.0));
      // Horizontally still centred: no sideways slide.
      expect(tester.getCenter(find.text('other')).dx, closeTo(400, 1));
      await tester.pumpAndSettle();
    });
  });

  group("the browser's own back (Safari's swipe or back button)", () {
    late BrowserBackHandler handler;

    setUp(() {
      handler = BrowserBackHandler(_key);
      // Ahead of the navigator's own handling, as in main().
      WidgetsBinding.instance.addObserver(handler);
    });
    tearDown(() => WidgetsBinding.instance.removeObserver(handler));

    testWidgets('closes the page at once instead of sliding after Safari',
        (tester) async {
      await _openSecondPage(tester);
      final handled = await tester.binding.handlePopRoute();
      await tester.pump(); // One frame — no half-second animation.
      expect(handled, isTrue);
      expect(find.text('second'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('on the first screen, stays in the app', (tester) async {
      await _openSecondPage(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a page guarding its back still gets asked', (tester) async {
      var asked = 0;
      await _openSecondPage(
        tester,
        second: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => asked++,
          child: const Scaffold(body: Center(child: Text('second'))),
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(find.text('second'), findsOneWidget);
    });
  });
}
