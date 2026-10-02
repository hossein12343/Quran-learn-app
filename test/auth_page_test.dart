import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';
import 'package:quran_learn_app/features/auth/auth_pages.dart';
import 'package:quran_learn_app/shared/services/backend.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: home,
    );

void main() {
  testWidgets('the name field only appears when creating an account',
      (tester) async {
    await tester.pumpWidget(_app(const AuthPage()));
    await tester.pumpAndSettle();
    expect(find.text('نام'), findsNothing);

    await tester.tap(find.text('ثبت‌نام'));
    await tester.pumpAndSettle();
    expect(find.text('نام'), findsOneWidget);
    expect(find.text('ساخت حساب'), findsOneWidget);

    await tester.tap(find.text('ورود').first);
    await tester.pumpAndSettle();
    expect(find.text('نام'), findsNothing);
  });

  testWidgets('empty sign-in shows each problem under its own field',
      (tester) async {
    await tester.pumpWidget(_app(const AuthPage()));
    await tester.pumpAndSettle();
    // The primary button is the last "ورود" (the first is the mode toggle).
    await tester.ensureVisible(find.text('ورود').last);
    await tester.tap(find.text('ورود').last);
    await tester.pumpAndSettle();
    expect(find.text('ایمیل خود را وارد کنید.'), findsOneWidget);
    expect(find.text('رمز عبور را وارد کنید.'), findsOneWidget);
  });

  testWidgets('sign-up asks for an 8-character password', (tester) async {
    await tester.pumpWidget(_app(const AuthPage(signUp: true)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Sara');
    await tester.enterText(find.byType(TextField).at(1), 'sara@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'short');
    await tester.ensureVisible(find.text('ساخت حساب'));
    await tester.tap(find.text('ساخت حساب'));
    await tester.pumpAndSettle();
    expect(find.text('رمز عبور باید حداقل ۸ کاراکتر باشد.'), findsOneWidget);
    expect(find.text('نام خود را وارد کنید.'), findsNothing);
  });

  testWidgets('the code field accepts Persian digits', (tester) async {
    await tester.pumpWidget(_app(const VerifyCodePage(email: 'a@b.co')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '۱۲۳');
    await tester.pump();
    // Shown in the box (and held by the invisible input over it).
    expect(find.text('123'), findsWidgets);
    // Stop the resend countdown's timer before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  group('emailed code length', () {
    final sent = <String>[];
    setUp(() {
      sent.clear();
      debugSubmitCode = (_, code) async => sent.add(code);
    });
    tearDown(() => debugSubmitCode = null);

    test('keeps every digit up to ten, converting Persian digits', () {
      expect(cleanCode('۱۲۳۴۵۶۷۸'), '12345678');
      expect(cleanCode('12 34-56'), '123456');
      expect(cleanCode('123456789012'), '1234567890');
    });

    testWidgets('a pasted 8-digit code is sent whole', (tester) async {
      await tester.pumpWidget(_app(const VerifyCodePage(email: 'a@b.co')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12345678');
      await tester.pump();
      expect(sent, ['12345678']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a typed code waits for the button', (tester) async {
      await tester.pumpWidget(_app(const VerifyCodePage(email: 'a@b.co')));
      await tester.pump();
      var typed = '';
      for (final d in '123456'.split('')) {
        typed += d;
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();
      }
      expect(sent, isEmpty, reason: 'it may be an 8-digit code');
      await tester.ensureVisible(find.text('تأیید کد'));
      await tester.tap(find.text('تأیید کد'));
      await tester.pump();
      expect(sent, ['123456']);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('a sign-up for an email that already has an account is recognised', () {
    // Supabase's stand-in answer: a user with no identities, no email sent.
    expect(Backend.signupWasForExistingAccount({'id': 'x', 'identities': []}),
        isTrue);
    expect(
        Backend.signupWasForExistingAccount({
          'id': 'x',
          'identities': [
            {'provider': 'email'}
          ]
        }),
        isFalse);
    // Some setups return no identities field at all; never block those.
    expect(Backend.signupWasForExistingAccount({'id': 'x'}), isFalse);
  });
}
