import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/theme/app_theme.dart';
import 'package:quran_learn_app/features/home/home_page.dart';
import 'package:quran_learn_app/features/main/main_shell.dart';

void main() {
  testWidgets('off iPhone, the tab bar leaves the page its screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const MainShell(),
    ));
    await tester.pump(const Duration(seconds: 1));

    // The tab bar once stretched over the whole screen, leaving it blank.
    expect(tester.getSize(find.byType(HomePage)).height, greaterThan(600));
    await tester.pumpWidget(const SizedBox());
  });
}
