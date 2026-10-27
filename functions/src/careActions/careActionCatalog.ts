/** Definitions live only in shared/care_action_catalog.json. */
import {generatedCareActionCatalog, CARE_ACTION_CATALOG_VERSION} from './careActionCatalog.generated';
export {CARE_ACTION_CATALOG_VERSION};
export interface CareActionDetail {
  readonly key: string; readonly label: string; readonly type: 'enum' | 'integer';
  readonly unit?: string | null; readonly meaning?: string; readonly min?: number; readonly max?: number;
  readonly values?: readonly {readonly id: string; readonly label: string}[];
  readonly legacy?: boolean; readonly onlyWhen?: {readonly key: string; readonly values: readonly string[]};
}
export interface CareActionCatalogItem {
  readonly id: string; readonly label: string; readonly order: number; readonly active: boolean;
  readonly inputType: 'tri_state' | 'cleaning_choice' | 'duration_minutes'; readonly aliases: readonly string[]; readonly legacyNames: readonly string[];
  readonly detail?: CareActionDetail; readonly details?: readonly CareActionDetail[];
}
export const careActionCatalog = generatedCareActionCatalog;
export function resolveCareActionId(value: string, catalog: readonly CareActionCatalogItem[] = careActionCatalog): string | null {
  return catalog.find(item => item.id === value || item.label === value || item.aliases.includes(value) || item.legacyNames.includes(value))?.id ?? null;
}
export function activeCareActionItems(catalog: readonly CareActionCatalogItem[] = careActionCatalog): readonly CareActionCatalogItem[] {
  return catalog.filter(item => item.active).sort((a, b) => a.order - b.order || a.id.localeCompare(b.id));
}

/** Legacy detail remains readable; new definitions do not reinterpret its values. */
export function careActionDetailDefinitions(item: CareActionCatalogItem): readonly CareActionDetail[] {
  return [...(item.detail ? [item.detail] : []), ...(item.details ?? [])];
}
