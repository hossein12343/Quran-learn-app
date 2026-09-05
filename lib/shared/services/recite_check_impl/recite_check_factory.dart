import '../recite_check.dart';
import 'recite_check_factory_stub.dart'
    if (dart.library.html) 'recite_check_factory_web.dart' as impl;

/// Real microphone capture + grading on web via the browser's own Speech
/// Recognition API (zero pub.dev packages, see `recite_check.dart`); the
/// unavailable stub everywhere else.
ReciteGrader createReciteGrader() => impl.makeReciteGrader();
