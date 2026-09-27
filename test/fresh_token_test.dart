import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/app_state.dart';
import 'package:quran_learn_app/shared/services/backend.dart';
import 'package:quran_learn_app/shared/services/net/net.dart';

const _expired = NetException('x', technicalDetail: 'JWT expired');

void main() {
  var renewals = 0;

  setUp(() {
    renewals = 0;
    appState.debugSetTokens('old', 'refresh-1');
    appState.renewSession = (refreshToken) async {
      renewals++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return AuthSession(
        accessToken: 'new',
        refreshToken: 'refresh-2',
        userId: 'u',
        email: '',
      );
    };
  });

  tearDown(() {
    appState.renewSession = Backend.refresh;
    appState.debugSetTokens(null, null);
  });

  Future<String> request(String token) async {
    if (token == 'old') throw _expired;
    return 'ok with $token';
  }

  test('an expired token is renewed once and the request retried', () async {
    expect(await appState.withFreshToken(request), 'ok with new');
    expect(renewals, 1);
    expect(appState.authToken, 'new');
  });

  test('requests that expire together share one renewal', () async {
    final results = await Future.wait(
        [for (var i = 0; i < 5; i++) appState.withFreshToken(request)]);
    expect(results, everyElement('ok with new'));
    expect(renewals, 1);
  });

  test('the auth server wording for an expired token counts too', () async {
    var first = true;
    final result = await appState.withFreshToken((token) async {
      if (first) {
        first = false;
        throw const NetException('x', code: 'bad_jwt');
      }
      return token;
    });
    expect(result, 'new');
  });

  test('a token the server can no longer verify is renewed too', () async {
    var first = true;
    final result = await appState.withFreshToken((token) async {
      if (first) {
        first = false;
        throw const NetException('x', code: 'PGRST301');
      }
      return token;
    });
    expect(result, 'new');
  });

  test('renews only once: a second refusal is passed on', () async {
    await expectLater(
      appState.withFreshToken<void>((_) async => throw _expired),
      throwsA(isA<NetException>()),
    );
    expect(renewals, 1);
  });

  test('any other failure is passed on, without renewing', () async {
    await expectLater(
      appState.withFreshToken<void>(
          (_) async => throw const NetException('x', technicalDetail: 'boom')),
      throwsA(isA<NetException>()),
    );
    expect(renewals, 0);
  });

  test('signed out, it refuses rather than sending no token', () async {
    appState.debugSetTokens(null, null);
    await expectLater(
        appState.withFreshToken(request), throwsA(isA<NetException>()));
  });
}
