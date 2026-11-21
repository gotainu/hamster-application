import {authorizeWebBillingManagementIdentity} from './webBillingShared';
import {createSupportDeletion, inspectSupportDeletion, confirmSupportDeletion,
  reviewSupportDeletion, executeSupportDeletion} from './supportAccountDeletion';

export const SUPPORT_DELETION_ORIGIN = 'https://hamster-breeding-app.web.app';
type Core = Parameters<typeof createSupportDeletion>[0];
type Dependencies = {
  core: Core;
  enabled: () => boolean;
  auth: {
    verifyIdToken(token:string, checkRevoked:boolean):Promise<any>;
    getUser(uid:string):Promise<any>;
  };
};
type Request = {method:string; headers:Record<string,unknown>; query:Record<string,unknown>; body:unknown};
type Reply = {status:number; body:Record<string,unknown>};
const object = (v:unknown):v is Record<string,unknown> => !!v && typeof v==='object' && !Array.isArray(v);
const exact = (v:Record<string,unknown>,keys:string[]) => Object.keys(v).sort().join(',')===keys.sort().join(',');
const stopped = ():Reply => ({status:503,body:{ok:false,message:'現在、この本人確認を受け付けていません。サポートへご連絡ください。'}});

/** The public endpoint confirms intent only. It cannot start cleanup, mint a
 * ticket, accept a target UID, or bypass the ticket's server-selected account. */
export function createSupportDeletionHttp(d:Dependencies) {
  return {
    async confirm(req:Request):Promise<Reply> {
      if (!d.enabled()) return stopped();
      if (req.method!=='POST' || req.headers.origin!==SUPPORT_DELETION_ORIGIN ||
          Object.keys(req.query).length || !object(req.body)) return {status:400,body:{ok:false}};
      const b=req.body;
      const keys=b.action==='inspect'?['action','requestId','proof']:
        ['action','requestId','proof','confirmText','stopBillingConfirmed','appleRevocation'];
      if (typeof b.action!=='string' || !['inspect','confirm'].includes(b.action) || !exact(b,keys)) return {status:400,body:{ok:false}};
      const bearer=req.headers.authorization;
      if (typeof bearer!=='string' || !/^Bearer [^\s]{1,8192}$/.test(bearer)) return {status:401,body:{ok:false}};
      try {
        const token=await d.auth.verifyIdToken(bearer.slice(7),true);
        const user=await d.auth.getUser(token.uid);
        const identity=authorizeWebBillingManagementIdentity(token,user);
        if (!Number.isSafeInteger(token.auth_time)) throw new Error('authentication_required');
        const confirmed={uid:identity.uid,authTime:token.auth_time,
          appleLinked:user.providerData.some((p:any)=>p.providerId==='apple.com')};
        if (b.action==='inspect') {
          const result=await inspectSupportDeletion(d.core,{requestId:b.requestId,proof:b.proof} as any,confirmed);
          return {status:200,body:result};
        }
        const {action:_,...input}=b;
        const result=await confirmSupportDeletion(d.core,input as any,confirmed);
        return {status:200,body:result};
      } catch {
        // Do not disclose target existence, provider subject, credentials or SDK errors.
        return {status:403,body:{ok:false,message:'この申請とアカウントの本人確認を完了できませんでした。リンクの期限とログイン方法をご確認のうえ、サポートへご連絡ください。'}};
      }
    },
    /** IAM-protected onRequest only. Never mount this handler on public Hosting,
     * a callable, or the anonymous confirmation endpoint. Review is the default. */
    async operator(req:Request):Promise<Reply> {
      if (!d.enabled()) return stopped();
      if (req.method!=='POST' || Object.keys(req.query).length || !object(req.body)) return {status:400,body:{ok:false}};
      const b=req.body;
      try {
        if (b.action==='create' && exact(b,['action','targetUid','intakeRef'])) {
          return {status:200,body:await createSupportDeletion(d.core,b as any)};
        }
        if ((b.action===undefined || b.action==='review') && exact(b,b.action===undefined?['requestId']:['action','requestId'])) {
          return {status:200,body:await reviewSupportDeletion(d.core,b.requestId as string)};
        }
        if (b.action==='execute' && exact(b,['action','requestId','reviewDigest','confirmText']) && b.confirmText==='EXECUTE_VERIFIED_DELETION') {
          return {status:200,body:await executeSupportDeletion(d.core,b as any)};
        }
        return {status:400,body:{ok:false}};
      } catch {
        return {status:409,body:{ok:false,message:'申請・確認内容・処理状態を再確認してください。'}};
      }
    },
  };
}
