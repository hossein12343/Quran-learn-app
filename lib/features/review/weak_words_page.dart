import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/duo_button.dart';
import '../../core/widgets/mascot.dart';
import '../../shared/data/quran_seed.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/weak_spots.dart';
import '../quiz/quiz_page.dart' show Sfx;

Surah? _surahNumbered(int number) {
  for (final s in surahs) {
    if (s.number == number) return s;
  }
  return null;
}

/// How a weak spot reads on its own: the word itself, or the opening of
/// the ayah when it's the whole ayah that's weak. Null if the text isn't
/// loaded (or no longer matches).
String? weakSpotLabel(WeakSpot spot) {
  final surah = _surahNumbered(spot.surah);
  if (surah == null || spot.ayah >= surah.ayat.length) return null;
  final words = surah.ayat[spot.ayah].words;
  if (spot.isWholeAyah) {
    return words.length <= 3 ? words.join(' ') : '${words.take(3).join(' ')} …';
  }
  return spot.word < words.length ? words[spot.word] : null;
}

/// Where a weak spot is, in words: "الفاتحة · آیه ۳".
String? weakSpotPlace(WeakSpot spot) {
  final surah = _surahNumbered(spot.surah);
  if (surah == null || spot.ayah >= surah.ayat.length) return null;
  return '${surah.arabicName} · آیه ${surah.ayat[spot.ayah].number}';
}

class _Question {
  final WeakSpot spot;
  final String title;
  final String place;
  final String? arabic;
  final String? translation;
  final List<String> options;
  final String correct;

  const _Question({
    required this.spot,
    required this.title,
    required this.place,
    required this.options,
    required this.correct,
    this.arabic,
    this.translation,
  });
}

/// One question per weak spot: the missing word in its own ayah, or — for
/// a whole weak ayah — which ayah comes next. Every answer counts toward
/// the spot leaving the list (two right in a row), so this is where the
/// words the learner keeps missing actually get fixed.
List<_Question> _buildQuestions(List<WeakSpot> spots, math.Random rng) {
  final questions = <_Question>[];
  for (final spot in spots) {
    final surah = _surahNumbered(spot.surah);
    if (surah == null || spot.ayah >= surah.ayat.length) continue;
    final ayah = surah.ayat[spot.ayah];
    final place = '${surah.arabicName} · آیه ${ayah.number}';

    if (!spot.isWholeAyah) {
      final words = ayah.words;
      if (spot.word >= words.length) continue;
      final correct = words[spot.word];
      final masked = [...words]..[spot.word] = '———';
      // Distractors from the surrounding ayat of the same surah, so every
      // option looks like it belongs.
      final pool = <String>{
        for (var i = math.max(0, spot.ayah - 3);
            i < math.min(surah.ayat.length, spot.ayah + 4);
            i++)
          ...surah.ayat[i].words,
      }..remove(correct);
      final options = [correct, ...(pool.toList()..shuffle(rng)).take(3)]
        ..shuffle(rng);
      if (options.length < 2) continue;
      questions.add(_Question(
        spot: spot,
        title: 'کلمهٔ جاافتاده کدام است؟',
        place: place,
        arabic: masked.join(' '),
        translation: ayah.translation,
        options: options,
        correct: correct,
      ));
      continue;
    }

    final previous = spot.ayah > 0 ? surah.ayat[spot.ayah - 1].arabic : null;
    final others = surah.ayat
        .map((a) => a.arabic)
        .where((t) => t != ayah.arabic && t != previous)
        .toList()
      ..shuffle(rng);
    final options = [ayah.arabic, ...others.take(3)]..shuffle(rng);
    if (options.length < 2) continue;
    questions.add(previous != null
        ? _Question(
            spot: spot,
            title: 'آیهٔ بعد از این کدام است؟',
            place: place,
            arabic: previous,
            options: options,
            correct: ayah.arabic,
          )
        : _Question(
            spot: spot,
            title: 'کدام آیه این معنی را دارد؟',
            place: place,
            translation: ayah.translation,
            options: options,
            correct: ayah.arabic,
          ));
  }
  return questions;
}

/// Practise just the words (and ayat) you keep getting wrong.
class WeakWordsPage extends StatefulWidget {
  const WeakWordsPage({super.key});

  @override
  State<WeakWordsPage> createState() => _WeakWordsPageState();
}

class _WeakWordsPageState extends State<WeakWordsPage> {
  late final List<_Question> _questions =
      _buildQuestions(appState.weakSpots.ranked(limit: 10), math.Random());
  int _index = 0;
  int? _selected;
  bool _checked = false;
  int _right = 0;
  int _cleared = 0;

  _Question get _q => _questions[_index];
  bool get _done => _index >= _questions.length;

  void _check() {
    final q = _q;
    final correct = q.options[_selected!] == q.correct;
    final spot = q.spot;
    appState.recordWeakSpots(spot.surah, spot.ayah,
        missed: correct ? const [] : [spot.word],
        right: correct ? [spot.word] : const []);
    correct ? Sfx.right() : Sfx.wrong();
    setState(() {
      _checked = true;
      if (correct) {
        _right++;
        if (appState.weakSpots[spot.key] == null) _cleared++;
      }
    });
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _checked = false;
    });
    if (_done) appState.noteWeakWordsPractised();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('کلمات دشوار'),
        bottom: _questions.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _index / _questions.length,
                  minHeight: 4,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
      ),
      body: SafeArea(
        child: _questions.isEmpty
            ? _empty(context)
            : (_done ? _finished(context) : _question(context)),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return _centered(context, [
      const Mascot(mood: MascotMood.happy, size: 72),
      const SizedBox(height: AppSpacing.lg),
      Text('کلمهٔ دشواری نمانده',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.sm),
      Text('کلماتی که در تمرین‌ها اشتباه کنید اینجا جمع می‌شوند.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium),
    ]);
  }

  Widget _finished(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _centered(context, [
      Mascot(
          mood: _right == _questions.length
              ? MascotMood.cheering
              : MascotMood.happy,
          size: 84),
      const SizedBox(height: AppSpacing.lg),
      Text('تمرین تمام شد',
          textAlign: TextAlign.center, style: t.headlineMedium),
      const SizedBox(height: AppSpacing.sm),
      Text('$_right از ${_questions.length} درست',
          textAlign: TextAlign.center, style: t.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        _cleared > 0
            ? '$_cleared مورد دیگر دشوار نیست و از فهرست برداشته شد.'
            : 'هر کلمه با دو پاسخ درست پشت‌سرهم از فهرست برداشته می‌شود.',
        textAlign: TextAlign.center,
        style: t.bodyMedium?.copyWith(color: context.mutedColor),
      ),
      const SizedBox(height: AppSpacing.xl),
      DuoButton(label: 'بازگشت', onTap: () => Navigator.of(context).pop()),
    ]);
  }

  Widget _centered(BuildContext context, List<Widget> children) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final q = _q;
    final t = Theme.of(context).textTheme;
    final wordOptions = !q.spot.isWholeAyah;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(q.place,
                  style: t.labelMedium?.copyWith(color: context.mutedColor)),
              const SizedBox(height: AppSpacing.xs),
              Text(q.title, style: t.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              if (q.arabic != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: context.borderColor, width: 2),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _checked && wordOptions
                          ? q.arabic!.replaceFirst('———', q.correct)
                          : q.arabic!,
                      textAlign: TextAlign.center,
                      style: ArabicType.ayah(size: 26),
                    ),
                  ),
                ),
              if (q.translation != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(q.translation!,
                    style: t.bodyMedium?.copyWith(color: context.mutedColor)),
              ],
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < q.options.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.md),
                _option(context, q, i, wordOptions),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: _checked
              ? _feedback(context, q)
              : DuoButton(
                  label: 'بررسی',
                  onTap: _selected == null ? null : _check,
                ),
        ),
      ],
    );
  }

  Widget _option(BuildContext context, _Question q, int i, bool word) {
    final isCorrect = q.options[i] == q.correct;
    final chosen = _selected == i;
    Color? border;
    Color? fill;
    if (_checked && isCorrect) {
      border = AppColors.primary;
      fill = AppColors.primaryLight;
    } else if (_checked && chosen) {
      border = AppColors.error;
      fill = AppColors.errorWash;
    } else if (chosen) {
      border = AppColors.primary;
    }
    return DuoTile(
      onTap: _checked
          ? null
          : () {
              Sfx.tap();
              setState(() => _selected = i);
            },
      borderColor: border,
      fillColor: fill,
      stretch: true,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          q.options[i],
          textAlign: TextAlign.center,
          style: ArabicType.ayah(size: word ? 26 : 20),
        ),
      ),
    );
  }

  Widget _feedback(BuildContext context, _Question q) {
    final right = q.options[_selected!] == q.correct;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          right ? 'درست است!' : 'پاسخ درست سبز شده است.',
          textAlign: TextAlign.center,
          style: t.titleMedium
              ?.copyWith(color: right ? AppColors.primary : AppColors.error),
        ),
        const SizedBox(height: AppSpacing.md),
        DuoButton(
          label: _index + 1 < _questions.length ? 'ادامه' : 'پایان',
          color: right ? AppColors.primary : AppColors.error,
          onTap: _next,
        ),
      ],
    );
  }
}
