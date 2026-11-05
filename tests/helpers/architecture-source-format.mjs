// Pure formatting only: callers still execute every projection and proof guard.
// Exact source strings (not parsed values/digests) distinguish all token drift.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preGameUiExtractionSource} from './game-ui-extraction-source-inverse.mjs';
const cache=new Map();
const tokens=text=>text.replace(/"(?:\\.|[^"\\])*"|[ \t\r\n]+/g,token=>token.startsWith('"')?token:'');
const hash=text=>createHash('sha256').update(text).digest('hex');
export function architectureSourceFormat(path,source){
 const cacheable=path==='config/architecture.json'&&typeof source==='string';
 if(cacheable&&cache.has(source))return cache.get(source);
 const formatted=JSON.stringify(JSON.parse(source),null,2)+'\n';
 const result=Object.freeze({formatted,tokensEqual:tokens(source)===tokens(formatted)});
 if(cacheable){
  if(cache.size===8)cache.delete(cache.keys().next().value);
  cache.set(source,result);
 }
 return result;
}

// Exact outer inverse of the LivingWall copy-only boundary. It is deliberately
// in this file: detached historical hosts already copy this formatting owner.
// A warm token cache never substitutes for the fresh linked production bytes.
function isLivingWallArchitectureSource(source){
 const {formatted,tokensEqual}=architectureSourceFormat('config/architecture.json',source);
 return tokensEqual&&hash(formatted)==='b34a39a6e244d8b5c3da3dfa03ba2dc1a41af60e8fd0f311cc402774312c625c';
}
function livingWallCopyInverse(source,live){
 if(!isLivingWallArchitectureSource(source)
   ||hash(live)!=='e50c2b19ba16cc334bc438ab3fcceb4b1fba822caf094076325ca7fcaacd6e11')return source;
 const boundary='    {\n      "id": "living-wall-copy-isolation",\n      "from": ["abyss_living_wall"],\n      "forbiddenTargets": ["abyss_combat"],\n      "reason": "Living Wall filters detached card copies through Foundation; Session commands remain owned by Run."\n    },\n';
 assert.equal(live.split(boundary).length,2,'one complete reviewed LivingWall boundary');
 const previous=live.replace(boundary,'');
 assert.equal(hash(previous),'f610861cba597e017340433a1d0dcdc4930745bcbe0347ec24facdb3630bf96a',
  'complete pre-LivingWall architecture identity');
 return previous;
}
export function preLivingWallCopyArchitecture(path,source){
 source=preGameUiExtractionSource(path,source);
 if(path!=='config/architecture.json'||typeof source!=='string')return source;
 try{
  if(!isLivingWallArchitectureSource(source))return source;
  const live=preGameUiExtractionSource(path,readFileSync(new URL('../../config/architecture.json',import.meta.url),'utf8').replaceAll('\r\n','\n'));
  return livingWallCopyInverse(source,live);
 }catch{return source;}
}

// Exact outer inverse of PR511's three architecture changes. Keep all older
// complete-byte witnesses untouched. Layout-only inputs still require the
// current full token identity and a fresh, complete linked production file.
export function preCombatReactionArchitecture(path,source){
 source=preGameUiExtractionSource(path,source);
 if(path!=='config/architecture.json'||typeof source!=='string')return source;
 try{
  if(!isLivingWallArchitectureSource(source))return source;
  const linked=preGameUiExtractionSource(path,readFileSync(new URL('../../config/architecture.json',import.meta.url),'utf8').replaceAll('\r\n','\n'));
  const current=livingWallCopyInverse(source,linked);
  // A missing outer guard is not permission to enter an older proof epoch.
  if(current===source)return source;
  const {formatted,tokensEqual}=architectureSourceFormat(path,current);
  if(!tokensEqual||hash(formatted)!=='0a0cd90ea0b42968622379ebc3b92c50c3621543dce9210ead805a33b9a7fac1')return source;
  const live=livingWallCopyInverse(linked,linked);
  if(hash(live)!=='f610861cba597e017340433a1d0dcdc4930745bcbe0347ec24facdb3630bf96a')return source;
  const layer='    "abyss_combat_reactions": "core",\n';
  assert.equal(live.split(layer).length,2,'one reviewed reaction registration');
  const boundary=',\n  "dependencyBoundaries": [';
  assert.equal(live.split(boundary).length,2,'one reviewed dependency boundary block');
  let previous=live.slice(0,live.indexOf(boundary))+'\n}\n';
  previous=previous.replace(layer,'');
  const anchor='    {\n      "from": "abyss_actor",\n      "to": "abyss_relic_hooks",';
  assert.equal(previous.split(anchor).length,2,'one reviewed deferred-import insertion point');
  const deferred='    {\n      "from": "abyss_actor",\n      "to": "abyss_card_actions",\n      "reason": "Only enqueue callback bodies run after module initialization; Actor never invokes this import at load time."\n    },\n';
  previous=previous.replace(anchor,deferred+anchor);
  assert.equal(hash(previous),'3cc15d6f573fa5a5c637c2d2a4ef9086f444bb761a64ee1e6aef80dad40d0cc5',
   'complete pre-reaction architecture identity');
  return previous;
 }catch{return source;}
}
