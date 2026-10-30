// Exact test-only outer replay. Current event tests always execute live production.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {existsSync,readFileSync,realpathSync,lstatSync,rmSync,writeFileSync} from 'node:fs';
import {isAbsolute,join,relative,resolve,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update(`blob ${Buffer.byteLength(s)}\0`).update(s).digest('hex');
const liveDirectory=fileURLToPath(new URL('../..',import.meta.url));
const bytes=normalize(readFileSync(new URL('../fixtures/m3-event-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'b7a5df4dba3e8f9d3d30356e281b0d772df72dd5e4df104d5b1a32dbca660482','complete M3 event outer witness');
export const m3EventSourceLayer=deepFreezeSourceProof(JSON.parse(bytes));
const proof=m3EventSourceLayer;
assert.equal(proof.schemaVersion,1);
assert.equal(proof.baseCommit,'1fcd321ca9d6f79b4e5bbdfede48069119f5ed52');
assert.deepEqual(Object.keys(proof.files),['config/architecture.json','data/release/launch-content.json','src/lua/abyss_act2_events.lua','src/lua/abyss_event_pool.lua','src/lua/abyss_knowing_skull_event.lua','src/lua/abyss_node_ui_events.lua','src/lua/abyss_vampires_event.lua']);
for(const [path,binding]of Object.entries(proof.files)){
 assert.match(binding.afterSha256,/^[a-f0-9]{64}$/);
 assert.ok(binding.beforeSha256===null||/^[a-f0-9]{64}$/.test(binding.beforeSha256));
 assert.equal(binding.beforeGitBlob===null,binding.beforeSha256===null);
 if(binding.beforeSha256===null)assert.deepEqual(binding.hunks,[]);
 let end=0,beforeEnd=0;
 for(const hunk of binding.hunks){
  assert.ok(Number.isSafeInteger(hunk.at)&&hunk.at>=end&&Number.isSafeInteger(hunk.beforeAt)&&hunk.beforeAt>=beforeEnd,'ordered exact M3 hunks: '+path);
  for(const line of [...hunk.before,...hunk.after])assert.ok(typeof line==='string'&&!/[\r\n]/.test(line));
  end=hunk.at+hunk.after.length;beforeEnd=hunk.beforeAt+hunk.before.length;
 }
}
export const m3EventAddedPaths=Object.freeze(Object.keys(proof.files).filter(path=>proof.files[path].beforeSha256===null));
export function preM3EventSource(path,source,{readSource=path=>readFileSync(path,'utf8'),projectAdded=true}={}){
 const binding=proof.files[path];
 if(!binding||typeof source!=='string'||(!projectAdded&&binding.beforeSha256===null))return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 // Deliberately outside every older pure projection cache: linked owners are live.
 for(const added of m3EventAddedPaths){
  let actual;try{actual=readSource(added);}catch{assert.fail('M3 linked source missing: '+added);}
  assert.equal(typeof actual,'string','complete M3 linked source: '+added);
  assert.equal(hash(normalize(actual)),proof.files[added].afterSha256,'M3 linked source drift: '+added);
 }
 if(binding.beforeSha256===null)return null;
 const lines=normalized.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact current M3 hunk: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.beforeSha256,'complete pre-M3 source: '+path);
 assert.equal(blob(previous),binding.beforeGitBlob,'locked pre-M3 Git blob: '+path);
 const forward=[...lines];
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(forward.slice(hunk.beforeAt,hunk.beforeAt+hunk.before.length),hunk.before,'exact original M3 hunk: '+path);
  forward.splice(hunk.beforeAt,hunk.before.length,...hunk.after);
 }
 assert.equal(forward.join('\n'),normalized,'complete forward M3 source: '+path);
 return previous;
}
function inspect(directory,sourceRoot,paths){
 const destination=realpathSync(directory);
 const roots=[liveDirectory,sourceRoot].filter(existsSync).map(root=>realpathSync(root));
 for(const root of roots)assert.notEqual(destination,root,'M3 requires a separate historical destination');
 return paths.flatMap(path=>{
  const target=join(directory,path);
  if(!existsSync(target)){assert.ok(!(()=>{try{return lstatSync(target).isSymbolicLink();}catch{return false;}})(),'M3 dangling destination symlink');return [];}
  const actual=realpathSync(target),within=relative(destination,actual),stat=lstatSync(target);
  assert.ok(within&&!isAbsolute(within)&&within!=='..'&&!within.startsWith('..'+sep),'M3 destination must not escape historical copy: '+path);
  assert.ok(stat.isFile()&&!stat.isSymbolicLink(),'M3 destination must be a regular file: '+path);
  for(const root of roots){const live=join(root,path);if(existsSync(live)){
   assert.notEqual(actual,realpathSync(live),'M3 must never change a live source: '+path);
   const ls=lstatSync(live);assert.ok(stat.dev!==ls.dev||stat.ino!==ls.ino,'M3 must never change a live source hardlink: '+path);
  }}
  return [{path,target,actual,dev:stat.dev,ino:stat.ino}];
 });
}
export function prepareM3EventRetirement(directory,{sourceRoot=process.cwd()}={}){
 assert.notEqual(resolve(directory),resolve(sourceRoot),'M3 requires a separate historical destination');
 const validate=()=>{
  const targets=inspect(directory,sourceRoot,m3EventAddedPaths);
  for(const {path,target}of targets)assert.equal(hash(normalize(readFileSync(target,'utf8'))),proof.files[path].afterSha256,'unreviewed M3 added module destination: '+path);
  return targets;
 };
 const initial=validate();
 const revalidate=()=>{const current=validate();assert.deepEqual(current,initial,'M3 destination changed after preparation');return current;};
 const retire=()=>{for(const {target}of revalidate())rmSync(target);};
 retire.validate=revalidate;
 return retire;
}
export function materializeBeforeM3Events(directory,{sourceRoot=process.cwd(),historicalPaths=[]}={}){
 const retained=new Set(historicalPaths);
 assert.equal(retained.size,historicalPaths.length,'unique historical M3 owners');
 for(const path of retained)assert.ok(proof.files[path]&&proof.files[path].beforeSha256!==null,'only pre-existing M3 sources may retain an older owner');
 const targets=inspect(directory,sourceRoot,Object.keys(proof.files));
 const retire=prepareM3EventRetirement(directory,{sourceRoot});
 const outputs=[];
 for(const {path,target}of targets){
  if(retained.has(path))continue;
  const source=normalize(readFileSync(target,'utf8')),binding=proof.files[path];
  assert.ok(hash(source)===binding.afterSha256||hash(source)===binding.beforeSha256,'unreviewed M3 historical destination: '+path);
  if(binding.beforeSha256!==null)outputs.push([target,preM3EventSource(path,source,{readSource:p=>readFileSync(join(sourceRoot,p),'utf8')})]);
 }
 // Preparation validates the entire destination before any removal or write.
 retire();for(const [target,source]of outputs)writeFileSync(target,source);
}
