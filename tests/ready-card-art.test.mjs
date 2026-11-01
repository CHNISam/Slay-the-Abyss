import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {buildReadyCardRegistry, readExportTables} from '../scripts/art/ready-card-registry.mjs';
import {prepareNativeCardArt,nativeArtReceipt} from '../scripts/card-art-samples.mjs';

test('ready registry consumes only the three approved native drawings without enabling source-only cards',()=>{
 const registry=buildReadyCardRegistry();
 assert.deepEqual(Object.keys(registry.assets),['armaments','cleave','heavy_blade']);
 assert.deepEqual(Object.values(registry.assets).map(a=>a.slots.length),[1834,2657,2043]);
 const candidate=prepareNativeCardArt({registry,hosts:['battlePanel/card1']});
 assert.equal(candidate.capacity,2657);
 assert.equal(nativeArtReceipt(candidate).staticAddedControls,2703);
 assert.equal(nativeArtReceipt(candidate).deckTemplateEnabled,false);
 for(const a of Object.values(registry.assets))assert.equal(a.slots.filter(s=>[106056,106057].includes(s.image)).length,3);
});
for(const separator of ['/',String.fromCharCode(92)])test(`frozen registry rejects real byte/approval mutations with ${separator} paths`,()=>{
 const load=p=>readFileSync(p,'utf8');let hits=0;
 const corrupt=(suffix,mutate)=>p=>{
  // Exercise both callback path spellings on every host; read the actual path.
  const spelled=p.replaceAll(String.fromCharCode(92),'/').replaceAll('/',separator);
  if(!spelled.replaceAll(String.fromCharCode(92),'/').endsWith(suffix))return load(p);
  hits++;return mutate(load(p));
 };
 assert.throws(()=>buildReadyCardRegistry({read:corrupt('armaments/native-art.lua',s=>s+'\n')}),/hash/);
 assert.equal(hits,1,'byte negative control must actually alter one source');
 assert.throws(()=>buildReadyCardRegistry({read:corrupt('armaments/asset.json',s=>s.replace('native-redraw','native-pending'))}),/approval/);
 assert.equal(hits,2,'approval negative control must actually alter one source');
});
test('literal table reader does not execute functions, accept aliases or duplicate source bindings',()=>{
 assert.throws(()=>readExportTables('local ROOT = danger()'),/literal|missing/);
 const s=readFileSync('art/cards/traveler-geo/armaments/native-art.lua','utf8');
 assert.throws(()=>readExportTables(s+'\nlocal ROOT = {}'),/duplicate/);
});
test('runtime template capacity remains bounded and source-only IDs are rejected',()=>{
 const registry=buildReadyCardRegistry();
 const rejected=structuredClone(registry);rejected.assets.strike={...rejected.assets.armaments,cardId:'strike'};
 assert.throws(()=>prepareNativeCardArt({registry:rejected,hosts:['battlePanel/card1']}),/candidate assets|identity/);
 assert.throws(()=>prepareNativeCardArt({registry,hosts:['deckPanel/template']}),/unbounded/);
 const over=structuredClone(registry);over.assets.armaments.slots=Array(2658).fill(over.assets.armaments.slots[0]);
 assert.throws(()=>prepareNativeCardArt({registry:over,hosts:['battlePanel/card1']}),/capacity/);
});
