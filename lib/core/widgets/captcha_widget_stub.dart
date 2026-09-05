import 'package:flutter/widgets.dart';

/// Off-web: nothing to render, no token ever arrives. Callers that
/// require a token before proceeding (signup) should treat "stub
/// platform" the same as "user hasn't completed it yet" — which is
/// already correct default behavior, since [onToken] simply never fires.
class CaptchaWidget extends StatelessWidget {
  final String siteKey;
  final ValueChanged<String> onToken;
  final ValueChanged<String>? onError;

  const CaptchaWidget({
    super.key,
    required this.siteKey,
    required this.onToken,
    this.onError,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
