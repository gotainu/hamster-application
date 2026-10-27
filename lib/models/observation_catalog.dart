/// Item definitions live only in shared/observation_catalog.json.
/// Regenerate the bindings with tool/generate_observation_catalog.py.
library;

part 'observation_catalog.generated.dart';

class ObservationCatalogItem {
  const ObservationCatalogItem({
    required this.id,
    required this.label,
    required this.order,
    required this.active,
    required this.insightEligible,
    required this.defaultNormal,
    required this.aliases,
    required this.legacyNames,
  });

  final String id;
  final String label;
  final int order;
  final bool active;
  final bool insightEligible;
  final bool defaultNormal;
  final List<String> aliases;
  final List<String> legacyNames;
}

ObservationCatalogItem? observationItem(
  String value, {
  List<ObservationCatalogItem> catalog = observationCatalog,
}) {
  for (final item in catalog) {
    if (item.id == value ||
        item.label == value ||
        item.aliases.contains(value) ||
        item.legacyNames.contains(value)) {
      return item;
    }
  }
  return null;
}

String? resolveObservationId(
  String value, {
  List<ObservationCatalogItem> catalog = observationCatalog,
}) =>
    observationItem(value, catalog: catalog)?.id;

String observationLabel(
  String value, {
  List<ObservationCatalogItem> catalog = observationCatalog,
}) =>
    observationItem(value, catalog: catalog)?.label ?? value;

List<ObservationCatalogItem> activeObservationItems({
  List<ObservationCatalogItem> catalog = observationCatalog,
}) {
  final items = catalog.where((item) => item.active).toList();
  items.sort((a, b) {
    final ordered = a.order.compareTo(b.order);
    return ordered != 0 ? ordered : a.id.compareTo(b.id);
  });
  return List.unmodifiable(items);
}

/// Unknown and retired IDs remain readable; aliases are counted only once.
List<String> normalizeObservationIds(
  Iterable<String> values, {
  List<ObservationCatalogItem> catalog = observationCatalog,
}) =>
    {
      for (final value in values)
        resolveObservationId(value, catalog: catalog) ?? value
    }.toList();
