import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/core/motion/motion.dart';
import 'package:quran_learn_app/core/widgets/duo_button.dart';
import 'package:quran_learn_app/core/widgets/path_trail.dart';

/// Screen readers (VoiceOver, TalkBack) can only press what exposes a tap
/// action in the semantics tree. Every custom tappable surface builds on
/// [PressDetector], which listens to raw pointer events, so this checks
/// each one still announces itself as a button that can be pressed.
void main() {
  testWidgets('a Pressable card with its own text can be pressed',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Pressable(
            onTap: () => taps++,
            child: const Text('قاری، سرعت و حالت'),
          ),
        ),
      ),
    ));
    final node = tester.getSemantics(find.text('قاری، سرعت و حالت'));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('an icon-only Pressable keeps its label and can be pressed',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Pressable(
            onTap: () => taps++,
            semanticLabel: 'بستن',
            child: const Icon(Icons.close),
          ),
        ),
      ),
    ));
    final node = tester.getSemantics(find.bySemanticsLabel('بستن'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('DuoButton can be pressed, and a disabled one cannot',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            DuoButton(label: 'ادامه', onTap: () => taps++),
            const DuoButton(label: 'غیرفعال', onTap: null),
          ],
        ),
      ),
    ));
    final on = tester.getSemantics(find.text('ادامه'));
    expect(on.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(on.id, SemanticsAction.tap);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);

    final off = tester.getSemantics(find.text('غیرفعال'));
    expect(off.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('a path node says which level it is', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PathNode(
            size: 64,
            face: Colors.green,
            shadow: Colors.black,
            icon: const Icon(Icons.play_arrow_rounded),
            semanticLabel: 'الناس، باز',
            onTap: () => taps++,
          ),
        ),
      ),
    ));
    final node = tester.getSemantics(find.bySemanticsLabel('الناس، باز'));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
    handle.dispose();
  });
}
