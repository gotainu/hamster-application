import {addDaysToDateKey, formatDateKey, isDateKey} from '../../../functions/src/health/dateKey';
import {CanonicalPredictionPoint, Instant, PredictionAnchor, PredictionPoint, TimeEvidence} from './types';

/** UTC nanoseconds; explicit offsets are required and no machine timezone is consulted. */
export function epochNanos(value:Instant):bigint {
  const m=/^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if(!m || !isDateKey(m[1]) || +m[2]>23 || +m[3]>59 || +m[4]>59) throw new Error('invalid_explicit_timestamp');
  if(m[6]!=='Z' && (+m[6].slice(1,3)>23 || +m[6].slice(4)>59)) throw new Error('invalid_timestamp_offset');
  const ms=Date.parse(`${m[1]}T${m[2]}:${m[3]}:${m[4]}${m[6]}`);
  if(!Number.isFinite(ms)) throw new Error('invalid_timestamp');
  return BigInt(ms)*1000000n + BigInt((m[5]??'').padEnd(9,'0'));
}
export function normalizeInstant(value:Instant):Instant {
  const n=epochNanos(value); let seconds=n/1000000000n; let fraction=n%1000000000n;
  if(fraction<0){seconds--;fraction+=1000000000n;}
  return new Date(Number(seconds*1000n)).toISOString().slice(0,19)+'.'+fraction.toString().padStart(9,'0')+'Z';
}
export function compareInstants(a:Instant,b:Instant):number {const x=epochNanos(a),y=epochNanos(b);return x<y?-1:x>y?1:0;}
export function predictionPoint(anchor:PredictionAnchor):PredictionPoint {
  if(!isDateKey(anchor.referenceDateKey)) throw new Error('invalid_reference_day');
  return {...anchor,t0:normalizeInstant(`${anchor.referenceDateKey}T09:00:00+09:00`),t1:normalizeInstant(`${addDaysToDateKey(anchor.referenceDateKey,1)}T09:00:00+09:00`)};
}
export function timingInWindow(timing:TimeEvidence,t0:Instant,t1:Instant):boolean {
  if(timing.precision==='instant') return compareInstants(timing.at,t0)>0 && compareInstants(timing.at,t1)<=0;
  if(timing.precision==='interval') return compareInstants(timing.start,timing.end)<=0 && compareInstants(timing.start,t0)>0 && compareInstants(timing.end,t1)<=0;
  return false;
}

/** Explicit (T0,T1] window adapter; reference day supports existing date-only evidence semantics only. */
export function canonicalPredictionPoint(point:CanonicalPredictionPoint,timeZone:'Asia/Tokyo'):PredictionPoint {
  const t0=normalizeInstant(point.t0), t1=normalizeInstant(point.t1);
  if(compareInstants(t0,t1)>=0) throw new Error('invalid_prediction_window');
  normalizeInstant(point.labelFinalizedAt); normalizeInstant(point.dataAvailableThrough);
  if(compareInstants(point.labelFinalizedAt,t1)<0) throw new Error('L_before_T1');
  const referenceDateKey=formatDateKey(new Date(Number(epochNanos(t0)/1000000n)),timeZone);
  return {id:point.id,ownerId:point.ownerId,subjectId:point.subjectId,referenceDateKey,t0,t1};
}
