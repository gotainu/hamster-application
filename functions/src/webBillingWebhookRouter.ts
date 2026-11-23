import type Stripe from 'stripe';
import {WebBillingWebhookError, verifyWebBillingEvent} from './webBillingWebhook';

export interface WebBillingWebhookSource {
  stripe: Stripe;
  secret: string;
}
export interface WebBillingWebhookRouterDependencies {
  /** A separate, explicitly bound old endpoint credential, never a fallback
   * for an invalid or missing production Web configuration. */
  legacySource?(): WebBillingWebhookSource;
  legacyEnabled?(): boolean;
  processLegacy?(event: Stripe.Event): Promise<unknown>;
  source(): WebBillingWebhookSource;
  mode(): unknown;
  enabled(): boolean;
  process(event: Stripe.Event): Promise<unknown>;
  now(): Date;
}

/** One HTTP URL can keep the old endpoint working while a distinct new signing
 * secret is verified. Route only on a verified HMAC; payload metadata, query
 * parameters and client-provided IDs never choose the execution path.
 * A verification-only event remains retryable, without consuming a DB receipt. */
export function createWebBillingWebhookRouter(d: WebBillingWebhookRouterDependencies) {
  return {
    async handle(raw: Buffer, signature: unknown): Promise<unknown> {
      const old = d.legacySource?.();
      if (old) {
        let event: Stripe.Event | undefined;
        try {event = verifyWebBillingEvent(old.stripe, raw, signature, old.secret, d.now);}
        catch (error) {
          // Only an HMAC mismatch may try the other endpoint credential. A
          // correctly signed Test event is not a new-endpoint Live event.
          if (!(error instanceof WebBillingWebhookError) || error.code !== 'signature_invalid') throw error;
        }
        if (event) {
          if (d.legacyEnabled?.() !== true || typeof d.processLegacy !== 'function') {
            throw new WebBillingWebhookError('processing_paused', true);
          }
          return d.processLegacy(event);
        }
      }
      const current = d.source();
      if (old && old.secret === current.secret) throw new WebBillingWebhookError('configuration_invalid', true);
      const event = verifyWebBillingEvent(current.stripe, raw, signature, current.secret, d.now);
      const mode = d.mode();
      if (mode === 'verify_only') throw new WebBillingWebhookError('verification_only', true);
      if (mode !== 'process' || d.enabled() !== true) throw new WebBillingWebhookError('processing_paused', true);
      return d.process(event);
    },
  };
}
