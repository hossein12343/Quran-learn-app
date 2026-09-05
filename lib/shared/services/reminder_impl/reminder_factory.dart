import '../reminders.dart';
import 'reminder_factory_stub.dart'
    if (dart.library.html) 'reminder_factory_web.dart' as impl;

ReminderService createReminderService() => impl.makeReminderService();
