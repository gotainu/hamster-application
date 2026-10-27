'use strict';
const crypto=require('node:crypto');
const KEY_URL='https://www.gstatic.com/iap/verify/public_key-jwk';
function createIapVerifier({audience,adminEmails,fetchImpl=fetch,now=()=>Date.now()}={}){
 if(!/^\/projects\/\d+\/locations\/[a-z0-9-]+\/services\/[a-z0-9-]+$/.test(audience||''))throw Error('Verified direct Cloud Run IAP audience is required');
 if(!Array.isArray(adminEmails)||!adminEmails.length||adminEmails.some(email=>typeof email!=='string'||!email.includes('@')))throw Error('Explicit administrator allowlist is required');
 const allowed=new Set(adminEmails.map(value=>value.toLowerCase()));let keys=null,expires=0,pending=null,lastUnknownRefreshAt=-Infinity;
 async function loadKeys(force=false){
  if(keys&&(!force&&expires>now()||force&&now()-lastUnknownRefreshAt<60000))return keys;
  if(pending)return pending;
  if(force)lastUnknownRefreshAt=now();
  pending=(async()=>{
   let response;try{response=await fetchImpl(KEY_URL,{signal:AbortSignal.timeout(5000)})}catch{throw Error('IAP_KEY_UNAVAILABLE')}
   if(!response.ok)throw Error('IAP_KEY_UNAVAILABLE');
   let data;try{data=await response.json()}catch{throw Error('IAP_KEY_UNAVAILABLE')}
   if(!Array.isArray(data.keys)||!data.keys.length)throw Error('IAP_KEY_UNAVAILABLE');
   const next=new Map();for(const key of data.keys)if(key.kty==='EC'&&key.crv==='P-256'&&typeof key.kid==='string')next.set(key.kid,crypto.createPublicKey({key,format:'jwk'}));
   if(!next.size)throw Error('IAP_KEY_UNAVAILABLE');
   const seconds=Math.min(3600,Number(response.headers?.get('cache-control')?.match(/max-age=(\d+)/)?.[1]||300));
   keys=next;expires=now()+seconds*1000;return keys;
  })();try{return await pending}finally{pending=null}
 }
 return async function verify(assertion){
  if(typeof assertion!=='string'||assertion.length>16000)throw Error('IAP_AUTH_REQUIRED');
  const parts=assertion.split('.');if(parts.length!==3||parts.some(part=>!part||!/^[A-Za-z0-9_-]+$/.test(part)))throw Error('IAP_TOKEN_INVALID');
  let header,claims;try{header=JSON.parse(Buffer.from(parts[0],'base64url'));claims=JSON.parse(Buffer.from(parts[1],'base64url'))}catch{throw Error('IAP_TOKEN_INVALID')}
  if(!header||!claims||typeof header!=='object'||typeof claims!=='object'||header.alg!=='ES256'||typeof header.kid!=='string'||header.crit||header.jku||header.jwk||header.x5u)throw Error('IAP_TOKEN_INVALID');
  let available=await loadKeys();if(!available.has(header.kid))available=await loadKeys(true);
  const key=available.get(header.kid),signature=Buffer.from(parts[2],'base64url');
  if(!key||signature.length!==64||!crypto.verify('sha256',Buffer.from(`${parts[0]}.${parts[1]}`),{key,dsaEncoding:'ieee-p1363'},signature))throw Error('IAP_TOKEN_INVALID');
  const seconds=now()/1000;
  if(claims.iss!=='https://cloud.google.com/iap'||claims.aud!==audience||!Number.isFinite(claims.iat)||!Number.isFinite(claims.exp)||claims.exp<seconds-30||claims.iat>seconds+30||claims.exp<=claims.iat||claims.exp-claims.iat>600||claims.nbf!==undefined&&(!Number.isFinite(claims.nbf)||claims.nbf>seconds+30)||typeof claims.sub!=='string'||!claims.sub||typeof claims.email!=='string')throw Error('IAP_TOKEN_INVALID');
  if(!allowed.has(claims.email.toLowerCase()))throw Error('IAP_ACCOUNT_FORBIDDEN');
  return {subject:claims.sub}; // Email, token and upstream headers never enter output/logging.
 };
}
module.exports={createIapVerifier};
