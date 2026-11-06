// Exact final M7 epoch; the original three complete Git sources stay frozen.
// Source bytes can be retained. Linked-owner authorization is always a fresh read.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=s=>createHash('sha256').update(s).digest('hex');
const normalize=s=>s.replaceAll('\r\n','\n');
const archive=readFileSync(new URL('./m7-core-final-before.json.gz',import.meta.url));
assert.equal(hash(archive),'430bd33b94081665bcaadfcc284cf4c4fd019b3f4c84f44195d898e4083c8318');
const bytes=gunzipSync(archive);
assert.equal(hash(bytes),'2fed5ab1fc60b5c01373ef1e5bbd983116e588f8bbb209e71987979850206749');
export const m7FinalBefore=JSON.parse(bytes);
assert.equal(m7FinalBefore.revision,'c685409d7d34d91cae79e917090fe4299184ca8b');
assert.deepEqual(Object.keys(m7FinalBefore.files),['abyss_original_v4','abyss_combat','abyss_codex_relic']);
const files={};
for(const [name,file]of Object.entries(m7FinalBefore.files)){
 assert.equal(file.source,normalize(file.source));assert.equal(hash(file.source),file.sha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(file.source)+'\0'+file.source).digest('hex'),file.gitBlob);
 files['src/lua/'+name+'.lua']=Object.freeze(file);
}
Object.freeze(m7FinalBefore.files);Object.freeze(m7FinalBefore);Object.freeze(files);
const readLive=p=>readFileSync(p,'utf8'),rawReaders=new WeakMap();
const matches=(path,s)=>typeof s==='string'&&Object.hasOwn(files,path)&&hash(normalize(s))===files[path].afterSha256;
export function preM7FinalSource(path,source,{readSource=readLive}={}){
 if(!matches(path,source))return source;
 assert.equal(typeof readSource,'function','final M7 linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 for(const owner of Object.keys(files)){
  let current;try{current=readSource(owner);}catch(error){assert.fail('final M7 linked owner missing: '+owner+': '+String(error?.message??error));}
  assert(matches(owner,current),'final M7 linked owner identity: '+owner);
 }
 return files[path].source;
}
export function m7FinalReader(readSource=readLive){
 assert.equal(typeof readSource,'function','final M7 linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preM7FinalSource(path,readSource(path),{readSource});
 rawReaders.set(reader,readSource);return reader;
}
