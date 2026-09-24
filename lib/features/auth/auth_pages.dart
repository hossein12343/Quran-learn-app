import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/captcha_widget.dart';
import '../../core/widgets/duo_button.dart';
import '../../core/widgets/language_toggle.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/backend.dart';
import '../../shared/services/captcha.dart';
import '../../shared/services/net/net.dart';

/// The origin (`https://host/`) this page is running at — what OAuth
/// providers redirect back to. Built from `Uri.origin` rather than
/// `Uri.base.replace(fragment: '')`: an *empty* fragment still serializes
/// with a trailing `#`, and Supabase then appended its own
/// `#access_token=...` onto it, producing `##access_token=...` — confirmed
/// live during a real Google sign-in attempt.
String _oauthRedirectUrl() => '${Uri.base.origin}/';

bool _looksLikeEmail(String s) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

/// Persian and Arabic-Indic digits become ASCII — codes are typed on a
/// Persian keyboard as often as not, and the server only accepts 0-9.
String _asciiDigits(String s) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final out = StringBuffer();
  for (final ch in s.split('')) {
    final p = persian.indexOf(ch);
    final a = arabic.indexOf(ch);
    out.write(p >= 0 ? '$p' : (a >= 0 ? '$a' : ch));
  }
  return out.toString();
}

/// Every auth screen shares this frame: language toggle, optional back
/// button, content held to a phone-like column on wide screens.
class _AuthScaffold extends StatelessWidget {
  final List<Widget> children;
  final bool showBack;

  const _AuthScaffold({required this.children, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        actions: const [
          // Reachable before signing in on purpose — a visitor on a device
          // in the "wrong" language needs to be able to read this screen.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(child: LanguageToggle()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled text field with an inline error, autofill hints (so iPhone
/// offers saved passwords, suggests strong ones, and fills codes from
/// Mail), and a show/hide toggle for passwords.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool password;
  final TextInputType? keyboard;
  final Iterable<String>? autofillHints;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;
  final String? error;
  final FocusNode? focusNode;

  /// Emails and passwords are Latin text; typing them inside the app's
  /// right-to-left layout puts the cursor on the wrong end.
  final bool ltr;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.password = false,
    this.keyboard,
    this.autofillHints,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.error,
    this.focusNode,
    this.ltr = false,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: widget.password && _hidden,
          keyboardType: widget.keyboard,
          autofillHints: widget.autofillHints,
          textInputAction: widget.action,
          onSubmitted: widget.onSubmitted,
          autocorrect: false,
          enableSuggestions: !widget.password && !widget.ltr,
          textDirection: widget.ltr ? TextDirection.ltr : null,
          // Explicit, so the hint lines up with where typing starts;
          // `start` would put the hint on the right in this RTL app.
          textAlign: widget.ltr ? TextAlign.left : TextAlign.start,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.error,
            errorMaxLines: 2,
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _hidden ? 'نمایش رمز' : 'پنهان کردن رمز',
                    icon: Icon(_hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Kept as a thin wrapper around DuoButton so every call site stays short.
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const BigButton({super.key, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return DuoButton(
      label: label,
      onTap: onTap,
      color: color ?? AppColors.primary,
      height: 56,
    );
  }
}

/// The app's actual mark — the star-and-crescent mascot on its emerald icon
/// background (`assets/branding/app_logo.png`, the same artwork as the
/// home-screen icon), used on the splash screen and every auth screen.
class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    // Decoded at display size (3x for sharp phone screens) rather than the
    // full 512px source — this sits directly on the cold-start path.
    final px = (size * 3).round();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * (112 / 512)),
        boxShadow: AppShadows.hero,
      ),
      child: Image.asset(
        'assets/branding/app_logo.png',
        cacheWidth: px,
        cacheHeight: px,
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  final String message;
  const _FormError(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorWash,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(message,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.error)),
    );
  }
}

/// Turnstile, which Supabase requires for every password sign-in, signup
/// and reset. In "Managed" mode it nearly always passes on its own in a
/// second or two, so screens don't make people wait on it: tapping the
/// button early just queues the action until the token lands.
///
/// A token only works once, so after every attempt the screen bumps
/// [generation], which remounts the widget for a fresh challenge —
/// otherwise a retry after a typo would fail the security check.
class _SecurityCheck extends StatelessWidget {
  final int generation;
  final ValueChanged<String> onToken;

  const _SecurityCheck({required this.generation, required this.onToken});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CaptchaWidget(
        key: ValueKey(generation),
        siteKey: turnstileSiteKey,
        onToken: onToken,
      ),
    );
  }
}

// --------------------------------------------------------------- social

/// "Continue with Google" — shown only while Google is switched on in the
/// Supabase dashboard, so a misconfigured provider never offers a button
/// that leads to an error page.
class _SocialButtons extends StatefulWidget {
  const _SocialButtons();

  @override
  State<_SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends State<_SocialButtons> {
  /// Shared across screens so switching between them doesn't refetch.
  static Set<String>? _cache;

  Set<String>? _providers = _cache;
  String? _busy;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_providers == null) {
      Backend.enabledProviders().then((p) {
        _cache = p;
        if (mounted) setState(() => _providers = p);
      }).catchError((Object _) {
        if (mounted) setState(() => _providers = const {});
      });
    }
  }

  Future<void> _go(String provider) async {
    setState(() {
      _busy = provider;
      _error = null;
    });
    try {
      await appState.startOAuthSignIn(provider, _oauthRedirectUrl());
      // On success the browser leaves for the provider's own page.
    } on NetException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    if (providers == null) {
      // Reserve roughly the buttons' height so the form below doesn't
      // jump when they arrive.
      return const SizedBox(height: 56);
    }
    final buttons = <Widget>[
      if (providers.contains('google'))
        _ProviderButton(
          label: _busy == 'google' ? 'در حال انتقال…' : 'ادامه با گوگل',
          leading: const _GoogleMark(),
          background: Theme.of(context).colorScheme.surface,
          foreground: Theme.of(context).colorScheme.onSurface,
          border: context.borderColor,
          onTap: _busy == null ? () => _go('google') : null,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          buttons[i],
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _FormError(_error!),
        ],
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onTap;

  const _ProviderButton({
    required this.label,
    required this.leading,
    required this.background,
    required this.foreground,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
              border != null ? Border.all(color: border!, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain four-colour "G", drawn rather than shipped as an image since
/// this app bundles no image assets beyond its own logo.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.6;
    final r = (size.shortestSide - stroke) / 2;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint p(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.14159265 / 180;
    // Clockwise from the gap on the right: blue, green, yellow, red.
    canvas.drawArc(
        rect, -40 * deg, 85 * deg, false, p(const Color(0xFF4285F4)));
    canvas.drawArc(rect, 45 * deg, 90 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(
        rect, 135 * deg, 85 * deg, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(
        rect, 220 * deg, 95 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r + stroke / 2, c.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------- sign in / sign up

/// Kept so existing `/login` and `/signup` routes open the right mode.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthPage();
}

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthPage(signUp: true);
}

/// Signing in and creating an account on one screen: Google on top (one
/// tap, no code), then email with a toggle between the two modes.
/// They used to be separate pages, each with its own copy of the form.
class AuthPage extends StatefulWidget {
  final bool signUp;
  const AuthPage({super.key, this.signUp = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _signUp = widget.signUp;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  String? _notice;

  String? _captchaToken;
  int _captchaGeneration = 0;
  bool _waitingForCaptcha = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    if (signUp == _signUp) return;
    setState(() {
      _signUp = signUp;
      _nameError = _emailError = _passwordError = _formError = null;
      _notice = null;
    });
  }

  bool _validate() {
    final email = _email.text.trim();
    setState(() {
      _nameError =
          _signUp && _name.text.trim().isEmpty ? 'نام خود را وارد کنید.' : null;
      _emailError = email.isEmpty
          ? 'ایمیل خود را وارد کنید.'
          : (_looksLikeEmail(email) ? null : 'این آدرس ایمیل معتبر نیست.');
      _passwordError = _password.text.isEmpty
          ? 'رمز عبور را وارد کنید.'
          : (_signUp && _password.text.length < 8
              ? 'رمز عبور باید حداقل ۸ کاراکتر باشد.'
              : null);
      _formError = null;
      _notice = null;
    });
    return _nameError == null && _emailError == null && _passwordError == null;
  }

  void _onCaptchaToken(String token) {
    _captchaToken = token;
    if (_waitingForCaptcha) {
      _waitingForCaptcha = false;
      _submit();
    }
  }

  /// Uses up the current token: whatever happens next, the next attempt
  /// needs a fresh one.
  String _takeCaptchaToken() {
    final t = _captchaToken!;
    _captchaToken = null;
    _captchaGeneration++;
    return t;
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    if (_captchaToken == null) {
      setState(() => _waitingForCaptcha = true);
      return;
    }
    setState(() => _busy = true);
    final email = _email.text.trim();
    try {
      if (_signUp) {
        await appState.beginSignup(_name.text.trim(), email, _password.text,
            captchaToken: _takeCaptchaToken());
        TextInput.finishAutofillContext();
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              VerifyCodePage(email: email, purpose: CodePurpose.signup),
        ));
      } else {
        await appState.signIn(email, _password.text,
            captchaToken: _takeCaptchaToken());
        TextInput.finishAutofillContext();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }
    } on NetException catch (e) {
      if (!mounted) return;
      await _handleError(e, email);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleError(NetException e, String email) async {
    switch (e.code) {
      case 'email_not_confirmed':
        // Signed up earlier but never entered the code: send a fresh one
        // and pick up where they left off instead of just refusing.
        try {
          await appState.resumeUnconfirmedSignup(email);
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                VerifyCodePage(email: email, purpose: CodePurpose.signup),
          ));
        } on NetException catch (e2) {
          if (mounted) setState(() => _formError = e2.message);
        }
      case 'user_already_exists' || 'email_exists':
        setState(() {
          _signUp = false;
          _notice = e.message;
        });
        _passwordFocus.requestFocus();
      case 'invalid_credentials':
        setState(() => _passwordError = e.message);
      default:
        setState(() => _formError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final waiting = _waitingForCaptcha && !_busy;
    final label = _busy
        ? (_signUp ? 'در حال ساخت حساب…' : 'در حال ورود…')
        : waiting
            ? 'در حال بررسی امنیتی…'
            : (_signUp ? 'ساخت حساب' : 'ورود');
    return _AuthScaffold(
      children: [
        const Center(child: Wordmark(size: 64)),
        const SizedBox(height: AppSpacing.lg),
        Text('یادگیری قرآن',
            textAlign: TextAlign.center, style: t.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _signUp
              ? 'حساب بسازید تا پیشرفتتان همه‌جا همراهتان باشد.'
              : 'خوش برگشتید. برای ادامه وارد شوید.',
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: context.mutedColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SocialButtons(),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('یا با ایمیل',
                  style: t.bodySmall?.copyWith(color: context.mutedColor)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _ModeSwitch(signUp: _signUp, onChanged: _setMode),
        const SizedBox(height: AppSpacing.lg),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: Motion.enter,
                curve: Motion.smooth,
                alignment: Alignment.topCenter,
                child: _signUp
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: AuthField(
                          controller: _name,
                          label: 'نام',
                          hint: 'نامی که در برنامه نمایش داده شود',
                          autofillHints: const [AutofillHints.name],
                          error: _nameError,
                          onSubmitted: (_) => _emailFocus.requestFocus(),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              AuthField(
                controller: _email,
                focusNode: _emailFocus,
                label: 'ایمیل',
                hint: 'you@example.com',
                keyboard: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                ltr: true,
                error: _emailError,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthField(
                controller: _password,
                focusNode: _passwordFocus,
                label: 'رمز عبور',
                hint: _signUp ? 'حداقل ۸ کاراکتر' : null,
                password: true,
                ltr: true,
                autofillHints: [
                  _signUp ? AutofillHints.newPassword : AutofillHints.password,
                ],
                action: TextInputAction.done,
                error: _passwordError,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (!_signUp)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) =>
                    ForgotPasswordPage(initialEmail: _email.text.trim()),
              )),
              child: const Text('رمز را فراموش کرده‌اید؟'),
            ),
          )
        else
          const SizedBox(height: AppSpacing.md),
        if (_notice != null) ...[
          Text(_notice!,
              style: t.bodySmall?.copyWith(color: AppColors.primary)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_formError != null) ...[
          _FormError(_formError!),
          const SizedBox(height: AppSpacing.md),
        ],
        _SecurityCheck(
          generation: _captchaGeneration,
          onToken: _onCaptchaToken,
        ),
        const SizedBox(height: AppSpacing.lg),
        BigButton(label: label, onTap: _busy || waiting ? null : _submit),
      ],
    );
  }
}

/// "ورود | ثبت‌نام" with a sliding highlight, like an iOS segmented control.
class _ModeSwitch extends StatelessWidget {
  final bool signUp;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.signUp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option(String label, bool value) {
      final on = signUp == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: Motion.enter,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 15,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  color: on ? scheme.onSurface : context.mutedColor,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.borderColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: Motion.enter,
            curve: Motion.smooth,
            alignment: signUp
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md - 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(children: [option('ورود', false), option('ثبت‌نام', true)]),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ the code

enum CodePurpose { signup, recovery }

/// Six boxes for the emailed code. Fills itself from Mail on iPhone
/// (`one-time-code` autofill), accepts pasting and Persian digits, and
/// submits as soon as the sixth digit lands — no button needed.
class VerifyCodePage extends StatefulWidget {
  final String email;
  final CodePurpose purpose;

  const VerifyCodePage({
    super.key,
    required this.email,
    this.purpose = CodePurpose.signup,
  });

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  static const _length = 6;
  static const _resendWait = 60;

  final _code = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  String? _notice;
  bool _busy = false;
  int _secondsLeft = _resendWait;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendWait);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final digits = _asciiDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
    final clipped =
        digits.length > _length ? digits.substring(0, _length) : digits;
    if (clipped != raw) {
      _code.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
    }
    setState(() => _error = null);
    if (clipped.length == _length) _verify();
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _code.text;
    if (code.length < _length) {
      setState(() => _error = 'کد ۶ رقمی را کامل وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (widget.purpose == CodePurpose.signup) {
        await appState.confirmSignup(code);
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/onboarding', (_) => false);
      } else {
        await appState.confirmPasswordReset(code);
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/new-password', (_) => false);
      }
    } on NetException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
        _code.clear();
      });
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (widget.purpose == CodePurpose.recovery) {
      // Sending a reset email needs a fresh security check, which lives
      // on the previous screen — go back there with the email filled in.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await appState.resendSignupCode();
      if (!mounted) return;
      setState(() => _notice = 'کد جدید ارسال شد.');
      _startCountdown();
    } on NetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final code = _code.text;
    return _AuthScaffold(
      showBack: true,
      children: [
        const Center(child: Wordmark(size: 52)),
        const SizedBox(height: AppSpacing.lg),
        Text('ایمیل خود را بررسی کنید',
            textAlign: TextAlign.center, style: t.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'کد ۶ رقمی را به '),
            TextSpan(
              text: widget.email,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' فرستادیم.'),
          ]),
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: context.mutedColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Codes read left to right even in a right-to-left app.
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 60,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < _length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _CodeBox(
                          digit: i < code.length ? code[i] : '',
                          active: _focus.hasFocus &&
                              (i == code.length ||
                                  (i == _length - 1 && code.length == _length)),
                          error: _error != null,
                        ),
                      ),
                    ],
                  ],
                ),
                // The real input sits invisibly over the boxes: taps focus
                // it, the keyboard types into it, and long-press pastes.
                Positioned.fill(
                  child: TextField(
                    controller: _code,
                    focusNode: _focus,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    onChanged: _onChanged,
                    showCursor: false,
                    enableInteractiveSelection: true,
                    style: const TextStyle(color: Colors.transparent),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_busy)
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        if (_error != null)
          Text(_error!,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppColors.error)),
        if (_notice != null)
          Text(_notice!,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppColors.primary)),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton(
            onPressed: _secondsLeft > 0 || _busy ? null : _resend,
            child: Text(_secondsLeft > 0
                ? 'ارسال دوباره تا $_secondsLeft ثانیه دیگر'
                : 'کد را دریافت نکردید؟ ارسال دوباره'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ایمیل را اشتباه نوشته‌اید؟ ویرایش',
                style: t.bodySmall?.copyWith(color: context.mutedColor)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'ایمیل را پیدا نمی‌کنید؟ پوشهٔ اسپم را هم نگاه کنید.',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: context.mutedColor),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String digit;
  final bool active;
  final bool error;

  const _CodeBox(
      {required this.digit, required this.active, required this.error});

  @override
  Widget build(BuildContext context) {
    final border = error
        ? AppColors.error
        : (active ? AppColors.primary : context.borderColor);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: active ? 2.5 : 2),
      ),
      child: Text(
        digit,
        style: Theme.of(context)
            .textTheme
            .headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ------------------------------------------------------ password reset

class ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _email = TextEditingController(text: widget.initialEmail);
  String? _emailError;
  String? _formError;
  String? _captchaToken;
  int _captchaGeneration = 0;
  bool _waitingForCaptcha = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _onCaptchaToken(String token) {
    _captchaToken = token;
    if (_waitingForCaptcha) {
      _waitingForCaptcha = false;
      _send();
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    final email = _email.text.trim();
    setState(() {
      _emailError =
          _looksLikeEmail(email) ? null : 'این آدرس ایمیل معتبر نیست.';
      _formError = null;
    });
    if (_emailError != null) return;
    if (_captchaToken == null) {
      setState(() => _waitingForCaptcha = true);
      return;
    }
    final token = _captchaToken!;
    setState(() {
      _busy = true;
      _captchaToken = null;
      _captchaGeneration++;
    });
    try {
      await appState.beginPasswordReset(email, captchaToken: token);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            VerifyCodePage(email: email, purpose: CodePurpose.recovery),
      ));
    } on NetException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final waiting = _waitingForCaptcha && !_busy;
    return _AuthScaffold(
      showBack: true,
      children: [
        const Center(child: Wordmark(size: 52)),
        const SizedBox(height: AppSpacing.lg),
        Text('بازیابی رمز عبور',
            textAlign: TextAlign.center, style: t.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'ایمیل حسابتان را وارد کنید تا یک کد برای ساختن رمز جدید بفرستیم.',
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: context.mutedColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        AuthField(
          controller: _email,
          label: 'ایمیل',
          hint: 'you@example.com',
          keyboard: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          ltr: true,
          action: TextInputAction.done,
          error: _emailError,
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_formError != null) ...[
          _FormError(_formError!),
          const SizedBox(height: AppSpacing.md),
        ],
        _SecurityCheck(
          generation: _captchaGeneration,
          onToken: _onCaptchaToken,
        ),
        const SizedBox(height: AppSpacing.lg),
        BigButton(
          label: _busy
              ? 'در حال ارسال…'
              : (waiting ? 'در حال بررسی امنیتی…' : 'ارسال کد'),
          onTap: _busy || waiting ? null : _send,
        ),
      ],
    );
  }
}

/// Reached after a reset code (or a reset email's link) has signed the
/// user in; route `/new-password`.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_password.text.length < 8) {
      setState(() => _error = 'رمز عبور باید حداقل ۸ کاراکتر باشد.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await appState.setNewPassword(_password.text);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on NetException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _AuthScaffold(
      children: [
        const Center(child: Wordmark(size: 52)),
        const SizedBox(height: AppSpacing.lg),
        Text('رمز جدید بسازید',
            textAlign: TextAlign.center, style: t.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'وارد حسابتان شدید. یک رمز جدید انتخاب کنید.',
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: context.mutedColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        AutofillGroup(
          child: AuthField(
            controller: _password,
            label: 'رمز جدید',
            hint: 'حداقل ۸ کاراکتر',
            password: true,
            ltr: true,
            autofillHints: const [AutofillHints.newPassword],
            action: TextInputAction.done,
            error: _error,
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        BigButton(
          label: _busy ? 'در حال ذخیره…' : 'ذخیره و ادامه',
          onTap: _busy ? null : _save,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ onboarding

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _goals = <String>[
    'حفظ سوره‌های کوتاه',
    'حفظ یک جزء',
    'مرور آنچه قبلاً حفظ کرده‌ام',
  ];
  static const _minutes = <int>[5, 10, 20];

  String _goal = _goals.first;
  int _daily = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Reveal(
                        index: 0,
                        child: const Center(child: Wordmark(size: 48))),
                    const SizedBox(height: AppSpacing.lg),
                    Reveal(
                      index: 1,
                      child: Text('برای چه اینجا آمده‌اید؟',
                          style: Theme.of(context).textTheme.displayMedium),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    for (var i = 0; i < _goals.length; i++)
                      Reveal(
                        index: i + 2,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _choice(
                            _goals[i],
                            selected: _goal == _goals[i],
                            onTap: () => setState(() => _goal = _goals[i]),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('هر روز چقدر وقت می‌گذارید؟',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        for (final m in _minutes) ...[
                          Expanded(
                            child: _choice(
                              '$m دقیقه',
                              selected: _daily == m,
                              onTap: () => setState(() => _daily = m),
                              center: true,
                            ),
                          ),
                          if (m != _minutes.last)
                            const SizedBox(width: AppSpacing.md),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: BigButton(
                label: 'شروع یادگیری',
                onTap: () {
                  appState.setGoal(_goal, _daily);
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(String label,
      {required bool selected,
      required VoidCallback onTap,
      bool center = false}) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.lg),
        alignment: center ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primary : context.borderColor,
            width: 2.5,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? AppColors.primaryDeep : null,
              ),
        ),
      ),
    );
  }
}
