/** Item definitions live only in shared/observation_catalog.json. */
import {generatedObservationCatalog, OBSERVATION_CATALOG_VERSION} from './observationCatalog.generated';

export {OBSERVATION_CATALOG_VERSION};
export interface ObservationCatalogItem {
  readonly id: string;
  readonly label: string;
  readonly order: number;
  readonly active: boolean;
  readonly insightEligible: boolean;
  readonly defaultNormal: boolean;
  readonly aliases: readonly string[];
  readonly legacyNames: readonly string[];
}

export const observationCatalog = generatedObservationCatalog;

export function resolveObservationId(
  value: string,
  catalog: readonly ObservationCatalogItem[] = observationCatalog,
): string | null {
  return catalog.find(item => item.id === value || item.label === value ||
    item.aliases.includes(value) || item.legacyNames.includes(value))?.id ?? null;
}

export function observationLabel(
  value: string,
  catalog: readonly ObservationCatalogItem[] = observationCatalog,
): string {
  const id = resolveObservationId(value, catalog);
  return catalog.find(item => item.id === id)?.label ?? value;
}

export function activeObservationItems(
  catalog: readonly ObservationCatalogItem[] = observationCatalog,
): readonly ObservationCatalogItem[] {
  return catalog.filter(item => item.active)
    .sort((a, b) => a.order - b.order || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}
