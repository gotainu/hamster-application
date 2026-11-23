/** Deliberate copy changes only; never derives identity, access or price from DOM. */
export function configureLiveBillingPage() {
  document.documentElement.dataset.environment='live';
  document.title='HamCare｜アカウント・契約の確認';
  for (const node of document.querySelectorAll('[data-live-copy]')) node.textContent=node.dataset.liveCopy;
  const text=(id,value)=>{const node=document.getElementById(id);if(node)node.textContent=value;};
  text('billing-environment-notice','新規の有料申込・一般向け確認メール送信は現在停止しています。現在の契約は確認・管理できます。');
  text('billing-environment-footer','© 2026 HamCare');
  text('confirm-title','HamCareアカウントと契約を確認');
  text('plan-checkout','新規の有料申込は現在停止しています');
  text('checkout-cancel','支払い操作をキャンセルする');
  for (const prefix of ['account-preview','plan-preview','checkout-preview']) {
    text(prefix+'-title','サーバーに保存された契約状態');
    text(prefix+'-status','契約状態はまだ確認していません。');
    text(prefix+'-refresh','契約状態を再確認する');
    const detail=document.getElementById(prefix+'-details');
    if (detail) for(const node of detail.querySelectorAll('dt')) {
      if(node.textContent==='Preview契約状態')node.textContent='現在の契約状態';
      if(node.textContent==='サーバーのPreview権限保存状態')node.textContent='アプリの利用状態';
    }
  }
  for(const node of document.querySelectorAll('dt'))if(node.textContent==='月額料金（Preview）')node.textContent='月額料金';
  for(const node of document.querySelectorAll('#checkout-panel > .eyebrow,#plan-panel .plan-heading > .eyebrow'))node.textContent='HAMCARE PREMIUM';
}
export function configurePreviewBillingPage() {
  document.documentElement.dataset.environment='preview';
  document.getElementById('billing-environment-notice').textContent='PREVIEW：Stripe Test Mode専用です。実際の請求・アプリの権限変更は行いません。';
  document.getElementById('billing-environment-footer').textContent='© 2026 HamCare · Preview';
}
