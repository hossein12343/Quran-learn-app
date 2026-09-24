import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';
import 'package:quran_learn_app/features/auth/auth_pages.dart';

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

  testWidgets('the code boxes accept Persian digits', (tester) async {
    await tester.pumpWidget(_app(const VerifyCodePage(email: 'a@b.co')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '۱۲۳');
    await tester.pump();
    for (final d in ['1', '2', '3']) {
      expect(find.text(d), findsOneWidget);
    }
    // Stop the resend countdown's timer before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
