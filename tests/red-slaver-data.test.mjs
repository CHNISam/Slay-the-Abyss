import test from 'node:test';
import assert from 'node:assert/strict';
import {loadContent,validateContent} from '../scripts/validate-data.mjs';
const fixture=()=>{const data=loadContent('data');return {data,e:data.enemies.enemies.find(e=>e.id==='red_slaver')};};
test('Red A0 declares source HP/actions/one-net thresholds and actual Entangle status',()=>{
 const {data,e}=fixture();assert.deepEqual(e.hpRange,{min:46,max:50});
 assert.deepEqual(e.ai,{kind:'red_slaver',stabIntent:'red_slaver_1',entangleIntent:'red_slaver_2',scrapeIntent:'red_slaver_3',rollRange:100,entangleCutoff:75,stabCutoff:55});
 assert.deepEqual(e.intents.map(i=>i.effects),[[{op:'damage',value:13}],[{op:'applyStatus',status:'entangled',value:1}],[{op:'damage',value:8},{op:'applyStatus',status:'vulnerable',value:1}]]);
 const status=data.statuses.statuses.find(s=>s.id==='entangled');assert.equal(status.kind,'debuff');assert.equal(status.stack,'intensity');assert.equal(status.decay,'none');
 assert.deepEqual(validateContent(data),[]);
});
for(const [name,change,expected] of [
 ['unknown field',e=>e.ai.guess=1,/ai.guess/],
 ['missing Stab',e=>delete e.ai.stabIntent,/stabIntent/],
 ['unknown Scrape',e=>e.ai.scrapeIntent='missing',/scrapeIntent/],
 ['unknown net',e=>e.ai.entangleIntent='missing',/entangleIntent/],
 ['duplicate intent',e=>e.ai.scrapeIntent=e.ai.stabIntent,/distinct/],
 ['wrong Stab kind',e=>e.intents[0].kind='buff',/stabIntent/],
 ['wrong net kind',e=>e.intents[1].kind='attack',/entangleIntent/],
 ['fake net Weak',e=>e.intents[1].effects[0].status='weak',/Entangled one/],
 ['zero range',e=>e.ai.rollRange=0,/rollRange/],
 ['fractional net cutoff',e=>e.ai.entangleCutoff=74.5,/entangleCutoff/],
 ['out-of-range Stab cutoff',e=>e.ai.stabCutoff=100,/stabCutoff/],
]) test(`rejects Red ${name}`,()=>{const {data,e}=fixture();change(e);assert.match(validateContent(data).join('\n'),expected);});
