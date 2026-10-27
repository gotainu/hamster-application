'use strict';
// Offline metadata adapter. Aggregation is executed by the shared SQL, not UI.
const {createHash} = require('node:crypto');
const DAY=86400000;
const stable=(v)=>Array.isArray(v)?v.map(stable):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,stable(v[k])])):v;
const stringify=(v)=>JSON.stringify(stable(v));
const hash=(v)=>createHash('sha256').update(stringify(v)).digest('hex');
const ms=(v)=>v==null?null:Date.parse(v);
const jstDay=(v)=>Math.floor((v+9*3600000)/DAY);
const generatedNames=new Set(['first_personalized_report_generated','personality_report_generated']);
function canonicalFacts(input,config){
  const asOf=ms(config.as_of), serverThrough=ms(config.server_complete_through), ga4Through=ms(config.ga4_complete_through);
  if(!Number.isFinite(asOf)||![serverThrough,ga4Through].every(x=>x===null||Number.isFinite(x))) throw Error('Explicit valid UTC as_of / completeness watermarks required.');
  if([serverThrough,ga4Through].some(x=>x!==null&&x>asOf))throw Error('Watermark cannot exceed as_of.');
  if(!['general','validation'].includes(config.audience))throw Error('Unknown audience.');
  if(config.timezone!=='Asia/Tokyo')throw Error('This metric policy explicitly requires Asia/Tokyo.');
  for(const k of ['conversion_horizon_days','landmark_days','landmark_followup_day'])if(!Number.isSafeInteger(config[k])||config[k]<=0)throw Error('Explicit positive integer '+k+' required.');
  if(config.landmark_days>=config.conversion_horizon_days||config.landmark_followup_day<config.landmark_days)throw Error('Invalid landmark / follow-up horizon.');
  const diagnostics={server_input:input.server.length,ga4_input:input.ga4.length,server_duplicates:0,ga4_duplicates:0,unclassified_excluded:0,test_excluded:0,invalid_identity_excluded:0,unmatched_report_views:0,out_of_order_milestones:0};
  const choose=(rows,key,kind)=>{
    const m=new Map();
    for(const r of rows){
      if(!r.user_id||!r.event_name||!Number.isFinite(ms(r.event_at))||!Number.isFinite(ms(r.ingested_at))){diagnostics.invalid_identity_excluded++;continue;}
      if(ms(r.event_at)>asOf||ms(r.ingested_at)>asOf)continue;
      const id=key(r);if(!id){diagnostics.invalid_identity_excluded++;continue;}
      const prev=m.get(id);if(prev)diagnostics[kind+'_duplicates']++;
      const replace=kind==='ga4'?(!prev||ms(r.event_at)<ms(prev.event_at)||(r.event_at===prev.event_at&&stringify(r)<stringify(prev))):(!prev||ms(r.ingested_at)>ms(prev.ingested_at)||(r.ingested_at===prev.ingested_at&&stringify(r)>stringify(prev)));
      if(replace)m.set(id,r);
    }
    return [...m.values()].sort((a,b)=>ms(a.event_at)-ms(b.event_at)||stringify(a).localeCompare(stringify(b)));
  };
  const allServer=choose(input.server,r=>r.source_event_id&&`${r.user_id}:${r.source_event_id}`,'server');
  const allowed=(r)=>{
    if(config.audience==='validation')return ['test','emulator','synthetic'].includes(r.environment)&&['test','synthetic'].includes(r.account_classification);
    if(r.environment==='unknown'||!r.environment||r.account_classification==='unknown'||!r.account_classification){diagnostics.unclassified_excluded++;return false;}
    if(r.environment!=='live'||r.account_classification!=='general'||r.test_only===true||r.test_only===1){diagnostics.test_excluded++;return false;}
    return true;
  };
  const server=allServer.filter(allowed);
  // Registration is the roster source. Missing legacy registrations remain uninstrumented.
  const users=new Set(server.filter(r=>r.event_name==='account_registered').map(r=>r.user_id));
  const ga4=choose(input.ga4,r=>{
    const id=r.event_id||r.presentation_id;
    return id?`${r.user_id}:${r.event_name}:${id}`:null;
  },'ga4').filter(r=>users.has(r.user_id)&&r.analytics_identity_version==='firebase_uid_v1'&&(
    config.audience==='general'?r.analytics_environment==='live'&&r.test_only===0:
      ['test','emulator','synthetic'].includes(r.analytics_environment)&&r.test_only===1));
  const facts=[];const active=[];
  for(const uid of [...users].sort()){
    const own=server.filter(e=>e.user_id===uid), client=ga4.filter(e=>e.user_id===uid);
    const first=(xs)=>xs.length?Math.min(...xs.map(e=>ms(e.event_at))):null;
    const registered=first(own.filter(e=>e.event_name==='account_registered'));
    const trialEvents=own.filter(e=>e.event_name==='initial_trial_started'&&ms(e.event_at)>=registered);
    const trial=trialEvents[0]||null, trialAt=trial?ms(trial.event_at):null;
    const within=own.filter(e=>trialAt!==null&&ms(e.event_at)>=trialAt&&(!e.trial_id||e.trial_id===trial.trial_id));
    const gens=within.filter(e=>generatedNames.has(e.event_name)&&e.pet_id&&e.report_id&&Number.isInteger(e.report_revision));
    const views=client.filter(v=>v.event_name==='personalized_report_viewed').filter(v=>{
      const match=gens.some(g=>v.pet_id===g.pet_id&&v.report_id===g.report_id&&v.report_revision===g.report_revision&&ms(v.event_at)>=ms(g.event_at));
      if(!match)diagnostics.unmatched_report_views++;return match;
    });
    const manual=e=>e.record_source==='manual'&&e.actor==='user_client'&&e.record_type!=='switchbot_reading';
    const saved=own.filter(e=>e.event_name==='valid_record_saved'&&manual(e));
    const meaningful=[...saved,...own.filter(e=>e.event_name==='ai_answer_succeeded'),...views];
    const activeDays=new Set(meaningful.map(e=>jstDay(ms(e.event_at))));
    for(const d of [...activeDays].sort())active.push({user_id:uid,active_day:d});
    const at=name=>first(within.filter(e=>e.event_name===name));
    const a1=at('ai_answer_succeeded');
    const a2=first(within.filter(e=>(e.event_name==='first_accepted_data_saved'||e.event_name==='valid_record_saved')&&manual(e)&&['weight','activity','distance'].includes(e.record_type)));
    const body=first(within.filter(e=>e.event_name==='analysis_readiness_changed'&&e.current_status==='ready'&&e.metric==='body'));
    const activity=first(within.filter(e=>e.event_name==='analysis_readiness_changed'&&e.current_status==='ready'&&e.metric==='activity'));
    const ready=body===null?activity:activity===null?body:Math.min(body,activity);
    const paid=first(within.filter(e=>e.event_name==='subscription_activated'&&(config.audience!=='general'||e.billing_livemode===true)));
    const generated=first(gens),viewed=first(views);
    const f={user_id:uid,registered:1,trial_started:+(trialAt!==null),a1:+(a1!==null),a2:+(a2!==null),ready:+(ready!==null),body_ready:+(body!==null),activity_ready:+(activity!==null),generated:+(generated!==null),viewed:+(viewed!==null),paid:+(paid!==null),paywall:+client.some(e=>e.event_name==='paywall_presented'&&trialAt!==null&&ms(e.event_at)>=trialAt),checkout:+client.some(e=>e.event_name==='checkout_started'&&trialAt!==null&&ms(e.event_at)>=trialAt),cancel_scheduled:+(at('subscription_cancel_scheduled')!==null),ended:+(at('subscription_ended')!==null),cohort_month:trialAt===null?'not_started':new Date(trialAt+9*3600000).toISOString().slice(0,7),registered_at:new Date(registered).toISOString(),trial_started_at:trialAt===null?null:new Date(trialAt).toISOString(),first_report_viewed_at:viewed===null?null:new Date(viewed).toISOString()};
    // Strict ordered funnel; independent reach metrics above remain available.
    let cursor=registered;f.funnel_depth=1;
    const sequence=[trialEvents,within.filter(e=>e.event_name==='ai_answer_succeeded'),within.filter(e=>(e.event_name==='first_accepted_data_saved'||e.event_name==='valid_record_saved')&&manual(e)&&['weight','activity','distance'].includes(e.record_type)),within.filter(e=>e.event_name==='analysis_readiness_changed'&&e.current_status==='ready'&&['body','activity'].includes(e.metric)),gens,views,within.filter(e=>e.event_name==='subscription_activated'&&(config.audience!=='general'||e.billing_livemode===true))];
    for(const xs of sequence){const next=first(xs.filter(e=>ms(e.event_at)>=cursor));if(next===null)break;cursor=next;f.funnel_depth++;}
    if(f.funnel_depth<8&&[trialAt,a1,a2,ready,generated,viewed,paid].every(x=>x!==null))diagnostics.out_of_order_milestones++;
    const complete=Math.min(serverThrough??-Infinity,ga4Through??-Infinity);
    for(const d of [1,7,14,21]){
      const end=(jstDay(registered)+d+1)*DAY-9*3600000;
      f[`d${d}_eligible`]=+(complete>=end);
      f[`d${d}_retained`]=+(activeDays.has(jstDay(registered)+d));
    }
    const horizon=trialAt===null?null:trialAt+config.conversion_horizon_days*DAY;
    f.conversion_eligible=+(horizon!==null&&serverThrough!==null&&serverThrough>=horizon);
    f.converted=+(paid!==null&&horizon!==null&&paid<=horizon);
    const landmark=trialAt===null?null:trialAt+config.landmark_days*DAY;
    const followupDay=trialAt===null?null:jstDay(trialAt)+config.landmark_followup_day;
    const followupEnd=followupDay===null?Infinity:(followupDay+1)*DAY-9*3600000;
    f.landmark_eligible=+(horizon!==null&&complete>=Math.max(horizon,followupEnd));
    f.landmark_segment=viewed!==null&&viewed<=landmark?'viewed_by_day14':'not_viewed_by_day14';
    f.landmark_retained=+(followupDay!==null&&activeDays.has(followupDay));
    f.landmark_conversion_eligible=+(paid===null||paid>landmark);
    f.landmark_converted=+(paid!==null&&paid>landmark&&paid<=horizon);
    facts.push(f);
  }
  return {facts,active,diagnostics,config:stable(config)};
}
module.exports={canonicalFacts,hash,stringify,stable};
