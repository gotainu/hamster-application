import * as admin from 'firebase-admin';
import {createHash} from 'node:crypto';
import * as https from 'node:https';
import {URL} from 'node:url';
import {onDocumentCreated, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {isValidationUid} from './validationIdentity';

const REGION = 'asia-northeast1';
const TABLE = 'server_events_raw';
const INGEST_SERVICE_ACCOUNT =
  'hamcare-bq-ingest@hamster-breeding-app.iam.gserviceaccount.com';

type JsonValue = string | number | boolean | null;
type ServerEventRow = Record<string, JsonValue>;

function asDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (value && typeof value === 'object' && 'toDate' in value) {
    const toDate = (value as {toDate?: () => Date}).toDate;
    if (typeof toDate === 'function') return toDate.call(value);
  }
  if (typeof value === 'number') return new Date(value);
  if (typeof value === 'string') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  return null;
}

function iso(value: unknown): string | null {
  return asDate(value)?.toISOString() ?? null;
}

function projectId(): string {
  const project = process.env.GOOGLE_CLOUD_PROJECT ??
    process.env.GCLOUD_PROJECT ?? admin.app().options.projectId;
  if (!project) throw new Error('BigQuery project is not configured.');
  return project;
}

function requestJson(url: string, accessToken: string, body: unknown): Promise<any> {
  return new Promise((resolve, reject) => {
    const request = https.request(new URL(url), {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    }, (response) => {
      let content = '';
      response.setEncoding('utf8');
      response.on('data', (chunk: string) => { content += chunk; });
      response.on('end', () => {
        let parsed: any = {};
        try { parsed = content ? JSON.parse(content) : {}; } catch { /* sanitized below */ }
        if ((response.statusCode ?? 500) < 200 || (response.statusCode ?? 500) >= 300) {
          reject(new Error(`BigQuery insert failed with HTTP ${response.statusCode ?? 500}.`));
          return;
        }
        if (Array.isArray(parsed.insertErrors) && parsed.insertErrors.length > 0) {
          reject(new Error('BigQuery rejected one or more server metadata rows.'));
          return;
        }
        resolve(parsed);
      });
    });
    request.on('error', () => reject(new Error('BigQuery metadata transport failed.')));
    request.end(JSON.stringify(body));
  });
}

function serverEventRow(params: {
  uid: string;
  sourceCollection: 'journey_events' | 'analysis_events';
  eventId: string;
  data: FirebaseFirestore.DocumentData;
}): ServerEventRow {
  const data = params.data;
  return {
    source_event_id: `${params.uid}:${params.sourceCollection}:${params.eventId}`,
    source_collection: params.sourceCollection,
    user_id: params.uid,
    event_name: String(data.eventName ?? 'unknown'),
    event_at: iso(data.occurredAt ?? data.startedAt ?? data.serverReceivedAt ?? data.createdAt),
    ingested_at: new Date().toISOString(),
    trial_id: typeof data.trialId === 'string' ? data.trialId : null,
    policy_version: typeof data.policyVersion === 'string' ? data.policyVersion : null,
    trial_ends_at: iso(data.trialEndsAt ?? data.endsAt),
    actor: typeof data.actor === 'string' ? data.actor : null,
    source: typeof data.source === 'string' ? data.source : null,
    test_only: data.testOnly === true,
    request_id: typeof data.requestId === 'string' ? data.requestId : null,
    reservation_micros: typeof data.reservedCostMicros === 'number' ? data.reservedCostMicros : null,
    record_type: typeof data.recordType === 'string' ? data.recordType : null,
    record_source: typeof data.source === 'string' ? data.source : null,
    observation_at: typeof data.observationAt === 'string' ? data.observationAt : iso(data.observationAt),
    server_received_at: iso(data.serverReceivedAt),
    metric: typeof data.metric === 'string' ? data.metric : null,
    previous_status: typeof data.previousStatus === 'string' ? data.previousStatus : null,
    current_status: typeof data.currentStatus === 'string' ? data.currentStatus : null,
    analysis_spec_version: typeof data.analysisSpecVersion === 'string' ? data.analysisSpecVersion : null,
    pet_id: typeof data.petId === 'string' ? data.petId : null,
    report_id: typeof data.reportId === 'string' ? data.reportId : null,
    report_revision: typeof data.reportRevision === 'number' ? data.reportRevision : null,
    report_join_key: typeof data.reportJoinKey === 'string' ? data.reportJoinKey : null,
    readiness_metrics: Array.isArray(data.readyMetrics) ? data.readyMetrics.join(',') : null,
  };
}

function providerCallRow(params: {
  uid: string;
  requestId: string;
  callId: string;
  data: FirebaseFirestore.DocumentData;
}): ServerEventRow {
  const data = params.data;
  return {
    source_event_id: `${params.uid}:ai_provider_call:${params.requestId}:${params.callId}`,
    source_collection: 'ai_provider_calls',
    user_id: params.uid,
    event_name: 'ai_provider_call_usage',
    event_at: iso(data.completedAt ?? data.startedAt),
    ingested_at: new Date().toISOString(),
    trial_id: null,
    policy_version: null,
    trial_ends_at: null,
    actor: 'server_rag_api',
    source: typeof data.api === 'string' ? data.api : null,
    test_only: data.testOnly === true,
    request_id: params.requestId,
    call_id: params.callId,
    call_type: typeof data.callType === 'string' ? data.callType : null,
    api: typeof data.api === 'string' ? data.api : null,
    requested_model: typeof data.requestedModel === 'string' ? data.requestedModel : null,
    returned_model: typeof data.returnedModel === 'string' ? data.returnedModel : null,
    provider_response_id: typeof data.providerResponseId === 'string' ? data.providerResponseId : null,
    status: typeof data.status === 'string' ? data.status : null,
    usage_status: typeof data.usageStatus === 'string' ? data.usageStatus : null,
    input_tokens: typeof data.inputTokens === 'number' ? data.inputTokens : null,
    output_tokens: typeof data.outputTokens === 'number' ? data.outputTokens : null,
    total_tokens: typeof data.totalTokens === 'number' ? data.totalTokens : null,
    cached_input_tokens: typeof data.cachedInputTokens === 'number' ? data.cachedInputTokens : null,
    estimated_cost_micros: typeof data.estimatedCostMicros === 'number' ? data.estimatedCostMicros : null,
    cost_estimate_status: typeof data.costEstimateStatus === 'string' ? data.costEstimateStatus : null,
    price_version: typeof data.priceVersion === 'string' ? data.priceVersion : null,
  };
}

async function insertServerEvent(sourceEventId: string, row: ServerEventRow): Promise<void> {
  const dataset = (process.env.SERVER_EVENTS_BQ_DATASET ?? 'hamcare_trial_analytics').trim();
  if (!dataset) throw new Error('Server-event BigQuery dataset is not configured.');
  const app = admin.app();
  const credential = app.options.credential;
  if (!credential) throw new Error('BigQuery service credential is unavailable.');
  const {access_token: accessToken} = await credential.getAccessToken();
  if (!accessToken) throw new Error('BigQuery access token is unavailable.');
  const id = createHash('sha256').update(sourceEventId).digest('hex');
  const url = `https://bigquery.googleapis.com/bigquery/v2/projects/${encodeURIComponent(projectId())}/datasets/${encodeURIComponent(dataset)}/tables/${TABLE}/insertAll`;
  await requestJson(url, accessToken, {
    rows: [{insertId: id, json: row}],
    skipInvalidRows: false,
    ignoreUnknownValues: false,
  });
}

export const ingestJourneyEventToBigQuery = onDocumentCreated(
  {document: 'users/{uid}/journey_events/{eventId}', region: REGION, retry: true, maxInstances: 1, timeoutSeconds: 60, serviceAccount: INGEST_SERVICE_ACCOUNT},
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const uid = event.params.uid;
    if (!isValidationUid(uid) || data.testOnly !== true) return;
    const eventId = event.params.eventId;
    const row = serverEventRow({uid, eventId, sourceCollection: 'journey_events', data});
    await insertServerEvent(row.source_event_id as string, row);
  },
);

export const ingestAnalysisEventToBigQuery = onDocumentCreated(
  {document: 'users/{uid}/analysis_events/{eventId}', region: REGION, retry: true, maxInstances: 1, timeoutSeconds: 60, serviceAccount: INGEST_SERVICE_ACCOUNT},
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const uid = event.params.uid;
    if (!isValidationUid(uid) || data.testOnly !== true) return;
    const eventId = event.params.eventId;
    const row = serverEventRow({uid, eventId, sourceCollection: 'analysis_events', data});
    await insertServerEvent(row.source_event_id as string, row);
  },
);

export const ingestAiProviderUsageToBigQuery = onDocumentUpdated(
  {document: 'users/{uid}/feature_access/initial_trial_v2/ai_usage/{requestId}/api_calls/{callId}', region: REGION, retry: true, maxInstances: 1, timeoutSeconds: 60, serviceAccount: INGEST_SERVICE_ACCOUNT},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || !['succeeded', 'failed', 'unknown'].includes(String(after.status))) return;
    if (!isValidationUid(event.params.uid) || after.testOnly !== true) return;
    if (before && before.status === after.status && before.completedAt) return;
    const uid = event.params.uid;
    const requestId = event.params.requestId;
    const callId = event.params.callId;
    const row = providerCallRow({uid, requestId, callId, data: after});
    await insertServerEvent(row.source_event_id as string, row);
  },
);
