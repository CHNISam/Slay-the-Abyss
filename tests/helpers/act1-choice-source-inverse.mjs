// A single-owner extraction epoch. Never update the older 391-source proof.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
export const act1ChoicePath='src/lua/abyss_act1_events.lua';
export const act1ChoiceBefore=normalize(readFileSync(new URL('./act1-choice-before.lua',import.meta.url),'utf8'));
assert.equal(hash(act1ChoiceBefore),'5052bec306ea9d3544cf40bd9d1dc1327f61c6608b1557fd13fe3473fbc8ff25');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(act1ChoiceBefore)+'\0'+act1ChoiceBefore).digest('hex'),'4239018ef0204141129b2732883a99c6d971264f');
const after='987a96604109beac3365a8f8daf478b8bf45286921deccc865c96102ae2590c5';
const matches=(path,source)=>path===act1ChoicePath&&typeof source==='string'&&hash(normalize(source))===after;
const live=path=>readFileSync(path,'utf8'),rawReaders=new WeakMap();
export function preAct1ChoiceSource(path,source,{readSource=live}={}){
 if(!matches(path,source))return source;
 assert.equal(typeof readSource,'function','Act1 choice linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 let current;try{current=readSource(path);}catch(error){assert.fail('Act1 choice linked owner missing: '+String(error?.message??error));}
 assert(matches(path,current),'Act1 choice linked owner identity');
 return act1ChoiceBefore;
}
export function act1ChoiceReader(readSource=live){
 assert.equal(typeof readSource,'function','Act1 choice linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preAct1ChoiceSource(path,readSource(path),{readSource});
 rawReaders.set(reader,readSource);return reader;
}

// The sole moved throw observed by the failure fixtures. Compare only this
// exact string in the observation copy; never rewrite the actual thrown value.
const missingDamageBody="attempt to call a nil value (field 'eventDamage')";
export function comparableAct1ChoiceError(value){
 return value===`${act1ChoicePath}:174: ${missingDamageBody}`?`${act1ChoicePath}:177: ${missingDamageBody}`:value;
}
export function verifyAct1ChoiceErrorSite(current){
 const statement='local damaged,damageReason=Run.eventDamage(run,event.damage)';
 assert.equal(act1ChoiceBefore.split('\n')[176].trim(),statement,'original unguarded damage site');
 assert.equal(normalize(current).split('\n')[173].trim(),statement,'moved unguarded damage site');
}
