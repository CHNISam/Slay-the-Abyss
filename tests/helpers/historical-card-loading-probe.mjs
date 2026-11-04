// Observe the real module loader and the original filesystem reads in a fresh
// process. Faults affect only this process; no source/archive file is modified.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {syncBuiltinESMExports} from 'node:module';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';

const mode=process.argv[2];
assert.ok(['helper','runner','active','warm-faults'].includes(mode));
const read=fs.readFileSync,parse=JSON.parse,reads=[];
let fault,parsedBytes=0;
fs.readFileSync=function(path,...args){
 const name=(path instanceof URL?fileURLToPath(path):String(path)).replaceAll('\\','/');
 if(name.includes('/tests/fixtures/'))reads.push(name);
 if(name.endsWith('/pr323-historical-fixtures.json.gz')){
  if(fault==='missing')throw Object.assign(new Error('original archive unavailable'),{code:'ENOENT'});
  if(fault==='corrupt')return Buffer.from('corrupt original archive');
 }
 return read.call(this,path,...args);
};
JSON.parse=function(source,...args){parsedBytes+=Buffer.byteLength(String(source));return parse.call(this,source,...args);};
syncBuiltinESMExports();
const started=performance.now();
const helper=await import('./historical-card-input.mjs');
if(mode==='runner')await import('../../scripts/test-lua.mjs');
const importMs=performance.now()-started;
const cold={reads:[...reads],parsedBytes};
assert.ok(Object.isFrozen(helper.historicalCardInputFixtures));
assert.equal((await import('./historical-card-input.mjs')).historicalCardInputPrelude,helper.historicalCardInputPrelude);
const forbidden=()=>{throw Error('unselected entry must not read sources');};
for(const script of ['tests/lua/combat.lua','tests/lua/card_input_port_slice_4.lua','tests/lua/card_input_port.lua.extra'])
 assert.equal(helper.historicalCardInputPrelude(script,{readSource:forbidden}),'');
for(const script of helper.historicalCardInputFixtures)
 assert.equal(helper.historicalCardInputPrelude(script,{cwd:resolve('foreign-source-root'),readSource:forbidden}),'');
const warm={reads:[...reads],parsedBytes};
let historical;
if(mode==='active'||mode==='warm-faults'){
 const outputs=helper.historicalCardInputFixtures.map(script=>helper.historicalCardInputPrelude(script));
 for(const value of outputs){assert.equal(typeof value,'string');assert.match(value,/HISTORICAL_CARD_INPUT_PRE_BROWSE/);}
 assert.equal(new Set(outputs).size,1);
 historical={sha256:createHash('sha256').update(outputs[0]).digest('hex'),bytes:Buffer.byteLength(outputs[0]),reads:reads.length};
 if(mode==='warm-faults'){
  for(const kind of ['missing','corrupt']){
   fault=kind;
   for(const script of helper.historicalCardInputFixtures)
    assert.throws(()=>helper.historicalCardInputPrelude(script),kind==='missing'?/original archive unavailable/:/header|gzip|compression/i);
  }
  fault=undefined;
  assert.equal(helper.historicalCardInputPrelude(helper.historicalCardInputFixtures[0]),outputs[0],'failed archive reads do not poison a later fresh call');
 }
}
fs.readFileSync=read;JSON.parse=parse;syncBuiltinESMExports();
process.stdout.write(JSON.stringify({mode,importMs,cold,warm,historical})+'\n');
