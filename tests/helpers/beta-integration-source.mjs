import {preBetaHostSource} from './beta-delivery-host-source.mjs';
// Test-only composition of PR379 with PR372. Both frozen source branches remain intact.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,realpathSync,rmSync} from 'node:fs';
import {join,relative,isAbsolute,sep} from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const sourceDirectory=fileURLToPath(new URL('../..',import.meta.url));
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/beta-integration-sources.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'ce3402eb178847948c88f90d785fc89cd72bb3a87f136e8be56b8c1dc36223a3','complete beta composition witness');
export const betaSources=JSON.parse(bytes).sources;
const added=Object.entries(betaSources).filter(([,b])=>b.targets.history.absent).map(([p])=>p);
export function preBetaSource(path,source,target='history',{readSource=p=>readFileSync(p,'utf8')}={}){
 assert.ok(['history','feature379'].includes(target),'known beta source target');
 source=preBetaHostSource(path,source,{readSource});
 const b=betaSources[path];
 if(!b||typeof source!=='string'||hash(normalize(source))!==b.sha256||!b.targets[target])return source;
 for(const p of added){
  let input;try{input=readSource(p);}catch{assert.fail('unreviewed beta linked source missing: '+p);}
  assert.equal(typeof input,'string','complete beta linked source: '+p);
  const actual=preBetaHostSource(p,input,{readSource});
  assert.equal(typeof actual,'string','complete beta linked source: '+p);
  assert.equal(hash(normalize(actual)),betaSources[p].sha256,'unreviewed beta linked owner; linked source drift: '+p);
 }
 const destination=b.targets[target];if(destination.absent)return null;
 const lines=normalize(source).split('\n');
 for(const h of [...destination.hunks].reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.current.length),h.current,'exact beta composition hunk: '+path);
  lines.splice(h.at,h.current.length,...h.prior);
 }
 const prior=lines.join('\n');assert.equal(hash(prior),destination.sha256,'complete beta target: '+path);
 let delta=0;const forward=destination.hunks.map(h=>{const at=h.at+delta;delta+=h.prior.length-h.current.length;return {...h,at};});
 for(const h of forward.reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.prior.length),h.prior,'exact forward beta hunk: '+path);
  lines.splice(h.at,h.prior.length,...h.current);
 }
 assert.equal(lines.join('\n'),normalize(source),'complete forward beta source: '+path);
 return prior;
}
export function prepareBetaRetirement(directory,{sourceRoot=process.cwd()}={}){
 const validate=()=>{
  const destination=realpathSync(directory),liveRoots=[sourceRoot,sourceDirectory,process.cwd()].map(p=>realpathSync(p));
  for(const live of liveRoots)assert.notEqual(destination,live,'beta retirement requires a historical copy');
  const targets=[];
  for(const p of added){
   const file=join(directory,p);if(!existsSync(file))continue;
   const actual=realpathSync(file),within=relative(destination,actual);
   assert.ok(within&&!isAbsolute(within)&&within!=='..'&&!within.startsWith('..'+sep),'beta retirement must stay in copy');
   for(const live of liveRoots)if(existsSync(join(live,p)))assert.notEqual(actual,realpathSync(join(live,p)),'beta retirement must not remove live source');
   assert.equal(hash(normalize(preBetaHostSource(p,readFileSync(file,'utf8'),{readSource:q=>readFileSync(join(sourceRoot,q),'utf8')}))),betaSources[p].sha256,'unreviewed beta added module destination: '+p);
   targets.push(file);
  }
  return targets;
 };
 validate();return ()=>{for(const p of validate())rmSync(p);};
}
