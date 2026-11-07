// Exact outer Card Upgrade epoch. Only immutable source bytes are retained;
// every recognized projection freshly checks all five raw linked owners.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,realpathSync,rmSync} from 'node:fs';
import {join,relative,isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';

const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update(`blob ${Buffer.byteLength(s)}\0`).update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('./card-upgrade-source-proof.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'6bd0731174a59dcf7233d0408fda5b147402df9c63bc360a9c3f5a456a86b944','complete Card Upgrade source proof');
const proof=JSON.parse(bytes);
// Read the same complete frozen corpus as the behavioral VM without importing
// that VM or its execution dependencies into isolated source-only consumers.
const archive=readFileSync(new URL('./colorless-catalog-before-2ad07111.json.gz',import.meta.url));
assert.equal(hash(archive),'88c0ab46a951aacc45a2cf8e4a2d2c7a6ac0b5ebc153dcdf87ac600ad6ee8a95');
const originalBytes=gunzipSync(archive);
assert.equal(hash(originalBytes),'4f9d7725cf432227aa74c1bd616f0b449223a0f4b4c53a52cf6cfc5617f461cf');
export const cardUpgradeBefore=JSON.parse(originalBytes);
const baseline=cardUpgradeBefore;
assert.equal(baseline.schemaVersion,1);assert.equal(baseline.normalization,'LF');
assert.equal(baseline.revision,'2ad07111e3d5b5cb52b4229860b3b780941e29a9');
assert.equal(Object.keys(baseline.files).length,333);
for(const [name,file]of Object.entries(baseline.files)){
 assert.equal(file.path,'src/lua/'+name+'.lua');assert.equal(normalize(file.source),file.source);
 assert.equal(hash(file.source),file.sha256);assert.equal(blob(file.source),file.gitBlob);Object.freeze(file);
}
Object.freeze(baseline.files);Object.freeze(baseline);
assert.equal(proof.schemaVersion,1);assert.equal(proof.normalization,'LF');
// The corpus keeps its actual historical revision. The actual refactor base was
// independently compared file-for-file and blob-for-blob before freezing proof.
assert.equal(proof.baseRevision,'d8a57cae2a867200ca8e588abc0d368e6cdb3799');
assert.equal(proof.corpusRevision,baseline.revision);
assert.equal(proof.baseLuaCorpus.sourceCount,333);
const manifest=Object.values(baseline.files).map(file=>[file.path,file.gitBlob]).sort(([a],[b])=>a<b?-1:a>b?1:0);
assert.equal(hash(JSON.stringify(manifest)+'\n'),proof.baseLuaCorpus.gitBlobManifestSha256);
Object.freeze(proof.baseLuaCorpus);
const originals=['src/lua/abyss_combat.lua','src/lua/abyss_act2_stasis.lua','src/lua/abyss_warrior_status_cards.lua'];
const witnesses=['src/lua/abyss_card_upgrade.lua'];
const config='config/architecture.json',owners=[...originals,...witnesses,config];
assert.deepEqual(Object.keys(proof.files),owners,'complete five-owner Card Upgrade epoch');
for(const path of originals){
 const original=baseline.files[path.slice(8,-4)],file=proof.files[path];
 assert.equal(original.path,path);assert.equal(original.sha256,file.beforeSha256);assert.equal(original.gitBlob,file.beforeGitBlob);
 file.beforeSource=original.source;
}
for(const [path,file]of Object.entries(proof.files)){
 assert.match(file.afterSha256,/^[a-f0-9]{64}$/);
 if(witnesses.includes(path)){
  assert.deepEqual(Object.keys(file),['afterSha256'],'new witnesses have no invented historical source');
 }else{
  assert.equal(normalize(file.beforeSource),file.beforeSource);
  assert.equal(hash(file.beforeSource),file.beforeSha256);assert.equal(blob(file.beforeSource),file.beforeGitBlob);
  assert.notEqual(file.beforeSha256,file.afterSha256,'an actual complete-source change enters the epoch');
 }
 Object.freeze(file);
}
Object.freeze(proof.files);Object.freeze(proof);
export const cardUpgradeSourceProof=proof;
const readLive=path=>readFileSync(path,'utf8'),rawReaders=new WeakMap();
const identity=(path,source)=>typeof source==='string'&&Object.hasOwn(proof.files,path)
 &&hash(normalize(source))===proof.files[path].afterSha256;
const tokens=source=>source.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,value=>value.startsWith('"')?value:'');
function inputIdentity(path,source){
 if(identity(path,source))return true;
 if(path!==config||typeof source!=='string')return false;
 try{
  const formatted=JSON.stringify(JSON.parse(source),null,2)+'\n';
  return tokens(source)===tokens(formatted)&&hash(formatted)===proof.files[config].afterTokenSha256;
 }catch{return false;}
}
export function preCardUpgradeSource(path,source,{readSource=readLive}={}){
 // Old, foreign, partial and witness-only inputs do not authorize any I/O.
 if(!Object.hasOwn(proof.files[path]??{},'beforeSource')||!inputIdentity(path,source))return source;
 assert.equal(typeof readSource,'function','Card Upgrade linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 for(const owner of owners){
  let current;try{current=readSource(owner);}catch(error){assert.fail('Card Upgrade linked owner missing: '+owner+': '+String(error?.message??error));}
  // Formatting permission belongs to the supplied config input only. Linked
  // real files retain exact normalized bytes, including on warm calls.
  assert(identity(owner,current),'Card Upgrade linked owner identity: '+owner);
 }
 return proof.files[path].beforeSource;
}
export function cardUpgradeReader(readSource=readLive){
 assert.equal(typeof readSource,'function','Card Upgrade linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preCardUpgradeSource(path,readSource(path),{readSource});
 rawReaders.set(reader,readSource);return reader;
}

// The established historical materializer is the only caller. Validate complete
// destination bytes and real filesystem identity both before and at deletion.
export function prepareCardUpgradeRetirement(directory,{sourceRoot=process.cwd()}={}){
 const path=witnesses[0],target=join(directory,path),live=join(sourceRoot,path);
 if(!existsSync(target))return ()=>{};
 const source=realpathSync.native(sourceRoot),destination=realpathSync.native(directory);
 const inside=(root,target)=>{const rel=relative(root,target);return rel!==''&&!isAbsolute(rel)&&rel!=='..'&&!rel.startsWith('../')&&!rel.startsWith('..\\');};
 assert(destination!==source&&!inside(destination,source),'Card Upgrade retirement requires a separate historical destination');
 const actual=realpathSync.native(target),sourceDirectory=realpathSync.native(join(sourceRoot,'src/lua'));
 const check=()=>{
  assert.equal(realpathSync.native(directory),destination,'Card Upgrade retirement destination changed');
  assert.equal(realpathSync.native(target),actual,'Card Upgrade retirement target changed');
  assert(inside(destination,actual)&&actual!==realpathSync.native(live)&&!inside(sourceDirectory,actual),
   'Card Upgrade retirement target aliases live source');
  assert(identity(path,readFileSync(target,'utf8')),'unreviewed Card Upgrade module destination');
 };
 check();return ()=>{check();rmSync(target);};
}
