# Cloud Run RAG authorization contract

The implemented source is `/Users/gota/docker/hamster_rag_server`. The public
`POST /chat` route in `app/main.py` verifies a Firebase ID token first, then
passes only that verified UID to `app/chat_service.py`. The client body has no
UID field and cannot authorize another account.

`execute_chat` enforces the following before `search_and_generate_with_context`
can call the OpenAI client:

1. Validate a client-generated `request_id` and hash the exact query/history.
2. In one Firestore transaction, inspect the verified user's paid subscription
   or fixed free-trial end/limits, create a `reserved` usage document, and
   atomically reserve one finite free request/cost allowance when applicable.
3. Mark the request `started`, invoke RAG once, then persist a replayable
   `succeeded` response. A same-UID/same-body retry returns that response
   without a second model call. Different content for the same ID is rejected.
4. On provider/transport failure, mark `unknown`; a retry is rejected instead
   of silently generating again. It must be resolved operationally.

The reservation path is under the verified user in
`users/{uid}/feature_access/initial_trial_v2/ai_usage/{request_id}`. It is
server-owned; Flutter no longer consumes this quota before calling RAG.
Analytics never authorizes this route.

## Current model and bounds

`app/rag_logic.py` uses `gpt-4o-mini` for generation and can perform a second
grounding pass. User query is capped at 1,500 characters, each history message
at 1,200 characters (at most 12), retrieved context at five chunks of 3,000
characters, and each model pass at `RAG_MAX_OUTPUT_TOKENS` (default 700,
code-bounded to 64–2,000). These are request bounds, not measured billing.

## Required deployment configuration before enabling it

The current local policy deliberately has zero AI requests and zero cost
micros, which rejects new general-user trials. Before production enablement,
approve and deploy finite values for the Functions trial policy and matching
Cloud Run `AI_RESERVATION_COST_MICROS`; they must be calculated from the chosen
model price and both possible generation passes. The Cloud Run service account
needs existing Firestore access to the user's entitlement document and usage
subcollection. No service account, IAM, or Cloud Run environment setting was
changed by this work.

Firebase App Check verification exists, but its default configuration remains
monitor-only (`APP_CHECK_ENFORCE=false`). Firebase ID token verification is
mandatory for `/chat`; turning App Check enforcement on remains a separately
approved release step because it changes live client compatibility.

## Local proof, not production proof

Mock-only tests cover invalid Firebase authentication, expired/unconfigured
entitlement, exhausted final slot under concurrent requests, replay behavior,
request hash mismatch, and unknown timeout handling. They do not prove the
deployed Cloud Run revision, its service account, or Firestore transaction
behavior against a real emulator/project.
