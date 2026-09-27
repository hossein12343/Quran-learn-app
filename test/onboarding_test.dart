import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';
import 'package:quran_learn_app/features/auth/auth_pages.dart';
import 'package:quran_learn_app/shared/services/app_state.dart';

void main() {
  setUp(() {
    appState.debugClearProgress();
    appState.learningGoal = AppState.goalShortSurahs;
    appState.dailyGoalMinutes = 10;
  });

  testWidgets(
      'the welcome answers set the order, the known surahs and '
      'the daily goal', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const OnboardingPage(),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('HOME'))),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('از ابتدای قرآن'));
    await tester.tap(find.text('20 دقیقه'));
    await tester.tap(find.text('انتخاب سوره‌هایی که حفظم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('همهٔ جزء ۳۰'));
    await tester.pump();
    await tester.tap(find.textContaining('تأیید'));
    await tester.pumpAndSettle();
    expect(find.textContaining('سوره انتخاب شد'), findsOneWidget);

    await tester.ensureVisible(find.text('شروع یادگیری'));
    await tester.tap(find.text('شروع یادگیری'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(appState.learnsFromStart, isTrue);
    expect(appState.dailyGoalMinutes, 20);
    // The test data's short surahs (112–114) are all in Juz 30.
    expect(appState.sealed, containsAll([112, 113, 114]));
    expect(appState.sealed.contains(1), isFalse);
  });
}
