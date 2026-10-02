import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';
import 'package:quran_learn_app/core/widgets/surah_picker_sheet.dart';
import 'package:quran_learn_app/features/auth/auth_pages.dart';
import 'package:quran_learn_app/features/auth/known_surahs_sheet.dart';
import 'package:quran_learn_app/features/home/home_page.dart';
import 'package:quran_learn_app/features/learn/hifz_plan_page.dart';
import 'package:quran_learn_app/features/learn/learn_page.dart';
import 'package:quran_learn_app/features/learn/memorized_page.dart';
import 'package:quran_learn_app/features/main/main_shell.dart';
import 'package:quran_learn_app/features/practice/practice_page.dart';
import 'package:quran_learn_app/features/prayer_times/prayer_times_page.dart';
import 'package:quran_learn_app/features/profile/circles_page.dart';
import 'package:quran_learn_app/features/profile/pro_page.dart';
import 'package:quran_learn_app/features/profile/profile_page.dart';
import 'package:quran_learn_app/features/progress/achievements_page.dart';
import 'package:quran_learn_app/features/progress/progress_page.dart';
import 'package:quran_learn_app/features/qibla/qibla_page.dart';
import 'package:quran_learn_app/features/quiz/quiz_page.dart';
import 'package:quran_learn_app/features/quran/asma_al_husna_page.dart';
import 'package:quran_learn_app/features/quran/bookmarks_page.dart';
import 'package:quran_learn_app/features/quran/duas_page.dart';
import 'package:quran_learn_app/features/quran/khatm_page.dart';
import 'package:quran_learn_app/features/quran/quran_page.dart';
import 'package:quran_learn_app/features/quran/verse_search_page.dart';
import 'package:quran_learn_app/features/review/review_page.dart';
import 'package:quran_learn_app/features/review/weak_words_page.dart';
import 'package:quran_learn_app/features/settings/about_page.dart';
import 'package:quran_learn_app/features/settings/settings_page.dart';
import 'package:quran_learn_app/shared/data/quran_seed.dart';
import 'package:quran_learn_app/shared/services/app_state.dart';

/// Every screen of the app, opened at a regular and a small phone size,
/// with and without progress. Any exception while building or laying out
/// — including text that overflows its space — fails the test.

Surah _surah(int n) => surahs.firstWhere((s) => s.number == n);

/// A learner a few days in: Al-Fatihah sealed and due for review, part of
/// An-Nas held, a couple of hard words and a bookmark.
void _seedProgress() {
  appState.debugClearProgress();
  appState.recordSession(
    surahNumber: 1,
    heldIndicesNow: {0, 1, 2, 3, 4, 5, 6},
    didSeal: true,
    sealedChunk: 0,
    minutes: 6,
  );
  appState.reviewDue[appState.levelKey(1, 0)] =
      DateTime.now().subtract(const Duration(days: 1));
  appState.recordSession(
      surahNumber: 114, heldIndicesNow: {0, 1}, didSeal: false, minutes: 3);
  appState.recordWeakSpots(1, 1, missed: [1]);
  appState.recordWeakSpots(1, 4, missed: [-1]);
  appState.bookmarks['1:2'] = null;
}

final Map<String, Widget Function()> _screens = {
  'login': () => const AuthPage(),
  'signup': () => const AuthPage(signUp: true),
  'verify code': () => const VerifyCodePage(email: 'someone@example.com'),
  'reset code': () =>
      const VerifyCodePage(email: 'a@b.co', purpose: CodePurpose.recovery),
  'forgot password': () => const ForgotPasswordPage(initialEmail: 'a@b.co'),
  'new password': () => const NewPasswordPage(),
  'welcome': () => const OnboardingPage(),
  'known surahs': () => const Scaffold(body: KnownSurahsSheet()),
  'shell': () => const MainShell(),
  'home': () => HomePage(onGoToLearn: () {}),
  'learn': () => const LearnPage(),
  'practice': () => const PracticePage(),
  'quran': () => const QuranPage(),
  'reader': () => SurahReaderPage(surah: _surah(1)),
  'reader at ayah': () => SurahReaderPage(surah: _surah(114), scrollToAyah: 4),
  'progress': () => const ProgressPage(),
  'achievements': () => const AchievementsPage(),
  'profile': () => const ProfilePage(),
  'settings': () => const SettingsPage(),
  'about': () => const AboutPage(),
  'pro': () => const ProPage(),
  'circles': () => const CirclesPage(),
  'review': () => const ReviewPage(),
  'hard words': () => const WeakWordsPage(),
  'memorized': () => const MemorizedPage(),
  'hifz plan': () => const HifzPlanPage(),
  'bookmarks': () => const BookmarksPage(),
  'khatm': () => const KhatmPage(),
  'duas': () => const DuasPage(),
  'asma': () => const AsmaAlHusnaPage(),
  'search': () => const VerseSearchPage(),
  'prayer times': () => const PrayerTimesPage(),
  'qibla': () => const QiblaPage(),
  'surah picker': () => const Scaffold(body: SurahPickerSheet()),
  'lesson: Al-Fatihah': () => QuizPage(surah: _surah(1), chunkIndex: 0),
  'lesson: An-Nas': () => QuizPage(surah: _surah(114), chunkIndex: 0),
};

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: home,
    );

/// The app's real fonts, so text is measured as on a phone (the test
/// default draws every letter as a wide square, which overflows where the
/// real Persian font wouldn't).
Future<void> _loadRealFonts() async {
  const families = {
    'Vazirmatn': [
      'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black' //
    ],
    'Amiri': ['Regular', 'Bold'],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final weight in family.value) {
      final bytes =
          File('assets/fonts/${family.key}-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadRealFonts);

  for (final progress in [false, true]) {
    for (final size in const [Size(390, 844), Size(320, 640)]) {
      group(
          '${progress ? 'with progress' : 'new learner'}, '
          '${size.width.toInt()}x${size.height.toInt()}', () {
        for (final entry in _screens.entries) {
          testWidgets(entry.key, (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            if (progress) {
              _seedProgress();
            } else {
              appState.debugClearProgress();
            }
            await tester.pumpWidget(_app(entry.value()));
            // Animations here can run forever (the mascot), so step time
            // forward rather than waiting for them to settle.
            for (var i = 0; i < 10; i++) {
              await tester.pump(const Duration(milliseconds: 200));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 2));
          });
        }
      });
    }
  }
}
