import 'dart:math' as math;

/// Display formatters. Every number the user reads passes through here so
/// formats stay consistent between the live timer, the stats screen and the
/// share card.
abstract final class Fmt {
  /// `39:46` — hours only when it doesn't fit the layout budget.
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Big countdown form used on the timer face — `1:30`, or `0:08`.
  static String countdown(Duration d) {
    final total = math.max(0, d.inSeconds);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// `5:52` pace per km. Null when there's not enough distance yet.
  static String? pace(double? secPerKm) {
    if (secPerKm == null || secPerKm <= 0 || secPerKm > 3600 * 2) return null;
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// `6.8` — one decimal below 10km, whole numbers above.
  static String km(double v, {int decimals = -1}) {
    final d = decimals >= 0 ? decimals : (v < 10 ? 1 : 0);
    return v.toStringAsFixed(d);
  }

  static String distanceLabel(double v) => '${km(v)} km';

  static const List<String> monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// `Sat 3 Oct`
  static String date(DateTime d) => '${weekdayShort[d.weekday - 1]} ${d.day} ${monthShort[d.month - 1]}';

  /// `3 Oct, 7:12 pm`
  static String dateTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${monthShort[d.month - 1]}, $h:$m ${d.hour < 12 ? 'am' : 'pm'}';
  }

  /// ISO week-of-year, used for the stats screen's `week N of 15` header.
  static int weekOfYear(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    final firstDay = DateTime(d.year, 1, 1);
    final days = date.difference(firstDay).inDays;
    return (days / 7).floor() + 1;
  }
}
