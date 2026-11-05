// Leaf test-only boundary for one complete reviewed Host extraction. No historical
// owner imports this through production, and old source epochs perform no I/O.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,existsSync,realpathSync,rmSync} from 'node:fs';
import {join,relative,isAbsolute} from 'node:path';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const tokens=s=>s.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,t=>t.startsWith('"')?t:'');
const bytes=normalize(readFileSync(new URL('./game-ui-extraction-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'b4d40fde943210b406acad1e296922af487066f301fcadb500374baf37771eb9','complete GameUI extraction source witness');
export const gameUiExtractionProof=JSON.parse(bytes);
const proof=gameUiExtractionProof;
for(const b of Object.values(proof.files))Object.freeze(b);
Object.freeze(proof.files);Object.freeze(proof);
export const gameUiExtractionAddedPaths=Object.freeze(['overlays','view','run','lifecycle','input'].map(name=>'src/lua/abyss_game_ui_'+name+'.lua'));
assert.equal(proof.schemaVersion,1);
assert.deepEqual(Object.keys(proof.files),['src/lua/abyss_game_ui.lua','config/architecture.json',...gameUiExtractionAddedPaths]);
for(const [path,b]of Object.entries(proof.files)){
 assert.match(b.afterSha256,/^[a-f0-9]{64}$/);
 if(gameUiExtractionAddedPaths.includes(path))assert.equal(b.beforeSource,null);
 else assert.equal(hash(b.beforeSource),b.beforeSha256,'complete pre-extraction source: '+path);
}
assert.equal(proof.files['src/lua/abyss_game_ui.lua'].beforeSha256,'165e2ad1180cab9daf5321b46d1f87fe9c34ed6ebbcd3c3a8b495d23974e0933');
const readLive=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const rawReaders=new WeakMap();
function identity(path,source){
 if(typeof source!=='string')return false;
 const b=proof.files[path];if(!b)return false;
 if(path!=='config/architecture.json')return hash(normalize(source))===b.afterSha256;
 try{
  const formatted=JSON.stringify(JSON.parse(source),null,2)+'\n';
  return tokens(source)===tokens(formatted)&&hash(formatted)===b.afterTokenSha256;
 }catch{return false;}
}
function validate(readSource){
 assert.equal(typeof readSource,'function','GameUI extraction linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 for(const path of Object.keys(proof.files)){
  const source=readSource(path);
  assert.ok(identity(path,source),'reviewed GameUI extraction linked owner: '+path);
 }
}
export function preGameUiExtractionSource(path,source,{readSource=readLive}={}){
 // Reject path/type/hash/token drift before reading any detached owner.
 if(!identity(path,source))return source;
 validate(readSource);
 return proof.files[path].beforeSource;
}
export function gameUiExtractionReader(readSource=readLive){
 assert.equal(typeof readSource,'function','GameUI extraction linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preGameUiExtractionSource(path,readSource(path),{readSource});
 rawReaders.set(reader,readSource);
 return reader;
}
const inside=(root,target)=>{const rel=relative(root,target);return !!rel&&!isAbsolute(rel)&&rel!=='..'&&!rel.startsWith('..\\')&&!rel.startsWith('../');};
export function prepareGameUiExtractionModuleRetirement(directory,{sourceRoot=process.cwd()}={}){
 const destination=realpathSync(directory),source=realpathSync(sourceRoot);
 assert.ok(destination!==source&&!inside(source,destination)&&!inside(destination,source),'GameUI extraction retirement requires an isolated historical destination');
 function targets(){
  const result=[];
  for(const path of gameUiExtractionAddedPaths){
   const target=join(directory,path);if(!existsSync(target))continue;
   const actual=realpathSync(target);
   assert.ok(inside(destination,actual)&&!inside(source,actual),'GameUI extraction retirement target aliases source: '+path);
   assert.ok(identity(path,readFileSync(actual,'utf8')),'reviewed GameUI extraction retirement module: '+path);
   result.push(actual);
  }
  return result;
 }
 targets();
 return ()=>{const verified=targets();for(const target of verified)rmSync(target);};
}
