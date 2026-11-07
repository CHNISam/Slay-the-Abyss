// Exact one-owner EndTurn epoch. Keep the original full source and the older
// lifecycle oracle intact; every authorization rereads the current owner.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const path='src/lua/abyss_end_turn_powers.lua';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const before=normalize(readFileSync(new URL('../fixtures/end-turn-responsibilities-before.lua',import.meta.url),'utf8'));
assert.equal(hash(before),'0f8881d917f93efb26c7b53f67545c05e6c4f39b43b1694bc3d3d6080173ebda');
assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0'+before).digest('hex'),'aba3f7fdbf7b675b84fc330ac1d4d3a14fe1362c');
const afterSha256='3124970981b679dd4964a7805a6b28277a286cf83b1dc0601e1e0e79ca4de527';
const matches=(p,s)=>p===path&&typeof s==='string'&&hash(normalize(s))===afterSha256;
const readLive=p=>readFileSync(p,'utf8'),rawReaders=new WeakMap();
export function preEndTurnResponsibilitiesSource(p,source,{readSource=readLive}={}){
 if(!matches(p,source))return source;
 assert.equal(typeof readSource,'function','EndTurn linked reader must be a function');
 readSource=rawReaders.get(readSource)??readSource;
 assert(matches(path,readSource(path)),'EndTurn current owner identity');
 return before;
}
export function endTurnResponsibilitiesReader(readSource=readLive){
 assert.equal(typeof readSource,'function','EndTurn linked reader must be a function');
 if(rawReaders.has(readSource))return readSource;
 const reader=p=>preEndTurnResponsibilitiesSource(p,readSource(p),{readSource});
 rawReaders.set(reader,readSource);return reader;
}
