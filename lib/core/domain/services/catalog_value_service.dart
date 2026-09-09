/// Pure rules for normalizing and comparing catalog values.
///
/// Keeping these rules outside ChangeNotifier classes prevents subtle
/// differences between product, catalog and distributor management.
class CatalogValueService {
  const CatalogValueService();

  String normalizeName(String value) => value.trim();

  bool containsIgnoreCase(Iterable<String> values, String value) {
    final normalized = normalizeName(value).toLowerCase();
    return values.any((item) => normalizeName(item).toLowerCase() == normalized);
  }

  List<String> uniqueSorted(Iterable<String> values) {
    final result = <String>[];
    for (final value in values) {
      final normalized = normalizeName(value);
      if (normalized.isEmpty || containsIgnoreCase(result, normalized)) continue;
      result.add(normalized);
    }
    result.sort(compare);
    return List.unmodifiable(result);
  }

  int compare(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  List<int> normalizeWeekdays(Iterable<int> weekdays) {
    final result = weekdays.where((day) => day >= 0 && day <= 6).toSet().toList()
      ..sort();
    return List.unmodifiable(result);
  }
}
