'use strict';
// Synthetic OAuth responses and captured MIME only. No credential lookup,
// Gmail client, actual mail delivery or Firebase/Stripe connection is opened.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {loadStarSource}=require('./support/star_source_loader.cjs');
const {parseBillingNotificationMailConfig:parse,createBillingNotificationGmailSender:createSender,
  buildBillingNotificationMime:buildMime,BillingNotificationMailError:MailError,BILLING_NOTIFICATION_FROM:FROM}=loadStarSource()('billingNotificationGmail');
const hash=v=>createHash('sha256').update(v).digest('hex');
const UID='synthetic-billing-mail-owner',TO='synthetic@example.test',NOW=new Date('2030-01-01T00:00:00Z');
const cfg=(extra={})=>({enabled:true,environment:'preview',from:FROM,clientId:'synthetic-billing.apps.googleusercontent.com',
  clientSecret:'synthetic-client-secret',refreshToken:'synthetic-refresh-token-long',allowedSubjectHashes:[hash(UID)],allowedRecipientHashes:[hash(TO)],...extra});
const message=(extra={})=>({notificationId:'synthetic-notification-001',uid:UID,to:TO,
  subject:'【HamCare】お支払いを確認しました',text:'お支払いを確認しました。月額550円\n契約管理はWebからご確認ください。',
  html:'<!doctype html><html><body><p>お支払いを確認しました。月額550円</p></body></html>',...extra});
const response=(status=200,body={},headers={})=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json',...headers}});
function fixture({oauth=()=>response(200,{access_token:'synthetic-access-token',token_type:'Bearer',scope:'https://www.googleapis.com/auth/gmail.send'}),send=()=>response(200,{id:'syntheticMessage001'})}={}) {
  const calls=[];
  const sender=createSender(parse(cfg(),'preview'),{now:()=>NOW,fetchRequest:async(url,options)=>{
    calls.push({url,options});return String(url).includes('/token')?oauth(calls):send(calls);
  }});
  return {calls,sender};
}
async function rejected(fn,category,delivery='not_sent',retryable=false) {
  let error;try{await fn();}catch(e){error=e;}
  assert.ok(error instanceof MailError);assert.equal(error.category,category);
  assert.equal(error.delivery,delivery);assert.equal(error.retryable,retryable);
  assert.doesNotMatch(String(error)+JSON.stringify(error),/synthetic@|synthetic-refresh-token|synthetic-client-secret|Bearer /);
  return error;
}

test('Preview config reuses only explicit user OAuth fields and immutable two allowlists',()=>{
  const parsed=parse(JSON.stringify(cfg()),'preview');
  assert.equal(parsed.from,FROM);assert.equal(parsed.environment,'preview');
  assert.ok(Object.isFrozen(parsed));assert.ok(Object.isFrozen(parsed.allowedSubjectHashes));assert.ok(Object.isFrozen(parsed.allowedRecipientHashes));
});
test('Live config is explicit and has no implicit Preview allowlist or credential fallback',()=>{
  const {allowedSubjectHashes,allowedRecipientHashes,...live}=cfg({environment:'live'});
  assert.equal(parse(live,'live').environment,'live');
  assert.throws(()=>parse(cfg({environment:'live'}),'live'),MailError);
});
for(const key of ['enabled','environment','from','clientId','clientSecret','refreshToken','allowedSubjectHashes','allowedRecipientHashes'])
  test('missing '+key+' fails closed',()=>{const v=cfg();delete v[key];assert.throws(()=>parse(v,'preview'),MailError);});
for(const value of [undefined,null,'','{bad',[],true])test('invalid configuration '+JSON.stringify(value)+' rejects',()=>assert.throws(()=>parse(value,'preview'),MailError));
for(const extra of [{enabled:false},{environment:'live'},{from:'other@example.test'},{clientId:'service-account@example.test'},
  {clientId:'synthetic.apps.googleusercontent.com.evil.test'},{clientId:' synthetic.apps.googleusercontent.com'},
  {clientSecret:'bad\r\nsecret'},{refreshToken:'bad\nrefresh-value-with-newline'},
  {serviceAccount:'forbidden'},{private_key:'forbidden'},{impersonate:FROM},{subject:FROM},{token:'forbidden'}])
  test('unsafe OAuth config '+Object.keys(extra).join(',')+' rejects',()=>assert.throws(()=>parse(cfg(extra),'preview'),MailError));
for(const key of ['allowedSubjectHashes','allowedRecipientHashes'])for(const value of [[],['bad'],[hash('one'),hash('one')],Array.from({length:6},(_,i)=>hash(String(i))),null])
  test('invalid '+key+' '+JSON.stringify(value).slice(0,30)+' rejects',()=>assert.throws(()=>parse(cfg({[key]:value}),'preview'),MailError));
test('expected environment cannot be invented or copied across modes',()=>{
  assert.throws(()=>parse(cfg(),'live'),MailError);assert.throws(()=>parse(cfg(),'production'),MailError);
});
test('MIME has branded From, reply address, UTF-8 alternatives and no recipient/UID-bearing Message-ID',()=>{
  const mime=buildMime(message(),NOW);
  assert.match(mime,/^From: HamCare <gotainu@gmail\.com>\r\nReply-To: gotainu@gmail\.com\r\nTo: <synthetic@example\.test>\r\n/);
  assert.match(mime,/Date: Tue, 01 Jan 2030 00:00:00 GMT\r\n/);
  assert.match(mime,/Content-Type: multipart\/alternative;/);
  assert.ok(mime.match(/boundary="([^"]+)"/)[1].length<=70,'RFC2046 boundary length');
  assert.match(mime,/Content-Type: text\/plain; charset=UTF-8/);assert.match(mime,/Content-Type: text\/html; charset=UTF-8/);
  const id=mime.match(/Message-ID: (.+)/)[1];assert.doesNotMatch(id,/synthetic|owner|notification|example\.test/);
  assert.equal(id,buildMime(message(),new Date(NOW.getTime()+10000)).match(/Message-ID: (.+)/)[1]);
  assert.notEqual(id,buildMime(message({notificationId:'another-notification'}),NOW).match(/Message-ID: (.+)/)[1]);
});
test('RFC2047 Japanese subject is folded within encoded-word length and round-trips',()=>{
  const subject='【HamCare】お支払いを確認しました。日本語の確認用テキストです。'.repeat(2);
  const mime=buildMime(message({subject}),NOW), header=mime.slice(mime.indexOf('Subject: ')+9,mime.indexOf('\r\nDate:'));
  const words=header.split('\r\n ');assert.ok(words.length>1);
  assert.ok(words.every(word=>word.length<=75));
  assert.equal(words.map(word=>Buffer.from(word.slice(10,-2),'base64').toString('utf8')).join(''),subject);
});
test('both base64 MIME parts round-trip without JS/CSS transformation',()=>{
  const m=message(),mime=buildMime(m,NOW);
  const bodies=[...mime.matchAll(/Content-Transfer-Encoding: base64\r\n\r\n([A-Za-z0-9+/=\r\n]+?)\r\n--/g)];
  assert.equal(bodies.length,2);assert.equal(Buffer.from(bodies[0][1],'base64').toString('utf8'),m.text);
  assert.equal(Buffer.from(bodies[1][1],'base64').toString('utf8'),m.html);
  for(const body of bodies)assert.ok(body[1].split('\r\n').every(line=>line.length<=76));
});
for(const extra of [{subject:'bad\r\nBcc: attacker@example.test'},{subject:'bad\0subject'},{subject:''},{to:'wrong@example.test\nBcc: bad@example.test'},
  {to:'Name <synthetic@example.test>'},{uid:''},{uid:'other/path'},{notificationId:'bad\r\nid'},{text:''},{html:''},{returnUrl:'https://evil.test'}])
  test('invalid mail request '+Object.keys(extra).join(',')+' is rejected before OAuth',async()=>{
    const f=fixture();await assert.rejects(f.sender.send(message(extra)),MailError);assert.equal(f.calls.length,0);
  });
test('oversize body and subject reject before MIME creation',()=>{
  assert.throws(()=>buildMime(message({text:'a'.repeat(100001)}),NOW),MailError);
  assert.throws(()=>buildMime(message({subject:'あ'.repeat(172)}),NOW),MailError);
  assert.throws(()=>buildMime(message(),new Date(NaN)),MailError);
});
for(const extra of [{uid:'other-owned-uid'},{to:'other@example.test'},{uid:'other-owned-uid',to:'other@example.test'}])
  test('Preview allowlist blocks '+Object.keys(extra).join(',')+' before OAuth',async()=>{
    const f=fixture();await rejected(()=>f.sender.send(message(extra)),'recipient_not_allowed');assert.equal(f.calls.length,0);
  });
test('successful send uses refresh grant and exact Gmail account endpoint, returns only a message hash',async()=>{
  const f=fixture(),result=await f.sender.send(message());
  assert.deepEqual(result,{messageIdHash:hash('syntheticMessage001')});assert.equal(f.calls.length,2);
  const [oauth,send]=f.calls;assert.equal(oauth.url,'https://oauth2.googleapis.com/token');
  assert.equal(oauth.options.body.get('grant_type'),'refresh_token');assert.equal(oauth.options.body.get('client_secret'),cfg().clientSecret);
  assert.equal(oauth.options.body.has('assertion'),false);assert.equal(oauth.options.body.has('sub'),false);
  assert.equal(send.url,'https://gmail.googleapis.com/gmail/v1/users/gotainu%40gmail.com/messages/send');
  assert.equal(send.options.headers.Authorization,'Bearer synthetic-access-token');
  assert.equal(send.options.redirect,'error');assert.ok(send.options.signal instanceof AbortSignal);
  const body=JSON.parse(send.options.body);assert.deepEqual(Object.keys(body),['raw']);assert.match(body.raw,/^[A-Za-z0-9_-]+$/);
  assert.match(Buffer.from(body.raw,'base64url').toString('utf8'),/From: HamCare/);
});
test('OAuth network failure is retryable before Gmail is touched',async()=>{
  const f=fixture({oauth:()=>{throw Error('sensitive credential failure');}});
  await rejected(()=>f.sender.send(message()),'oauth_temporary','not_sent',true);assert.equal(f.calls.length,1);
});
for(const status of [500,502,503,504])test('OAuth '+status+' safely retries before send',async()=>{
  const f=fixture({oauth:()=>response(status,{error:'backend_error'})});
  await rejected(()=>f.sender.send(message()),'oauth_temporary','not_sent',true);assert.equal(f.calls.length,1);
});
test('OAuth 429 preserves Retry-After for worker exponential backoff',async()=>{
  const f=fixture({oauth:()=>response(429,{error:'rate_limit'},{'Retry-After':'120'})});
  const e=await rejected(()=>f.sender.send(message()),'oauth_temporary','not_sent',true);assert.equal(e.retryAfterMillis,120000);
});
for(const [status,body,category]of [[400,{error:'invalid_grant'},'authorization_revoked'],[401,{error:'invalid_token'},'authorization_revoked'],
  [400,{error:'invalid_client'},'authorization_failed'],[403,{error:'access_denied'},'authorization_failed']])
  test('OAuth permanent '+status+' '+category+' never reaches Gmail',async()=>{
    const f=fixture({oauth:()=>response(status,body)});await rejected(()=>f.sender.send(message()),category);assert.equal(f.calls.length,1);
  });
for(const body of [{},{access_token:'bad token'},{access_token:'bad\nsecret'},{access_token:'good',token_type:'MAC'},
  {access_token:'good',scope:'https://mail.google.com/'},{access_token:'good',scope:'https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/gmail.readonly'}])
  test('unusable/broader OAuth response rejects '+Object.keys(body).join(','),async()=>{
    const f=fixture({oauth:()=>response(200,body)});await rejected(()=>f.sender.send(message()),'authorization_failed');assert.equal(f.calls.length,1);
  });
for(const [status,reason,msg,category]of [[400,'invalidArgument','Invalid recipient','invalid_recipient'],[400,'invalidArgument','Malformed raw','request_invalid'],
  [401,'authError','Expired token','authorization_revoked'],[403,'forbidden','Forbidden','authorization_failed'],
  [404,'notFound','Unknown account','gmail_permanent']])
  test('Gmail permanent '+status+' '+category+' stops without raw error text',async()=>{
    const f=fixture({send:()=>response(status,{error:{message:msg+' synthetic@example.test',errors:[{reason}]}})});
    await rejected(()=>f.sender.send(message()),category);assert.equal(f.calls.length,2);
  });
for(const [status,reason,msg,category]of [[429,'userRateLimitExceeded','User-rate limit exceeded','rate_limited'],
  [403,'rateLimitExceeded','Rate limit','rate_limited'],[429,'quotaExceeded','Quota exceeded','quota_exceeded'],
  [403,'dailyLimitExceeded','Daily limit','sending_limit'],[429,'userRateLimitExceeded','User-rate limit exceeded (Mail sending)','sending_limit']])
  test('Gmail known refusal '+category+' supports delayed finite retry',async()=>{
    const f=fixture({send:()=>response(status,{error:{message:msg,errors:[{reason}]}},{'Retry-After':'Wed, 02 Jan 2030 00:00:00 GMT'})});
    const e=await rejected(()=>f.sender.send(message()),category,'not_sent',true);assert.equal(e.retryAfterMillis,86400000);assert.equal(f.calls.length,2);
  });
for(const status of [500,502,503,504])test('Gmail '+status+' is ambiguous and cannot be blindly sent again',async()=>{
  const f=fixture({send:()=>response(status,{error:{message:'Backend error',errors:[{reason:'backendError'}]}})});
  await rejected(()=>f.sender.send(message()),'gmail_temporary','uncertain',false);assert.equal(f.calls.length,2);
});
test('Gmail timeout/network throw is uncertain with no internal second send',async()=>{
  const f=fixture({send:()=>{throw Error('network timeout with email synthetic@example.test');}});
  await rejected(()=>f.sender.send(message()),'delivery_uncertain','uncertain',false);assert.equal(f.calls.length,2);
});
test('Gmail 408 is uncertain rather than incorrectly claiming no delivery',async()=>{
  const f=fixture({send:()=>response(408,{})});await rejected(()=>f.sender.send(message()),'delivery_uncertain','uncertain',false);
});
for(const send of [()=>response(200,{}),()=>response(200,{id:'bad\nmessage-id'}),()=>new Response('{bad',{status:200})])
  test('success without an interpretable acknowledgement remains uncertain',async()=>{
    const f=fixture({send});await rejected(()=>f.sender.send(message()),'delivery_uncertain','uncertain',false);
  });
test('invalid Retry-After is ignored without exposing its contents',async()=>{
  const f=fixture({send:()=>response(429,{error:{message:'Too many requests'}},{'Retry-After':'not-a-date'})});
  const e=await rejected(()=>f.sender.send(message()),'rate_limited','not_sent',true);assert.equal(e.retryAfterMillis,undefined);
});
