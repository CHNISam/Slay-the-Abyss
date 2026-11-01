import {historicalCardInputPrelude,historicalCardInputFixtures} from './helpers/historical-card-input.mjs';
import test from 'node:test';
import {readHistoricalBaselineSource,loadHistoricalBaselineInputs} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
import {resolve} from 'node:path';

test('all 12 original source-input groups retain their complete body and run once with the original 30-second budget', () => {
  // Pin the original assertion/name witness; the three executions below still use current files.
  const source = readHistoricalBaselineSource('tests/lua/support/card_input_port_cases.lua').replaceAll('\r\n', '\n');
  const header = 'return function(first,last)\nfirst,last=assert(first),assert(last)\nlocal registered=0\n';
  const gating = '    registered=registered+1\n    if registered<first or registered>last then return end\n';
  const tail = "assert(registered==12 and passed==last-first+1,'source input partition coverage changed')\nend\n";
  assert.ok(source.startsWith(header));
  assert.ok(source.endsWith(tail));
  assert.equal(source.split(gating).length, 2);
  const original = source.slice(header.length, -tail.length).replace(gating, '');
  assert.equal(createHash('sha256').update(original).digest('hex'),
    '62b56bbabbe457f0c6480f576cc2f83d34d71e698d354d0a4644820f2a47fa14');
  const names = [...original.matchAll(/^test\('([^']+)', function\(\)/gm)].map(match => match[1]);
  assert.equal(names.length, 12);
  const seen = [];
  for (const [file, first, last] of [['card_input_port.lua', 1, 6], ['card_input_port_slice_2.lua', 7, 10],
    ['card_input_port_slice_3.lua', 11, 12]]) {
    assert.equal(readFileSync(`tests/lua/${file}`, 'utf8').trim(),
      `dofile('tests/lua/support/card_input_port_cases.lua')(${first},${last})`);
    const result = runLua(`tests/lua/${file}`, { timeout: 30000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const actual = [...result.stdout.matchAll(/^PASS source card input (.+)$/gm)].map(match => match[1]);
    assert.deepEqual(actual, names.slice(first - 1, last));
    seen.push(...actual);
  }
  assert.deepEqual(seen, names);
});

test('only the three frozen input archives load exact pre-browsing gesture semantics',()=>{
 assert.deepEqual(historicalCardInputFixtures,['tests/lua/card_input_port.lua','tests/lua/card_input_port_slice_2.lua','tests/lua/card_input_port_slice_3.lua']);
 const cwd=process.cwd(),inputs=loadHistoricalBaselineInputs();
 const host='src/lua/abyss_battle_card_gestures.lua',linked='src/lua/abyss_monster_intent_particle_view.lua';
 const original=path=>{assert.ok(Object.hasOwn(inputs,path),'complete original input: '+path);return inputs[path].toString('utf8');};
 for(const path of historicalCardInputFixtures){
  // Call the ordinary current-cwd API, as runLua does. Only its explicit
  // historical fixture inputs are old; no test-wide historical cwd can mask a live-reader bug.
  const actual=historicalCardInputPrelude(path);assert.match(actual,/HISTORICAL_CARD_INPUT_PRE_BROWSE/);
  const reads=[];
  assert.equal(historicalCardInputPrelude(path,{cwd,readSource:p=>{reads.push(p);return original(p);}}),actual);
  assert.ok(reads.includes(host)&&reads.includes(linked),'the real inverse validates both host and complete linked owner closure');
  assert.equal(historicalCardInputPrelude(path,{readSource:p=>original(p).replaceAll('\n','\r\n')}),actual,'legal original CRLF sources recover the same exact pre-browsing semantics');
  for(let attempt=0;attempt<2;attempt++){
   assert.throws(()=>historicalCardInputPrelude(path,{readSource:p=>original(p)+(p===host?'\n-- drift':'')}),/unreviewed source-input gesture host/);
   assert.throws(()=>historicalCardInputPrelude(path,{readSource:p=>original(p)+(p===linked?'\n-- drift':'')}),/delivery linked source identity/);
  }
  assert.throws(()=>historicalCardInputPrelude(path,{readSource:p=>{if(p===linked)throw Error('missing original linked owner');return original(p);}}),'missing linked original source cannot fall back to a current or cached owner');
  assert.equal(historicalCardInputPrelude(path,{cwd:resolve(cwd,'unrelated-source-directory'),readSource:()=>{throw Error('foreign cwd must not read inputs');}}),'');
  assert.equal(process.cwd(),cwd,'the current runtime cwd remains unchanged');
 }
 for(const path of ['tests/lua/hand_flick_intent.lua','tests/lua/battle_hand_fan_swipe.lua','tests/lua/aim_visual_parity.lua','tests/lua/card_input_port_slice_4.lua']){
  assert.equal(historicalCardInputPrelude(path),'');
  assert.equal(historicalCardInputPrelude(path,{readSource:()=>{throw Error('current input fixtures must not read historical sources');}}),'');
 }
});
