import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';
import 'package:quran_learn_app/features/profile/profile_page.dart';
import 'package:quran_learn_app/shared/services/app_state.dart';

Widget _app() => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const ProfilePage(),
    );

void main() {
  tearDown(() => appState.debugSetTokens(null, null));

  testWidgets(
      'delete account asks first, says what goes, and can be backed '
      'out of', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appState.debugSetTokens('token', 'refresh');

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('حذف حساب'));
    await tester.tap(find.text('حذف حساب'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('حساب حذف شود؟'), findsOneWidget);
    expect(find.textContaining('برگشت‌پذیر نیست'), findsOneWidget);

    await tester.tap(find.text('انصراف'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('حساب حذف شود؟'), findsNothing);
    expect(appState.hasSyncedAccount, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signed out, there is no account to delete', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('حذف حساب'), findsNothing);
    expect(find.text('حریم خصوصی'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
