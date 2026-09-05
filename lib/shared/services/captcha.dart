/// Cloudflare Turnstile — a free, privacy-respecting CAPTCHA — added to
/// signup (required) and login (best-effort) after a real penetration
/// test this session found brute-force login protection to be a loose
/// request-rate throttle (~45-50 guesses before Supabase's own limiter
/// kicked in), not a tight per-account lockout. A CAPTCHA raises the
/// cost of scripted signup/login abuse well above what a rate limit
/// alone does.
///
/// The real site key, from the user's own Turnstile widget (created
/// 2026-09-05, "Managed" mode, hostnames including `localhost`) — safe to
/// ship, that's what a Turnstile *site* key is for (public by design,
/// same footing as the Supabase publishable key). The matching **secret
/// key** is a separate, server-side-only value that goes in Supabase's
/// dashboard (Authentication → Attack Protection → enable CAPTCHA
/// protection) — never in this file, and not the same value as this one.
const String turnstileSiteKey = '0x4AAAAAAEpai6llbWVgpkSm';
