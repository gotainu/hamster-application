import {createHash} from 'node:crypto';
import {CHECKIN_INSIGHT_SPEC_VERSION, type CheckinInsights} from './checkinInsights';

/** Publication identity is intentionally separate from the full Evidence hash.
 * These are delivery stages, never medical thresholds or inferred frequency. */
export const CHECKIN_PUBLICATION_SPEC_VERSION = 'checkin_publication_v1';
export interface CheckinPublicationCandidate {
  schemaVersion: 1;
  publicationSpecVersion: typeof CHECKIN_PUBLICATION_SPEC_VERSION;
  evaluationDateKey: string | null;
  windowEndDateKey: string | null;
  materialityKeys: string[];
  coveredMaterialityKeys: string[];
  semanticSignature: string | null;
}
export interface CheckinPublicationState {
  schemaVersion: 1;
  publicationSpecVersion: typeof CHECKIN_PUBLICATION_SPEC_VERSION;
  seenMaterialityKeys: string[];
}
const hash = (value: string) => createHash('sha256').update(value).digest('hex');
const continuityKey = hash(`${CHECKIN_PUBLICATION_SPEC_VERSION}:continuity:first_seven_days`);
const validKeys = (value: unknown): string[] => Array.isArray(value)
  ? [...new Set(value.filter((key): key is string => typeof key === 'string' && /^[a-f0-9]{64}$/.test(key)))].sort() : [];
const stage = (count: number) => count >= 11 ? '11_to_14' : count >= 7 ? '7_to_10' : 'initial';

export function checkinPublicationCandidate(value: CheckinInsights | null | undefined): CheckinPublicationCandidate {
  const keys: string[] = [];
  const covered: string[] = [];
  if (value?.schemaVersion === 1 && value.calculationSpecVersion === CHECKIN_INSIGHT_SPEC_VERSION) {
    for (const insight of Array.isArray(value.insights) ? value.insights : []) {
      const count = insight.evidence?.matchingDayCount;
      if (insight.eligible !== true || insight.metric !== 'condition' || !Number.isInteger(count) || count < 0 || count > 14) continue;
      let meaning: string | null = null;
      if (insight.kind === 'checkin_item_repetition' && count >= 3 && typeof insight.evidence.itemId === 'string' && insight.evidence.itemId.length > 0) {
        meaning = `item:${insight.evidence.itemId}:${stage(count)}`;
        const concerns = insight.evidence.concernDayCount;
        // A is a more specific explanation of these same concern days. Keep
        // covered B separate from visible identity so hidden count changes
        // cannot themselves make A a new publication.
        if (Number.isInteger(concerns) && concerns >= 2 && concerns <= 14) covered.push(hash(`${CHECKIN_PUBLICATION_SPEC_VERSION}:concern:${stage(concerns)}`));
      } else if (insight.kind === 'checkin_concern_frequency' && count >= 2) {
        meaning = `concern:${stage(count)}`;
      } else if (insight.kind === 'checkin_record_continuity' && count >= 7) {
        keys.push(continuityKey);
      }
      if (meaning) keys.push(hash(`${CHECKIN_PUBLICATION_SPEC_VERSION}:${meaning}`));
    }
  }
  const materialityKeys = validKeys(keys);
  return {schemaVersion: 1, publicationSpecVersion: CHECKIN_PUBLICATION_SPEC_VERSION,
    evaluationDateKey: value?.evaluationDateKey ?? null, windowEndDateKey: value?.windowEndDateKey ?? null,
    materialityKeys, coveredMaterialityKeys: validKeys(covered), semanticSignature: materialityKeys.length ? hash(JSON.stringify(materialityKeys)) : null};
}

/** Successful publication writes this state; report history is not a migration source. */
export function readCheckinPublicationState(value: unknown): CheckinPublicationState {
  const saved = value && typeof value === 'object' ? value as Partial<CheckinPublicationState> : {};
  return {schemaVersion: 1, publicationSpecVersion: CHECKIN_PUBLICATION_SPEC_VERSION,
    seenMaterialityKeys: saved.schemaVersion === 1 && saved.publicationSpecVersion === CHECKIN_PUBLICATION_SPEC_VERSION ? validKeys(saved.seenMaterialityKeys) : []};
}
export function hasNewCheckinPublication(candidate: CheckinPublicationCandidate, state: CheckinPublicationState): boolean {
  return candidate.materialityKeys.some(key => !state.seenMaterialityKeys.includes(key));
}
export function mergeCheckinPublicationState(state: CheckinPublicationState | null, delivered: CheckinPublicationCandidate): CheckinPublicationState {
  return {schemaVersion: 1, publicationSpecVersion: CHECKIN_PUBLICATION_SPEC_VERSION,
    // A/B already deliver the seven-day observation milestone. Do not issue C
    // later just because a recurring-item/concern pattern disappears.
    seenMaterialityKeys: validKeys([...(state?.seenMaterialityKeys ?? []), ...delivered.materialityKeys, ...validKeys(delivered.coveredMaterialityKeys),
      ...(delivered.materialityKeys.length ? [continuityKey] : [])])};
}
