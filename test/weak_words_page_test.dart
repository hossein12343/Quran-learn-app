import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';
import 'package:quran_learn_app/features/review/weak_words_page.dart';
import 'package:quran_learn_app/shared/data/quran_seed.dart';
import 'package:quran_learn_app/shared/services/app_state.dart';
import 'package:quran_learn_app/shared/services/weak_spots.dart';

Widget _app() => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const WeakWordsPage(),
    );

void main() {
  setUp(() => appState.weakSpots.clear());

  testWidgets('asks for the missing word, and a right answer counts',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Al-Fatihah, second ayah, second word.
    final fatiha = surahs.firstWhere((s) => s.number == 1);
    final word = fatiha.ayat[1].words[1];
    appState.weakSpots.missed(1, 1, 1);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('کلمهٔ جاافتاده کدام است؟'), findsOneWidget);

    await tester.tap(find.text(word));
    await tester.pump();
    await tester.tap(find.text('بررسی'));
    await tester.pumpAndSettle();
    expect(find.text('درست است!'), findsOneWidget);
    expect(appState.weakSpots[WeakSpot.keyOf(1, 1, 1)]!.rightInARow, 1);

    await tester.tap(find.text('پایان'));
    // The celebrating mascot bounces continuously, so this never "settles".
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1 از 1 درست'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with nothing to practise, says so', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('کلمهٔ دشواری نمانده'), findsOneWidget);
  });

  test('the app-wide record adds a miss and clears it after two rights', () {
    appState.recordWeakSpots(1, 2, missed: [0]);
    expect(appState.weakSpots.length, 1);
    appState.recordWeakSpots(1, 2, right: [0]);
    appState.recordWeakSpots(1, 2, right: [0]);
    expect(appState.weakSpots.isEmpty, isTrue);
  });
}
