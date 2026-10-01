String formatBrazilianNumber(num value, {int decimalDigits = 1}) {
  final fixed = value.toStringAsFixed(decimalDigits);
  final parts = fixed.split('.');
  final rawInteger = parts.first;
  final negative = rawInteger.startsWith('-');
  final digits = negative ? rawInteger.substring(1) : rawInteger;
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, digits.substring(start, end));
  }
  final integer = groups.join('.');
  final sign = negative ? '-' : '';
  if (decimalDigits == 0) return '$sign$integer';
  return '$sign$integer,${parts[1]}';
}
