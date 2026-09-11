import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/hijri_date.dart';

void main() {
  test('renders the Persian month name for a given month number', () {
    const h = HijriToday(day: 29, monthNumber: 3, year: 1448);
    expect(h.monthNameFa, 'ربیع‌الاول');
  });

  test('renders day/month/year as Persian digits in the expected label form',
      () {
    const h = HijriToday(day: 29, monthNumber: 3, year: 1448);
    expect(h.label, '۲۹ ربیع‌الاول ۱۴۴۸');
  });

  test('handles a single-digit day correctly', () {
    const h = HijriToday(day: 1, monthNumber: 9, year: 1448);
    expect(h.label, '۱ رمضان ۱۴۴۸');
  });

  test('the last month (Dhul-Hijjah) maps correctly', () {
    const h = HijriToday(day: 10, monthNumber: 12, year: 1447);
    expect(h.monthNameFa, 'ذی‌الحجه');
  });
}
