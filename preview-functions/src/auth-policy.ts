// Preserve Preview's public API while sharing only pure server identity checks.
export {
  BillingAuthenticationError as PreviewAuthenticationError,
  validWebBillingUid as validPreviewUid,
  authorizeWebBillingIdentity as authorizePreviewIdentity,
} from '../../functions/src/webBillingShared';
