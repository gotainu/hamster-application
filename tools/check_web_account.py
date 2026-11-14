#!/usr/bin/env python3
"""Static boundaries for the read-only Preview account page (no network)."""
from pathlib import Path
from html.parser import HTMLParser
import json
import re

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'public'
class Page(HTMLParser):
    def __init__(self): super().__init__(); self.nodes=[]
    def handle_starttag(self, tag, attrs): self.nodes.append((tag,dict(attrs)))

def main():
    checks=[]
    def check(name, condition): checks.append((name,bool(condition)))
    page=Page(); html=(PUBLIC/'account/index.html').read_text();page.feed(html)
    nodes=page.nodes
    ids=[a['id'] for _,a in nodes if 'id' in a]
    check('unique IDs',len(ids)==len(set(ids)))
    check('Japanese and mobile viewport',('html',{'lang':'ja'}) in nodes and 'width=device-width' in html)
    check('zoom remains available','user-scalable=no' not in html and 'maximum-scale=1' not in html)
    check('local module entry only',[(a.get('type'),a.get('src')) for t,a in nodes if t=='script']==[('module','/assets/account.mjs')])
    check('no inline events',all(not k.lower().startswith('on') for _,a in nodes for k in a))
    check('credentials cannot use native GET',all(a.get('method')=='post' for t,a in nodes if t=='form'))
    check('credentials never have native form names',all('name' not in a for t,a in nodes if t=='input'))
    check('inputs start disabled until handlers exist',any(t=='fieldset' and 'disabled' in a for t,a in nodes))
    for t,a in nodes:
        if t=='input':check('input has label '+a['id'],any(x=='label' and y.get('for')==a['id'] for x,y in nodes))
        for attr in ['for','aria-controls','aria-labelledby','aria-describedby']:
            if attr in a:check('accessible references '+attr,all(value in ids for value in a[attr].split()))
        if t in ['script','link','img']:
            resource=a.get('src',a.get('href',''))
            if resource.startswith('/'):check('resource exists '+resource,(PUBLIC/resource.lstrip('/')).is_file())
    check('errors are announced',any(a.get('role')=='alert' for _,a in nodes))
    check('loading and safe guidance exist','準備中' in html and 'Apple' in html and 'ログアウト' in html)
    check('no payment controls or signup form',not re.search(r'type=["\'](?:tel|number)["\']|createUserWithEmailAndPassword|card-number|CVC',html))
    scripts=list((PUBLIC/'assets').glob('account*.mjs'))+[PUBLIC/'assets/firebase-web-config.mjs']
    code='\n'.join(p.read_text() for p in scripts)
    check('no business writers or linking',not re.search(r'\b(?:setDoc|updateDoc|addDoc|deleteDoc|writeBatch|runTransaction|httpsCallable|linkWithCredential|linkWithPopup|createUserWithEmailAndPassword|sendEmailVerification|sendPasswordResetEmail)\s*\(',code))
    check('no custom persistence or raw DOM injection',not re.search(r'localStorage|sessionStorage|\.innerHTML|insertAdjacentHTML|document\.write',code))
    check('no credential or error logging',not re.search(r'console\s*\.|onLog\s*\(',code))
    check('no Stripe/Functions/Analytics',not re.search(r'checkout\.stripe|api\.stripe|firebase-functions|firebase-analytics|cloudfunctions\.net|run\.app',code))
    check('standard session persistence only','browserSessionPersistence' in code and 'browserLocalPersistence' not in code)
    check('read-only Firestore Lite', 'firebase-firestore-lite.js' in code and 'sdk.getDoc(' in code)
    check('no timestamp-based Web entitlement decision',not re.search(r'Date\.now|isPaid|canUsePaidFeatures|isActiveAt|isInitialTrialActive', (PUBLIC/'assets/account-model.mjs').read_text()))
    check('existing SDK version pinned',set(re.findall(r'https://www\.gstatic\.com/firebasejs/([^/]+)/',code))=={'12.17.1'})
    check('public config only',set(json.loads((PUBLIC/'assets/firebase-web-config.mjs').read_text().split('Object.freeze(',1)[1].rsplit(');',1)[0]))=={'apiKey','authDomain','projectId','appId'})
    config=json.loads((ROOT/'firebase.preview.json').read_text())
    rules=config['hosting']['headers']
    account={h['key']:h['value'] for r in rules if r['source']=='/account/**' for h in r['headers']}
    csp=account.get('Content-Security-Policy','')
    check('account page is not stored',account.get('Cache-Control')=='no-store, max-age=0')
    check('CSP blocks form submission/base/frame embedding',all(s in csp for s in ["form-action 'none'","base-uri 'none'","frame-ancestors 'none'","object-src 'none'"]))
    check('CSP does not allow inline/eval/wildcard',not any(s in csp for s in ['unsafe-inline','unsafe-eval','*']))
    directives={p[0]:p[1:] for d in csp.split(';') if (p:=d.split())}
    check('only necessary API origins',set(directives.get('connect-src',[]))=={'https://identitytoolkit.googleapis.com','https://securetoken.googleapis.com','https://firestore.googleapis.com'})
    check('only pinned SDK/helper script origins',set(directives.get('script-src',[]))=={"'self'",'https://www.gstatic.com/firebasejs/12.17.1/','https://apis.google.com'})
    check('fixed auth frames',set(directives.get('frame-src',[]))=={'https://hamster-breeding-app.firebaseapp.com','https://accounts.google.com'})
    check('auth CSP is isolated from landing',any(r['source']=='/' and any(h['key']=='Content-Security-Policy' and "connect-src 'none'" in h['value'] for h in r['headers']) for r in rules))
    print(f'Web account static checks: {sum(ok for _,ok in checks)}/{len(checks)} PASS')
    for name,ok in checks:
        if not ok:print('FAIL:',name)
    return 0 if all(ok for _,ok in checks) else 1
if __name__=='__main__':raise SystemExit(main())
