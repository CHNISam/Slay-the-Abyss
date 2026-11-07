// A single-owner extraction epoch. Never update the older 391-source proof.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
export const defectPlanPath='src/lua/abyss_defect_engine_cards.lua';
export const defectPlanBefore=normalize(readFileSync(new URL('./defect-plan-before.lua',import.meta.url),'utf8'));
assert.equal(hash(defectPlanBefore),'ecfccd24cac9aa6010555d4ac4d2502a75837e2ccfee4dc291aa511b494f76c0');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(defectPlanBefore)+'\0'+defectPlanBefore).digest('hex'),'f1d8c87575db5e2bb7bda8ac05275a152929f67b');
const after='4d9a0281fdd42f853d6a836f485d56d0693996577287ba2ec5283c222cd17ac7';
const matches=(path,source)=>path===defectPlanPath&&typeof source==='string'&&hash(normalize(source))===after;
const live=path=>readFileSync(path,'utf8'),rawReaders=new WeakMap();
export function preDefectPlanSource(path,source,{readSource=live}={}){
 if(!matches(path,source))return source;
 assert.equal(typeof readSource,'function','Defect plan linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 let current;try{current=readSource(path);}catch(error){assert.fail('Defect plan linked owner missing: '+String(error?.message??error));}
 assert(matches(path,current),'Defect plan linked owner identity');
 return defectPlanBefore;
}
export function defectPlanReader(readSource=live){
 assert.equal(typeof readSource,'function','Defect plan linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=path=>preDefectPlanSource(path,readSource(path),{readSource});
 rawReaders.set(reader,readSource);return reader;
}

// Only verified moved assert sites; thrown values themselves are never changed.
export const defectPlanErrorSites=Object.freeze([
 [
  166,
  168,
  "assert(effect.value==1,'unsupported Steam decrement')",
  "unsupported Steam decrement"
 ],
 [
  167,
  169,
  "local c=instanceByUid(state,context.uid or (state.cardInUse and state.cardInUse.uid));assert(c.cardId=='steam_barrier','wrong Steam instance')",
  "wrong Steam instance"
 ],
 [
  170,
  174,
  "assert(effect.value==1,'unsupported Streamline decrement')",
  "unsupported Streamline decrement"
 ],
 [
  171,
  175,
  "local c=instanceByUid(state,context.uid or (state.cardInUse and state.cardInUse.uid));assert(c.cardId=='streamline','wrong Streamline instance')",
  "wrong Streamline instance"
 ],
 [
  179,
  185,
  "assert(effect.value==3 or effect.value==4,'invalid Aggregate divisor')",
  "invalid Aggregate divisor"
 ],
 [
  182,
  190,
  "assert(type(effect.enabled)=='boolean' and effect.fixed==true,'Auto Shields not prepared')",
  "Auto Shields not prepared"
 ],
 [
  185,
  195,
  "assert(effect.normalAmounts,'Blizzard not prepared');p.top[1]=e('damageAll',integer(effect.value),{normalAmounts=copy(effect.normalAmounts)})",
  "Blizzard not prepared"
 ],
 [
  187,
  199,
  "assert(effect.orbs and #effect.orbs==effect.value,'Chaos not prepared')",
  "Chaos not prepared"
 ],
 [
  188,
  200,
  "for _,kind in ipairs(effect.orbs)do assert(kinds[kind],'invalid prepared Chaos orb');p.top[#p.top+1]=channel(kind)end",
  "invalid prepared Chaos orb"
 ],
 [
  199,
  219,
  "local rng=Random.cloneState(assert(state.cardRandomRng,'random attack requires cardRandomRng'))",
  "random attack requires cardRandomRng"
 ],
 [
  206,
  228,
  "assert(integer(effect.normalAmount) and context.target,'Sunder not prepared')",
  "Sunder not prepared"
 ],
 [
  212,
  238,
  "assert(effect.value==0 or effect.value==1,'invalid X upgrade bonus')",
  "invalid X upgrade bonus"
 ],
 [
  214,
  240,
  "assert(context.freeToPlayOnce==nil or type(context.freeToPlayOnce)=='boolean','invalid X free flag')",
  "invalid X free flag"
 ],
 [
  215,
  241,
  "assert(not context.chemicalX or context.chemicalX==0,'Chemical X context override unsupported')",
  "Chemical X context override unsupported"
 ],
 [
  223,
  253,
  "integer(effect.remaining,1);assert(kinds[effect.orb],'invalid channel repetition')",
  "invalid channel repetition"
 ]
].map(Object.freeze));
export function verifyDefectPlanErrorSites(current){
 const old=defectPlanBefore.split('\n'),now=normalize(current).split('\n');
 for(const [a,b,line]of defectPlanErrorSites){assert.equal(old[a-1].trim(),line);assert.equal(now[b-1].trim(),line);}
}
export function comparableDefectPlanError(value){
 if(typeof value!=='string')return value;
 for(const [a,b,,body]of defectPlanErrorSites)if(value===`${defectPlanPath}:${b}: ${body}`)return `${defectPlanPath}:${a}: ${body}`;
 return value;
}
