/// Free/Pro plan gating.
///
/// `AppState.isPro` mirrors `profiles.is_pro` in Supabase (see the
/// `add_profiles_is_pro` migration) — plain data, not proof of a real
/// purchase. **No payment processor is wired up yet.** [ProPage] shows the
/// comparison and an honest "not set up yet" message on its call to
/// action rather than pretending to charge anyone; today the only way an
/// account becomes Pro is someone with database access flipping that
/// column by hand. Every gate in the app (hearts, reciters) is written
/// against `isPro` alone, so wiring up a real payment provider later is a
/// matter of setting that column correctly from a webhook — nothing that
/// reads it needs to change.
class ProPerk {
  final String title;
  final String description;
  const ProPerk(this.title, this.description);
}

const List<ProPerk> proPerks = <ProPerk>[
  ProPerk('قلب نامحدود', 'یک اشتباه دیگر جلسه را متوقف نمی‌کند — هر چقدر لازم است تمرین کنید.'),
  ProPerk('همهٔ قاریان', 'صدای عبدالباسط عبدالصمد و عبدالرحمن السدیس هم باز می‌شود.'),
  ProPerk('بدون تبلیغات', 'در نسخهٔ رایگان فعلاً تبلیغی نیست — این برای وقتی است که اضافه شود.'),
];
