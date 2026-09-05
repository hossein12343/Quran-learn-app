import 'package:flutter/material.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/captcha_widget.dart';
import '../../core/widgets/duo_button.dart';
import '../../shared/services/app_state.dart';
import '../../shared/services/captcha.dart';
import '../../shared/services/net/net.dart';

/// The form always succeeds locally first — displayName/email are recorded
/// instantly so the app can greet you and hold progress even if nothing is
/// reachable — then AppState syncs against the PocketBase server on this PC
/// in the background. See AppState.signIn / BACKEND.md.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// Kept as a thin wrapper around DuoButton so every call site (login,
/// signup, onboarding) stays unchanged.
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const BigButton({super.key, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return DuoButton(
      label: label.toUpperCase(),
      onTap: onTap,
      color: color ?? AppColors.primary,
      height: 56,
    );
  }
}

/// The origin (`https://host:port/`) this page is actually running at —
/// what must be registered as the OAuth2 client's redirect URI, and what
/// gets passed back to AppState.startGoogleSignIn. Only meaningful on web;
/// on other platforms this is unused since WebNav's stub never redirects.
/// `Uri.origin` never carries a path, query, or fragment — building it
/// this way instead of `Uri.base.replace(fragment: '')` matters:
/// `replace(fragment: '')` sets an *empty* fragment, not *no* fragment, so
/// it still serializes with a trailing `#`. Supabase then appended its own
/// `#access_token=...` straight onto that, producing a real
/// `##access_token=...` fragment that no parser expecting a single `#`
/// could match — confirmed live via a diagnostic log capturing the exact
/// browser URL during a real Google sign-in attempt.
String _oauthRedirectUrl() => '${Uri.base.origin}/';

/// Flat white pill matching Duolingo's third-party-auth buttons — visually
/// distinct from the primary green [BigButton] so it doesn't compete with
/// the main call to action.
class GoogleButton extends StatefulWidget {
  const GoogleButton({super.key});

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  bool _busy = false;
  String? _error;

  Future<void> _tap() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await appState.startGoogleSignIn(_oauthRedirectUrl());
      // On success the browser navigates away to Google entirely; nothing
      // after this point runs in this tab.
    } on NetException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DuoTile(
          onTap: _busy ? null : _tap,
          // fillColor/borderColor both default to theme-aware colors now
          // (see DuoTile's doc comment) — no need to pin them here.
          padding: const EdgeInsets.symmetric(vertical: 14),
          stretch: true,
          child: Center(
            child: Text(
              _busy ? 'در حال انتقال…' : 'ادامه با گوگل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }
}

/// The app's actual mark \u2014 the star-and-crescent mascot on its emerald
/// icon background (`assets/branding/app_logo.png`, the same artwork used
/// for the browser tab/home-screen icon under `web/icons/`), not a text
/// placeholder. Used everywhere the app shows its own identity: the
/// splash screen and every auth screen. The PNG's corners are already
/// transparent-rounded at the source (matching the real app-icon shape),
/// so this only needs to add the drop shadow \u2014 `boxShadow` follows the
/// `Container`'s own `borderRadius`, not the child image's alpha, so that
/// radius is kept in the same ratio (112/512) as the source SVG's.
class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * (112 / 512)),
        boxShadow: AppShadows.hero,
      ),
      child: Image.asset('assets/branding/app_logo.png'),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _captchaToken;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_email.text.contains('@')) {
      setState(() => _error = '\u0627\u06cc\u0646 \u0634\u0628\u06cc\u0647 \u06cc\u06a9 \u0622\u062f\u0631\u0633 \u0627\u06cc\u0645\u06cc\u0644 \u0646\u06cc\u0633\u062a.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = '\u0631\u0645\u0632 \u0639\u0628\u0648\u0631 \u0628\u0627\u06cc\u062f \u062d\u062f\u0627\u0642\u0644 \u06f8 \u06a9\u0627\u0631\u0627\u06a9\u062a\u0631 \u0628\u0627\u0634\u062f.');
      return;
    }
    final name = _email.text.split('@').first;
    // Not gated on `_captchaToken` being non-null \u2014 login already
    // "succeeds locally first" regardless of network state (see the
    // class doc comment at the top of this file), and a missing token
    // just means the background sync will fail the same way a bad
    // password would, surfaced the same offline-friendly way. Requiring
    // it here would break that established offline-first contract for
    // no real security gain (Supabase only starts enforcing this once
    // CAPTCHA protection is turned on server-side \u2014 see `captcha.dart`).
    appState.signIn(name, _email.text,
        password: _password.text, captchaToken: _captchaToken);
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Reveal(index: 0, child: const Center(child: Wordmark())),
              const SizedBox(height: AppSpacing.xl),
              Reveal(
                index: 1,
                child: Column(
                  children: [
                    Text('\u06cc\u0627\u062f\u06af\u06cc\u0631\u06cc \u0642\u0631\u0622\u0646',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text('\u0642\u0631\u0622\u0646 \u0631\u0627 \u0622\u06cc\u0647 \u0628\u0647 \u0622\u06cc\u0647 \u062d\u0641\u0638 \u06a9\u0646\u06cc\u062f',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Reveal(
                index: 2,
                child: AuthField(
                  controller: _email,
                  label: '\u0627\u06cc\u0645\u06cc\u0644',
                  hint: 'you@example.com',
                  keyboard: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 3,
                child: AuthField(
                  controller: _password,
                  label: '\u0631\u0645\u0632 \u0639\u0628\u0648\u0631',
                  hint: '\u062d\u062f\u0627\u0642\u0644 \u06f8 \u06a9\u0627\u0631\u0627\u06a9\u062a\u0631',
                  obscure: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorWash,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(_error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.error)),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: CaptchaWidget(
                  siteKey: turnstileSiteKey,
                  onToken: (t) => setState(() => _captchaToken = t),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Reveal(index: 4, child: BigButton(label: '\u0648\u0631\u0648\u062f', onTap: _submit)),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 5,
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Text('\u06cc\u0627',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Reveal(index: 6, child: GoogleButton()),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('\u062a\u0627\u0632\u0647 \u0627\u0648\u0645\u062f\u06cc\u061f ',
                      style: Theme.of(context).textTheme.bodySmall),
                  Pressable(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/signup'),
                    child: Text('\u0627\u06cc\u062c\u0627\u062f \u062d\u0633\u0627\u0628 \u06a9\u0627\u0631\u0628\u0631\u06cc',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _captchaToken;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'نام خود را وارد کنید.');
      return;
    }
    if (!_email.text.contains('@')) {
      setState(() => _error = 'این شبیه یک آدرس ایمیل نیست.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'رمز عبور باید حداقل ۸ کاراکتر باشد.');
      return;
    }
    // Unlike login (which "succeeds locally first" regardless of network
    // state, by design), signup can't proceed at all without a real
    // server round-trip — there's no local-only signup to fall back to.
    // That makes it worth actually gating on a completed challenge here,
    // rather than just passing along whatever's there like login does.
    if (_captchaToken == null) {
      setState(() => _error = 'لطفاً تأیید امنیتی زیر را کامل کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await appState.beginSignup(_name.text, _email.text, _password.text,
          captchaToken: _captchaToken);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => VerifyCodePage(email: _email.text.trim()),
      ));
    } on NetException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'امکان اتصال به سرور نبود: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(index: 0, child: const Center(child: Wordmark(size: 48))),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 1,
                child: Text('حساب کاربری خود را بسازید',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
              const SizedBox(height: AppSpacing.sm),
              Reveal(
                index: 2,
                child: Text('پیشرفت شما در این دستگاه ذخیره می‌شود.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Reveal(
                index: 3,
                child: AuthField(
                    controller: _name, label: 'نام', hint: 'نام شما'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 4,
                child: AuthField(
                  controller: _email,
                  label: 'ایمیل',
                  hint: 'you@example.com',
                  keyboard: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 5,
                child: AuthField(
                  controller: _password,
                  label: 'رمز عبور',
                  hint: 'حداقل ۸ کاراکتر',
                  obscure: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorWash,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(_error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.error)),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: CaptchaWidget(
                  siteKey: turnstileSiteKey,
                  onToken: (t) => setState(() => _captchaToken = t),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              BigButton(
                label: _busy ? 'در حال ایجاد حساب…' : 'ایجاد حساب',
                onTap: _busy ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text('یا',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const GoogleButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The code-entry gate shown right after account creation. Nothing about
/// signup is considered final until this passes — see
/// `AppState.beginSignup`/`confirmSignup`.
class VerifyCodePage extends StatefulWidget {
  final String email;
  const VerifyCodePage({super.key, required this.email});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _code = TextEditingController();
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _resending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'کدی که به ایمیلتان ارسال شد را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await appState.confirmSignup(code);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } on NetException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'این کد کار نکرد: ${e.message}';
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      await appState.resendSignupCode();
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = 'کد جدید ارسال شد.';
      });
    } on NetException catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = 'امکان ارسال مجدد نبود: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(index: 0, child: const Center(child: Wordmark(size: 48))),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 1,
                child: Text('ایمیل خود را بررسی کنید',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
              const SizedBox(height: AppSpacing.sm),
              Reveal(
                index: 2,
                child: Text(
                  'یک کد تایید به ${widget.email} ارسال کردیم.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Reveal(
                index: 3,
                child: AuthField(
                  controller: _code,
                  label: 'کد تایید',
                  hint: 'کد ۶ رقمی',
                  keyboard: TextInputType.number,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorWash,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(_error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.error)),
                ),
              ],
              if (_notice != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(_notice!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.primary)),
              ],
              const SizedBox(height: AppSpacing.xl),
              BigButton(
                label: _busy ? 'در حال بررسی…' : 'تایید',
                onTap: _busy ? null : _verify,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Pressable(
                  onTap: _resending ? null : _resend,
                  child: Text(
                    _resending ? 'در حال ارسال…' : 'ارسال مجدد کد',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                    Reveal(index: 0, child: const Center(child: Wordmark(size: 48))),
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
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
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
