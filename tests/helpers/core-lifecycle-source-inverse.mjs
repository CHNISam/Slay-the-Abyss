// One exact reviewed lifecycle epoch. Historical archives remain independent;
// only pure source bytes are retained, never permission from a linked read.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {preRelicQuerySource,relicQueryReader} from './relic-query-source-inverse.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(normalize(s)).digest('hex');
const readHelper=p=>readFileSync(new URL('./'+p,import.meta.url),'utf8');
const combat=JSON.parse(readHelper('combat-lifecycle-before.json'));
assert.equal(combat.revision,'dedb9ed5af52fc595031d64d3e8fd84bc908b2c8');
assert.equal(combat.path,'src/lua/abyss_combat.lua');
assert.equal(combat.sha256,'6929906a274bc84dd2914083ae3d0019ef7ad5d89659f357ff979a89ee9e7805');
export const coreLifecycleSourceProof=Object.freeze({files:Object.freeze({
 'src/lua/abyss_actor.lua':Object.freeze({
  beforeSource:normalize(readHelper('actor-lifecycle-before.lua')),
  beforeSha256:'3ca585adaf351ef9fde31575e121c69186d2f2dfdd451a8ca32bf4ba0855ac94',
  afterSha256:'7dcb58d9d8243a37dde66c7a80a7cfc1b83cd049e40ac1c6bdb7e0167c308515',
 }),
 'src/lua/abyss_combat.lua':Object.freeze({
  beforeSource:normalize(gunzipSync(Buffer.from(combat.gzipBase64,'base64')).toString('utf8')),
  beforeSha256:'6929906a274bc84dd2914083ae3d0019ef7ad5d89659f357ff979a89ee9e7805',
  afterSha256:'0817555edf55919382c1f3cf4ad378c0a4e2d60098a7450551ae7fb305b5470d',
 }),
 'src/lua/abyss_actor_power_rules.lua':Object.freeze({
  afterSha256:'ff5ee7976332e9e3a01a62c121d7a7246ad59ae5eae27f0cd4bb5bee5be6051a',
 }),
 'config/architecture.json':Object.freeze({
  beforeSha256:'fcaff296e24d74abe704b4d3e7c420f6492986ec2ffe9e440cfe5b6b65768380',
  beforeGitBlob:'5c769902739efb7cad09df444bb2421ea5ed46cf',
  afterSha256:'68d46e73d734f9684326b24ba040706d768349ce9a552daf52006bb900bfaabf',
  afterTokenSha256:'b256595245b73acb0e7c29014412dec70aa7e09dcfb794239560824b30bd91b3',
 }),
})});
const files=coreLifecycleSourceProof.files;
for(const [path,binding]of Object.entries(files))if(Object.hasOwn(binding,'beforeSource'))
 assert.equal(hash(binding.beforeSource),binding.beforeSha256,'complete frozen lifecycle source: '+path);
const readLive=p=>readFileSync(p,'utf8');
const rawReaders=new WeakMap();
function identity(path,source){return typeof source==='string'&&Object.hasOwn(files,path)&&hash(source)===files[path].afterSha256;}
const tokens=s=>s.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,t=>t.startsWith('"')?t:'');
function inputIdentity(path,source){
 if(identity(path,source))return true;
 if(path!=='config/architecture.json'||typeof source!=='string'||!source.includes('"abyss_actor_power_rules"'))return false;
 try{
  const formatted=JSON.stringify(JSON.parse(source),null,2)+'\n';
  return tokens(source)===tokens(formatted)&&hash(formatted)===files[path].afterTokenSha256;
 }catch{return false;}
}
export function preCoreLifecycleSource(path,source,{readSource=readLive}={}){
 readSource=rawReaders.get(readSource)??readSource;
 source=preRelicQuerySource(path,source,{readSource});
 // Old, foreign and partial inputs never cause I/O or enter this new epoch.
 if(!Object.hasOwn(files[path]??{},'beforeSha256')||!inputIdentity(path,source))return source;
 assert.equal(typeof readSource,'function','lifecycle linked reader must be a function');
 readSource=relicQueryReader(readSource);
 let liveConfiguration;
 for(const linked of Object.keys(files)){
  let current;try{current=readSource(linked);}catch(error){assert.fail('lifecycle linked owner missing: '+linked+': '+String(error?.message??error));}
  assert.ok(identity(linked,current),'lifecycle linked owner identity: '+linked);
  if(linked==='config/architecture.json')liveConfiguration=current;
 }
 if(path!=='config/architecture.json')return files[path].beforeSource;
 let previous=normalize(liveConfiguration);
 const registration='    "abyss_actor_power_rules": "core",\n';
 const boundary='    {\n      "id": "actor-power-rules-independence",\n      "from": ["abyss_actor_power_rules"],\n      "forbiddenTargets": ["abyss_actor", "abyss_combat", "abyss_relic_hooks"],\n      "reason": "Pure Power validation and stacking cannot depend on lifecycle orchestration or relic callbacks."\n    },\n';
 for(const delta of [registration,boundary]){
  assert.equal(previous.split(delta).length,2,'one exact lifecycle architecture delta');
  previous=previous.replace(delta,'');
 }
 assert.equal(hash(previous),files[path].beforeSha256,'complete pre-lifecycle architecture');
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(previous)+'\0').update(previous).digest('hex'),files[path].beforeGitBlob,'independent dedb architecture Git blob');
 return previous;
}
export function coreLifecycleReader(readSource=readLive){
 assert.equal(typeof readSource,'function','lifecycle linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preCoreLifecycleSource(path,readSource(path),{readSource});
 rawReaders.set(reader,readSource);
 return reader;
}
