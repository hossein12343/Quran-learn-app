import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/duo_button.dart';
import '../../core/widgets/mascot.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/audio.dart';
import '../../shared/services/settings.dart';
import '../../shared/services/sfx.dart' as tone;
import 'quiz_engine.dart';

/// One call site for feedback. Haptics plus the synthesized tones from
/// `shared/services/sfx.dart` (a couple of oscillator nodes via
/// `dart:web_audio` — no audio file, no package, real sound). Swap in a
/// sample-based audio package here later and every screen gains it with
/// no other edits.
abstract class Sfx {
  static void tap() => HapticFeedback.selectionClick();
  static void right() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    tone.sfx.right();
  }

  static void wrong() {
    HapticFeedback.heavyImpact();
    tone.sfx.wrong();
  }

  static void seal() {
    HapticFeedback.mediumImpact();
    tone.sfx.seal();
  }
}

/// A little variety so the mascot doesn't say the literal same word after
/// every single correct answer in a lesson — small thing, but it's part
/// of what makes Duolingo's constant per-exercise praise feel alive
/// instead of like a stuck notification.
const _rightPhrases = <String>[
  'آفرین!',
  'عالی!',
  'همینطور ادامه بده!',
  'دقیقاً درست!',
  'محشره!',
];

enum _Fb { none, right, wrong }

class QuizPage extends StatefulWidget {
  final Surah surah;

  /// Which level (chunk) of the surah to play. One level per visit now —
  /// finishing it returns to the surah's own level list rather than
  /// rolling straight into the next one.
  final int chunkIndex;

  const QuizPage({super.key, required this.surah, required this.chunkIndex});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late Session _s;
  Exercise? _ex;
  final List<int> _placed = <int>[];
  int? _selected;
  _Fb _fb = _Fb.none;
  int _shake = 0;
  bool _justHeld = false;
  String _rightPhrase = _rightPhrases.first;
  Timer? _timer;
  int _left = 0;
  final DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _s = Session(
      widget.surah,
      alreadyHeld: appState.heldIndices(widget.surah.number),
      startChunk: widget.chunkIndex,
      singleLevel: true,
    );
    if (widget.chunkIndex == 0 && Session.isKnownIntro(widget.surah, 0)) {
      // Played once as a courtesy, never taught or drilled — see
      // Session.isKnownIntro.
      unawaited(_playAyah(0));
    }
    _load();
  }

  void _load() {
    _timer?.cancel();
    final ex = _s.next();

    setState(() {
      _ex = ex;
      _placed.clear();
      _selected = null;
      _fb = _Fb.none;
      _justHeld = false;
      _left = ex?.seconds ?? 0;
    });

    if (ex?.seconds != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          _judge(forceWrong: true);
        }
      });
    }
    if (ex != null && ex.kind != ExerciseKind.drill) {
      _playAyah(ex.ayahIndex);
    }
  }

  Future<void> _playAyah(int ayahIndex) async {
    try {
      await recitation.play(
        surah: widget.surah.number,
        ayah: widget.surah.ayat[ayahIndex].number,
        qariId: settings.qariId,
        speed: settings.speed,
      );
    } on Object catch (_) {
      // Recitation is a nice-to-have here; a failed fetch/play shouldn't
      // block or disrupt the exercise itself.
    }
  }

  void _continueTeach() {
    final ex = _ex;
    if (ex == null) return;
    _s.acknowledgeTeach(ex);
    _load();
  }

  bool get _hasAnswer {
    final ex = _ex;
    if (ex == null) return false;
    if (ex.isWordBank) return _placed.length == ex.answer.length;
    return _selected != null;
  }

  void _judge({bool forceWrong = false}) {
    final ex = _ex;
    if (ex == null || _fb != _Fb.none) return;
    _timer?.cancel();

    var correct = false;
    if (!forceWrong) {
      if (ex.isWordBank) {
        final given = _placed.map((i) => ex.tiles[i]).toList();
        correct = given.length == ex.answer.length;
        if (correct) {
          for (var i = 0; i < given.length; i++) {
            if (given[i] != ex.answer[i]) {
              correct = false;
              break;
            }
          }
        }
      } else {
        correct =
            _selected != null && ex.options[_selected!] == ex.correctOption;
      }
    }

    final before = _s.items[ex.ayahIndex].held;
    _s.submit(ex, correct);
    final after = _s.items[ex.ayahIndex].held;

    setState(() {
      _fb = correct ? _Fb.right : _Fb.wrong;
      _justHeld = !before && after;
      if (!correct) _shake++;
      // Picked once per exercise, not read at build time — a getter would
      // re-roll (and visibly flicker) on every unrelated rebuild of this
      // still-mounted panel (the countdown timer, the mascot's own blink).
      if (correct) {
        _rightPhrase = (_rightPhrases.toList()..shuffle()).first;
      }
    });

    correct ? Sfx.right() : Sfx.wrong();
    if (_s.stage == Stage.sealed) Sfx.seal();
  }

  void _advance() {
    if (_s.stage == Stage.failed || _s.stage == Stage.sealed) {
      setState(() => _ex = null);
      return;
    }
    _load();
  }

  void _commitAndClose() {
    _commitProgress(
      didSeal: _s.sealedWholeSurah,
      sealedChunk: _s.stage == Stage.sealed ? _s.currentChunk : null,
    );
    Navigator.of(context).pop();
  }

  void _commitProgress({required bool didSeal, int? sealedChunk}) {
    final minutes = DateTime.now().difference(_startedAt).inMinutes;
    appState.recordSession(
      surahNumber: widget.surah.number,
      heldIndicesNow:
          _s.items.where((i) => i.held).map((i) => i.index).toSet(),
      didSeal: didSeal,
      sealedChunk: sealedChunk,
      hadMistakes: _s.mistakes > 0,
      minutes: minutes < 1 ? 1 : minutes,
    );
  }

  /// Out of hearts restarts only the drilling, not the ayat already held in
  /// earlier chunks this session — those are committed first so a long
  /// surah never loses unrelated progress to one bad chunk.
  void _tryAgain() {
    _commitProgress(didSeal: false);
    _start();
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('این جلسه را ترک می‌کنید؟',
            style: Theme.of(ctx).textTheme.titleLarge),
        content: Text(
          'آیاتی که قبلاً ثبت کرده‌اید حفظ می‌مانند. هرچه هنوز در '
          'حال پیشرفت است بازنشانی می‌شود.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ادامه می‌دهم'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _commitAndClose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _s.stage == Stage.failed
            ? _failed()
            : _s.stage == Stage.sealed
                ? _sealed()
                : _running(),
      ),
    );
  }

  // ------------------------------------------------------------------ chrome

  Widget _running() {
    final ex = _ex;
    if (ex == null) return const SizedBox.shrink();
    if (ex.kind != ExerciseKind.drill) {
      return Column(
        children: [
          _topBar(),
          Expanded(child: _teachBody(ex)),
          _teachFooter(ex),
        ],
      );
    }
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
            child: Shaker(
              trigger: _shake,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _promptRow(ex),
                  const SizedBox(height: AppSpacing.xl),
                  if (ex.isWordBank) ..._wordBank(ex) else ..._choices(ex),
                ],
              ),
            ),
          ),
        ),
        _footer(ex),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Pressable(
            onTap: _confirmLeave,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(Icons.close_rounded, size: 26, color: context.mutedColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.circular),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _s.progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 16,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _s.stage == Stage.gate
                        ? AppColors.secondary
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(Icons.favorite_rounded, size: 22, color: AppColors.red),
          const SizedBox(width: 4),
          Text(
            '${_s.hearts}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.red,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- teaching

  Widget _teachBody(Exercise ex) {
    final listen = ex.kind == ExerciseKind.listen;
    final ayahNumber = widget.surah.ayat[ex.ayahIndex].number;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ayahChip(ayahNumber),
          const SizedBox(height: AppSpacing.xl),
          Text(
            listen ? 'گوش کنید' : 'اکنون همراه با تلاوت بخوانید',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            listen
                ? 'آیه را پخش کنید و متن را دنبال کنید.'
                : 'دوباره پخش کنید و هر عبارت را همزمان با قاری با صدای '
                    'بلند تکرار کنید.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Pressable(
              onTap: () => _playAyah(ex.ayahIndex),
              child: ValueListenableBuilder<bool>(
                valueListenable: recitation.isPlaying,
                builder: (context, playing, _) => Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.blue,
                  ),
                  child: Icon(
                    playing ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                    color: AppColors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          if (!recitation.available) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(
                'صدا در نسخه مرورگر پخش می‌شود — فعلاً آیه زیر را بخوانید.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.borderColor, width: 2),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ex.arabic!,
                textAlign: TextAlign.center,
                style: ArabicType.ayah(
                  size: 30 * settings.arabicScale,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
          if (listen && ex.translation != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              ex.translation!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }

  Widget _teachFooter(Exercise ex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: DuoButton(
        label: ex.kind == ExerciseKind.listen ? 'یاد گرفتم' : 'تکرار کردم',
        onTap: _continueTeach,
        color: AppColors.blue,
      ),
    );
  }

  Widget _promptRow(Exercise ex) {
    final gate = ex.isGate;
    late String label;
    switch (ex.drill!) {
      case Drill.order:
        label = 'آیه را بسازید';
        break;
      case Drill.blank:
        label = 'جای خالی را پر کنید';
        break;
      case Drill.next:
        label = 'آیه بعدی کدام است؟';
        break;
      case Drill.blind:
        label = gate ? 'یادآوری نهایی — بدون اشتباه' : 'بدون کمک بسازید';
        break;
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: gate ? AppColors.secondaryDark : null,
                ),
          ),
        ),
        if (ex.seconds != null)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: _left <= 5
                  ? AppColors.errorWash
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.circular),
            ),
            child: Text(
              '${_left}s',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _left <= 5 ? AppColors.error : context.mutedColor,
                  ),
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------- exercises

  Widget _ayahChip(int n) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          'آیه $n',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.secondaryDark),
        ),
      );

  List<Widget> _wordBank(Exercise ex) {
    Color edge;
    switch (_fb) {
      case _Fb.right:
        edge = AppColors.success;
        break;
      case _Fb.wrong:
        edge = AppColors.error;
        break;
      case _Fb.none:
        edge = context.borderColor;
        break;
    }

    return [
      _ayahChip(widget.surah.ayat[ex.ayahIndex].number),
      const SizedBox(height: AppSpacing.lg),
      if (ex.translation != null && !ex.isGate) ...[
        Text(ex.translation!, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
      ],
      GoldSweep(
        active: _justHeld,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: edge, width: 2.5),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < _placed.length; i++)
                  _tile(
                    ex.tiles[_placed[i]],
                    filled: true,
                    onTap: _fb == _Fb.none
                        ? () {
                            Sfx.tap();
                            setState(() => _placed.removeAt(i));
                          }
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < ex.tiles.length; i++)
              if (!_placed.contains(i))
                _tile(
                  ex.tiles[i],
                  filled: false,
                  onTap: _fb == _Fb.none
                      ? () {
                          Sfx.tap();
                          setState(() => _placed.add(i));
                        }
                      : null,
                ),
          ],
        ),
      ),
    ];
  }

  Widget _tile(String word, {required bool filled, VoidCallback? onTap}) {
    return DuoTile(
      onTap: onTap,
      fillColor:
          filled ? AppColors.blueLight : Theme.of(context).colorScheme.surface,
      borderColor: filled ? AppColors.blue : context.borderColor,
      child: Text(
        word,
        style: ArabicType.tile(
          color: filled
              ? AppColors.blueDark
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  List<Widget> _choices(Exercise ex) {
    final surface = Theme.of(context).colorScheme.surface;
    return [
      _ayahChip(widget.surah.ayat[ex.ayahIndex].number),
      const SizedBox(height: AppSpacing.lg),
      if (ex.contextText != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.borderColor, width: 2),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(ex.contextText!,
                style: ArabicType.ayah(
                    size: 22 * settings.arabicScale,
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        ),
      if (ex.maskedText != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.borderColor, width: 2),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(ex.maskedText!,
                style: ArabicType.ayah(
                    size: 22 * settings.arabicScale,
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        ),
      if (ex.translation != null) ...[
        const SizedBox(height: AppSpacing.md),
        Text(ex.translation!, style: Theme.of(context).textTheme.bodyMedium),
      ],
      const SizedBox(height: AppSpacing.xl),
      for (var i = 0; i < ex.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _option(ex, i),
        ),
    ];
  }

  Widget _option(Exercise ex, int i) {
    final chosen = _selected == i;
    final isCorrect = ex.options[i] == ex.correctOption;
    var border = context.borderColor;
    var fill = Theme.of(context).colorScheme.surface;

    if (_fb != _Fb.none) {
      if (isCorrect) {
        border = AppColors.success;
        fill = AppColors.successWash;
      } else if (chosen) {
        border = AppColors.error;
        fill = AppColors.errorWash;
      }
    } else if (chosen) {
      border = AppColors.blue;
      fill = AppColors.blueLight;
    }

    return DuoTile(
      stretch: true,
      onTap: _fb == _Fb.none
          ? () {
              Sfx.tap();
              setState(() => _selected = i);
            }
          : null,
      borderColor: border,
      fillColor: fill,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          ex.options[i],
          style: ArabicType.ayah(
              size: 21 * settings.arabicScale,
              color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ footer

  Widget _footer(Exercise ex) {
    if (_fb == _Fb.none) {
      return Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.borderColor, width: 2)),
        ),
        child: Row(
          children: [
            if (!ex.isGate)
              Pressable(
                onTap: () {
                  _timer?.cancel();
                  _s.takeHint(ex);
                  setState(() {
                    _fb = _Fb.wrong;
                    _shake++;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  child: Text('راهنما',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AppColors.blue, letterSpacing: 0.6)),
                ),
              ),
            const Spacer(),
            DuoButton(
              label: 'بررسی',
              fullWidth: false,
              onTap: _hasAnswer ? _judge : null,
              color: AppColors.primary,
            ),
          ],
        ),
      );
    }

    final right = _fb == _Fb.right;
    final ayah = widget.surah.ayat[ex.ayahIndex];
    final panelBg = right ? AppColors.primaryLight : AppColors.redLight;
    final ink = right ? AppColors.primaryDeep : AppColors.redDark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 40),
        child: Opacity(opacity: t, child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl),
        decoration: BoxDecoration(color: panelBg),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // A fresh Mascot mounts for every exercise (this whole
                  // panel is conditionally built only while `_fb != none`,
                  // and `_load()` resets `_fb` between exercises) — that's
                  // exactly what makes its entrance replay as a genuine
                  // per-answer reaction rather than a static icon. `happy`
                  // here, not `cheering`: that one's saved for the level/
                  // surah seal screen so finishing still feels bigger than
                  // any single right answer.
                  Mascot(
                    mood: right ? MascotMood.happy : MascotMood.sad,
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    right ? _rightPhrase : 'راه‌حل درست:',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: ink),
                  ),
                ],
              ),
              if (!right) ...[
                const SizedBox(height: AppSpacing.sm),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(ayah.arabic,
                      style: ArabicType.ayah(size: 21, color: ink)),
                ),
              ],
              if (right && _justHeld) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('آیه به خاطر سپرده شد',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: ink)),
              ],
              const SizedBox(height: AppSpacing.lg),
              DuoButton(
                label: 'ادامه',
                onTap: _advance,
                color: right ? AppColors.primary : AppColors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- outcomes

  Widget _failed() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Mascot(mood: MascotMood.sad, size: 76),
          const SizedBox(height: AppSpacing.xl),
          Text('قلب‌ها تمام شد',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            'این سوره از نو شروع می‌شود. حافظه با تکرار ساخته می‌شود، نه با '
            'عبور کردن — ${_s.heldCount} آیه‌ای که حفظ کرده‌اید نگه داشته می‌شود.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xxl),
          DuoButton(label: 'دوباره تلاش کنید', onTap: _tryAgain, color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Pressable(
              onTap: _commitAndClose,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('بازگشت به مسیر یادگیری',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.blue)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sealed() {
    final wholeSurah = _s.sealedWholeSurah;
    final chunkAyat = _s.chunkEnd - _s.chunkStart;
    final levelNumber = _s.currentChunk + 1;
    final xpEarned = chunkAyat * 12 + 15 + (wholeSurah ? 50 : 0);

    return Stack(
      children: [
        Positioned.fill(child: Confetti(play: true)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Mascot(mood: MascotMood.cheering, size: 84),
              const SizedBox(height: AppSpacing.xl),
              Text(
                wholeSurah
                    ? 'سوره ${widget.surah.englishName} مهر و موم شد'
                    : 'سطح $levelNumber کامل شد',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                wholeSurah
                    ? 'شما تمام آیات را به ترتیب، بدون کمک و بدون هیچ اشتباهی '
                        'به‌یاد آوردید. سوره بعدی باز شد.'
                    : 'بدون کمک و بدون هیچ اشتباهی به‌یاد آورده شد. سطح '
                        '${levelNumber + 1} از سوره ${widget.surah.englishName} '
                        'باز شد.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  _resultStat('$chunkAyat', 'آیه حفظ شد'),
                  const SizedBox(width: AppSpacing.xxl),
                  _resultStat('$xpEarned', 'امتیاز کسب شد'),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              DuoButton(label: 'دریافت', onTap: _commitAndClose, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: AppColors.primary)),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
