'use strict';
// Entirely fictional identities and events. No production exports are imported.
const DAY=86400000, start=Date.parse('2026-10-01T00:00:00Z');
function fixture(){
 const server=[],ga4=[];let n=0;
 const iso=(x)=>new Date(x).toISOString();
 const e=(u,name,day,extra={})=>{const at=iso(start+day*DAY);const r={source_event_id:`fake_${u}_${++n}`,source_collection:'analysis_events',user_id:`synthetic_${u}`,event_name:name,event_at:at,ingested_at:iso(start+day*DAY+1000),environment:'live',account_classification:'general',test_only:false,trial_id:'fake_initial_trial',...extra};server.push(r);return r;};
 const g=(u,name,day,extra={})=>{const r={user_id:`synthetic_${u}`,event_name:name,event_id:`fake_client_${++n}`,presentation_id:`fake_presentation_${n}`,event_at:iso(start+day*DAY),ingested_at:iso(start+day*DAY+5000),analytics_environment:'live',test_only:0,analytics_identity_version:'firebase_uid_v1',...extra};ga4.push(r);return r;};
 for(const u of ['alpha','beta','gamma','epsilon'])e(u,'account_registered',0,{trial_id:null});
 e('delta','account_registered',30,{trial_id:null});
 for(const u of ['alpha','beta','gamma']){e(u,'initial_trial_started',0.001);e(u,'ai_answer_succeeded',0.1);}
 e('delta','initial_trial_started',30.001);e('delta','ai_answer_succeeded',30.1);
 const record=(u,day,type='weight')=>e(u,'valid_record_saved',day,{actor:'user_client',record_source:'manual',record_type:type});
 for(const u of ['alpha','beta']){record(u,0.2);record(u,1);e(u,'first_accepted_data_saved',0.2,{actor:'user_client',record_source:'manual',record_type:'weight'});}
 for(const d of [7,14,21])record('alpha',d);
 record('beta',14);
 for(const u of ['alpha','beta']){
  e(u,'analysis_readiness_changed',12,{metric:'body',current_status:'ready'});
  e(u,'personality_report_generated',12.1,{pet_id:`fake_pet_${u}`,report_id:'fake_first',report_revision:1});
  g(u,'personalized_report_viewed',u==='alpha'?13:18,{pet_id:`fake_pet_${u}`,report_id:'fake_first',report_revision:1});
  g(u,'paywall_presented',17);g(u,'checkout_started',17.1);
 }
 e('alpha','subscription_activated',18,{billing_livemode:true});
 e('alpha','subscription_cancel_scheduled',23,{billing_livemode:true});
 e('alpha','subscription_ended',29,{billing_livemode:true});
 e('beta','subscription_activated',25,{billing_livemode:true});
 // Automatic production is intentionally not meaningful retention.
 e('gamma','personality_report_generated',21,{pet_id:'fake_pet_gamma',report_id:'fake_auto',report_revision:1});
 e('gamma','valid_record_saved',7,{actor:'sensor',record_source:'sensor',record_type:'switchbot_reading'});
 // Spoofed cross-owner/pet view must not join.
 g('gamma','personalized_report_viewed',13,{pet_id:'fake_pet_alpha',report_id:'fake_first',report_revision:1});
 // Ingestion after as_of cannot change a snapshot.
 g('gamma','personalized_report_viewed',22,{pet_id:'fake_pet_gamma',report_id:'fake_auto',report_revision:1,ingested_at:'2026-11-02T00:00:00Z'});
 const duplicate=server.find(x=>x.event_name==='valid_record_saved');server.push({...duplicate,ingested_at:iso(Date.parse(duplicate.ingested_at)+100)});
 const view=ga4.find(x=>x.event_name==='personalized_report_viewed');ga4.push({...view,ingested_at:iso(Date.parse(view.ingested_at)+100)});
 e('sandbox','account_registered',0,{environment:'test',account_classification:'test',test_only:true});
 e('unknown','account_registered',0,{environment:'unknown',account_classification:'unknown'});
 return {schema_version:'journey_synthetic_input_v1',synthetic_only:true,server,ga4};
}
module.exports={fixture};
