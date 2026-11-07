// Exact Session reward epoch; all linked sources are read again on every call.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('./session-reward-source-proof.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'2c2231817efb9cfa79693294d33e6b2b9e292ea69ed2dccab19d4db0fb59f8ea');
export const sessionRewardProof=JSON.parse(bytes);
assert.equal(sessionRewardProof.revision,'2c85bc618f39a4706dbc108eca0ebe5797630081');
const files=sessionRewardProof.files;
assert.deepEqual(Object.keys(files),['config/architecture.json','src/lua/abyss_event_combat.lua','src/lua/abyss_event_combat_routes.lua','src/lua/abyss_potion_rewards.lua']);
for(const file of Object.values(files)){
 assert.equal(hash(file.beforeSource),file.beforeSha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(file.beforeSource)+'\0'+file.beforeSource).digest('hex'),file.beforeGitBlob);
 Object.freeze(file);
}
Object.freeze(files);Object.freeze(sessionRewardProof.linked);Object.freeze(sessionRewardProof);
const readLive=p=>readFileSync(p,'utf8'),readers=new WeakMap();
const tokens=s=>s.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,t=>t.startsWith('"')?t:'');
const identity=(path,source)=>typeof source==='string'&&Object.hasOwn(files,path)&&hash(normalize(source))===files[path].afterSha256;
function inputIdentity(path,source){
 if(identity(path,source))return true;
 if(path!=='config/architecture.json'||typeof source!=='string')return false;
 try{const canonical=JSON.stringify(JSON.parse(source),null,2)+'\n';return tokens(source)===tokens(canonical)&&hash(canonical)===files[path].afterCanonicalSha256;}catch{return false;}
}
export function preSessionRewardSource(path,source,{readSource=readLive}={}){
 if(!inputIdentity(path,source))return source;
 assert.equal(typeof readSource,'function','Session reward linked reader must be a function');
 readSource=readers.get(readSource)??readSource;
 for(const linked of [...Object.keys(files),...Object.keys(sessionRewardProof.linked)]){
  let current;try{current=readSource(linked);}catch(error){assert.fail('Session reward linked owner missing: '+linked+': '+String(error?.message??error));}
  assert(typeof current==='string','Session reward linked owner missing: '+linked);
  assert.equal(hash(normalize(current)),files[linked]?.afterSha256??sessionRewardProof.linked[linked],'Session reward linked owner identity: '+linked);
 }
 return files[path].beforeSource;
}
export function sessionRewardReader(readSource=readLive){
 assert.equal(typeof readSource,'function','Session reward linked reader must be a function');
 if(readers.has(readSource))return readSource;
 const reader=path=>preSessionRewardSource(path,readSource(path),{readSource});readers.set(reader,readSource);return reader;
}
