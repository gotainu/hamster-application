/// The shared JSON catalog is the single item-definition source.
library;

part 'care_action_catalog.generated.dart';

class CareActionDetailOption {
  const CareActionDetailOption({required this.id, required this.label});
  final String id;
  final String label;
}

class CareActionDetailCondition {
  const CareActionDetailCondition({required this.key, required this.values});
  final String key;
  final List<String> values;
}

class CareActionDetail {
  const CareActionDetail(
      {required this.type,
      required this.key,
      required this.label,
      this.unit,
      this.meaning,
      this.values = const [],
      this.min,
      this.max,
      this.legacy = false,
      this.onlyWhen});
  final String type;
  final String key;
  final String label;
  final String? unit;
  final String? meaning;
  final List<CareActionDetailOption> values;
  final num? min;
  final num? max;
  final bool legacy;
  final CareActionDetailCondition? onlyWhen;

  bool isApplicable(Map<String, Object?> values) =>
      onlyWhen == null || onlyWhen!.values.contains(values[onlyWhen!.key]);
}

class CareActionCatalogItem {
  const CareActionCatalogItem(
      {required this.id,
      required this.label,
      required this.order,
      required this.active,
      required this.inputType,
      this.aliases = const [],
      this.legacyNames = const [],
      this.detail,
      this.details = const []});
  final String id;
  final String label;
  final int order;
  final bool active;
  final String inputType;
  final List<String> aliases;
  final List<String> legacyNames;
  final CareActionDetail? detail;
  final List<CareActionDetail> details;

  List<CareActionDetail> get detailDefinitions =>
      List.unmodifiable([if (detail != null) detail!, ...details]);
}

List<CareActionCatalogItem> activeCareActionItems(
    {List<CareActionCatalogItem> catalog = careActionCatalog}) {
  final items = catalog.where((item) => item.active).toList();
  items.sort((a, b) =>
      a.order == b.order ? a.id.compareTo(b.id) : a.order.compareTo(b.order));
  return List.unmodifiable(items);
}

CareActionCatalogItem? careActionItem(String id,
    {List<CareActionCatalogItem> catalog = careActionCatalog}) {
  for (final item in catalog) {
    if (item.id == id ||
        item.aliases.contains(id) ||
        item.legacyNames.contains(id)) {
      return item;
    }
  }
  return null;
}
