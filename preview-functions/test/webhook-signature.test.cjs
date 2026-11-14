const test=require('node:test');const assert=require('node:assert/strict');
const Stripe=require('stripe');const stripe=new Stripe('sk_test_synthetic_signature_only');
const {verifyPreviewEvent}=require('../lib/preview-functions/src/webhook-verification');
const secret='whsec_synthetic_test_only';const base={id:'evt_synthetic',object:'event',type:'invoice.paid',livemode:false,created:Math.floor(Date.now()/1000),data:{object:{}}};
function signed(value=base,timestamp=Math.floor(Date.now()/1000)){const payload=JSON.stringify(value);return {raw:Buffer.from(payload),header:stripe.webhooks.generateTestHeaderString({payload,secret,timestamp})};}
test('valid signature verifies original raw bytes',()=>{const s=signed();assert.equal(verifyPreviewEvent(stripe,s.raw,s.header,secret).id,base.id);});
test('missing or wrong signature rejects',()=>{const s=signed();for(const h of [null,'invalid',s.header.replace(/v1=./,'v1=f')+'x'])assert.throws(()=>verifyPreviewEvent(stripe,s.raw,h,secret));});
test('old and future timestamps reject',()=>{for(const delta of [-301,301]){const s=signed(base,Math.floor(Date.now()/1000)+delta);assert.throws(()=>verifyPreviewEvent(stripe,s.raw,s.header,secret));}});
test('parsed or altered bodies reject',()=>{const s=signed();assert.throws(()=>verifyPreviewEvent(stripe,base,s.header,secret));assert.throws(()=>verifyPreviewEvent(stripe,Buffer.from(s.raw.toString()+' '),s.header,secret));});
test('correctly signed Live event rejects',()=>{const s=signed({...base,livemode:true});assert.throws(()=>verifyPreviewEvent(stripe,s.raw,s.header,secret),e=>e.code==='event_not_allowed');});
test('unregistered event rejects',()=>{const s=signed({...base,type:'charge.refunded'});assert.throws(()=>verifyPreviewEvent(stripe,s.raw,s.header,secret),e=>e.code==='event_not_allowed');});
test('all six registered event types pass verification only',()=>{for(const type of ['checkout.session.completed','customer.subscription.created','customer.subscription.updated','customer.subscription.deleted','invoice.paid','invoice.payment_failed']){const s=signed({...base,type});assert.equal(verifyPreviewEvent(stripe,s.raw,s.header,secret).type,type);}});
