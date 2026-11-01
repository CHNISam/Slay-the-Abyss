import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preRelicCompletionSource} from './helpers/relic-completion-inverse.mjs';
const raw=readFileSync('data/cards.json','utf8').replaceAll('\r\n','\n');
const frozenInput=preRelicCompletionSource('data/cards.json',raw);
const cards=JSON.parse(raw).cards.filter(c=>!['status','curse'].includes(c.type)&&c.rarity!=='special');
const registration=JSON.parse(readFileSync('data/reference/sts1-card-pools/registration.json','utf8')).registration.filter(c=>c.color==='RED');
const fields=['condition','cost','costMode','effects','ethereal','exhaust','exhaustEnergy','healing','innate','rarity','repeatable','sourceId','strengthMultiplier','strikeBonus','strikeTag','target','type','upgrade'];
const pack=v=>typeof v==='string'?'s'+v.length+':'+v:typeof v==='number'?'n'+v+';':typeof v==='boolean'?(v?'t':'f'):
 '{'+(Array.isArray(v)?v.map((x,i)=>[i+1,x]):Object.keys(v).sort().map(k=>[k,v[k]])).map(([k,x])=>pack(k)+pack(x)).join('')+'}';
function fingerprint(c){
 const semantic=Object.fromEntries(fields.filter(k=>c[k]!==undefined).map(k=>[k,c[k]]));
 let a=1,b=7;for(const byte of Buffer.from(pack(semantic),'utf8')){a=(a*31+byte)%2147483647;b=(b*131+byte)%2147483629;}
 return a.toString(16).padStart(8,'0')+b.toString(16).padStart(8,'0');
}
const source=readFileSync('src/lua/abyss_run_red_card_contract.lua','utf8');
function verify(text){
 const rows=[...text.matchAll(/^ ([a-z_]+)='([0-9a-f]{16})',/gm)].map(m=>[m[1],m[2]]);
 assert.equal(rows.length,75);const actual=new Map(rows);assert.equal(actual.size,75);
 assert.ok(text.includes(createHash('sha256').update(frozenInput).digest('hex')),'explicit frozen native input SHA');
 for(const c of cards)assert.equal(actual.get(c.id),fingerprint(c),`native semantic signature for ${c.id}`);
}
test('Run red contract locks exactly75 native semantic signatures against frozen data and independent source identities',()=>{
 assert.equal(cards.length,75);assert.equal(registration.length,75);verify(source);
 for(const c of cards){const row=registration.find(r=>r.id===c.sourceId);assert.ok(row,`fixed registration ${c.id}`);
  assert.equal(c.type,row.type.toLowerCase());assert.equal(c.rarity,row.rarity.toLowerCase());assert.equal(c.healing===true,row.tags.includes('HEALING'));
 }
});
test('wrong but registered signature and modified gameplay fail; display/extension metadata do not enter the lock',()=>{
 const strike=cards.find(c=>c.id==='strike'),defend=cards.find(c=>c.id==='defend');
 assert.throws(()=>verify(source.replace(`strike='${fingerprint(strike)}'`,`strike='${fingerprint(defend)}'`)),/native semantic signature for strike/);
 const modified=structuredClone(strike);modified.effects[0].value=123;assert.notEqual(fingerprint(modified),fingerprint(strike));
 modified.effects[0].value=6;modified.name='任意词条';modified.callerGraph={self:null};modified.callerGraph.self=modified.callerGraph;
 assert.equal(fingerprint(modified),fingerprint(strike));
});
