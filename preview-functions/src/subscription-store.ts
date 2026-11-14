import {getFirestore} from 'firebase-admin/firestore';
import {subjectRef,PREVIEW_NAMESPACE} from './preview-runtime';
import {PreviewSyncError,PreviewSyncStore} from './subscription-sync';
const eventRef=(id:string)=>{if(!/^[a-f0-9]{64}$/.test(id))throw new PreviewSyncError('event_invalid',false);return getFirestore().collection(PREVIEW_NAMESPACE).doc('_events').collection('events').doc(id);};
export function createPreviewSyncStore():PreviewSyncStore {
  const db=getFirestore();
  return {
    async claimEvent(eventHash,lease,nowMs,untilMs,meta) {
      return db.runTransaction(async tx=>{const ref=eventRef(eventHash);const snap=await tx.get(ref);const old=snap.data()||{};
        if(old.result==='processed')return 'processed';
        if(old.lease && old.leaseUntil>nowMs)return 'busy';
        tx.set(ref,{...meta,lease,leaseUntil:untilMs,result:'processing',attempts:(old.attempts||0)+1});return 'claimed';});
    },
    async readSubject(subjectHash) {return (await subjectRef(subjectHash).get()).data() as any;},
    async claimSubject(subjectHash,lease,nowMs,untilMs) {
      return db.runTransaction(async tx=>{const ref=subjectRef(subjectHash);const snap=await tx.get(ref);if(!snap.exists)return false;const s=snap.data()!;
        if(s.syncLease && s.syncLease.untilMs>nowMs)return false;
        tx.update(ref,{syncLease:{lease,untilMs}});return true;});
    },
    async commit({subjectHash,eventHash,lease,billing,eventRecord,nowMs}) {
      await db.runTransaction(async tx=>{const root=subjectRef(subjectHash);const receipt=eventRef(eventHash);const [a,b]=await Promise.all([tx.get(root),tx.get(receipt)]);const s=a.data()||{};const e=b.data()||{};
        if(s.syncLease?.lease!==lease || s.syncLease.untilMs<=nowMs || e.lease!==lease || e.leaseUntil<=nowMs || e.result!=='processing')throw new PreviewSyncError('sync_conflict',true);
        tx.set(root.collection('billing').doc('subscription'),billing);
        tx.update(root,{syncLease:null});
        tx.set(receipt,{...eventRecord,result:'processed',processedAtMillis:nowMs,lease:null,leaseUntil:0});
      });
    },
    async release({subjectHash,eventHash,lease,errorCode}) {
      await db.runTransaction(async tx=>{const receipt=eventRef(eventHash);const root=subjectHash?subjectRef(subjectHash):null;const es=await tx.get(receipt);const ss=root?await tx.get(root):null;
        if(es.data()?.lease===lease)tx.update(receipt,{result:'retryable',lease:null,leaseUntil:0,errorCode});
        if(root && ss?.data()?.syncLease?.lease===lease)tx.update(root,{syncLease:null});});
    },
  };
}
