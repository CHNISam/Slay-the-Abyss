import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {shardLuaScripts} from '../scripts/test-lua.mjs';

const semanticFile='tests/lua/phase_four_presentation.lua';
const renderFile='tests/lua/phase_four_presentation_render.lua';
const helperFile='tests/lua/support/phase_four_presentation_data.lua';
const read=file=>readFileSync(file,'utf8').replaceAll('\r\n','\n');
const digest=text=>createHash('sha256').update(text.trim()).digest('hex');
function between(source,start,end) {
  const first=source.indexOf(start),last=source.indexOf(end,first+start.length);
  assert.ok(first>=0 && last>first, 'missing frozen case boundary');
  return source.slice(first,last);
}

// f17da73ad4fced1f68264efc12f4ef1a4deb6668: retain every original assertion,
// all four class/base+upgrade loops, the 69-card manifest and frozen hash.
// This guard does not rerun the expensive matrix during the JS test stage.
test('phase-four presentation keeps every original case in discovered original-budget fixtures',()=>{
  const discovered=readdirSync('tests/lua').filter(file=>file.endsWith('.lua')).map(file=>'tests/lua/'+file);
  for(const file of [semanticFile,renderFile]) assert.ok(discovered.includes(file), 'missing discovered fixture: '+file);
  const shards=Array.from({length:4},(_,i)=>shardLuaScripts(discovered,(i+1)+'/4')).flat();
  for(const file of [semanticFile,renderFile]) assert.equal(shards.filter(path=>path===file).length,1);
  const semantics=read(semanticFile),render=read(renderFile),helper=read(helperFile);
  assert.equal(digest(between(semantics,"test('all sixty-nine",'local function show(')),
    'e8278f054ba02df89309f2eaa9157d67b6d71f2453600c168da2e70717f275c6');
  assert.equal(digest(between(semantics,'local function show(','eq(cases,17)')),
    'dc6a6331d85f4d45c1f9e71fcdeb2c748468e71030cd5a2c54884b57afe53617');
  assert.equal(digest(between(render,"for _,id in ipairs({'ironclad'",'eq(cases,4)')),
    '5d81554b8627f70e07a3190547e56fc33fce9c2b5c2152f5843452690d87d1e4');
  assert.equal(digest(between(helper,'local function has(','return prepared')),
    'd7808869e291be598e4be80a5b3dae56c684f038a9bfcc123f5f74f7cac9aaa0');
  assert.deepEqual([...semantics.matchAll(/^test\('([^']+)'/gm)].map(row=>row[1]),[
  "all sixty-nine new regular cards and required derivative are present exactly once",
  "source-driven conditions and generated cards do not trust arbitrary text",
  "phase-three damage and next-turn block use actual modified previews",
  "Halt displays actual total and Brilliance captures Mantra once",
  "Bane nested conditional damage has its own exact dynamic token",
  "six card-trigger powers describe conditions and retain innate upgrades",
  "877c4af forty-card historical input keeps its prepared wording unchanged",
  "unknown operations statuses conditions and nested branches still reject",
  "phase-four per-hit damage uses real modifiers for every new attack op",
  "phase-four conditional and repeated Block use actual Dexterity and Frail",
  "orb history and permanent instance changes feed the shared dynamic preview",
  "random attack text does not pretend the selected enemy is every random target",
  "new targeted operations request a live enemy while random and self actions do not",
  "actual HP-loss and card reuse update displayed cost and Glass Knife damage",
  "new X cards and upgrade flags communicate count rather than fake flat zero",
  "all phase-four effects are validated even if arbitrary card text is supplied",
  "877c4af frozen inputs replay the unchanged 165-card and eleven-auxiliary display hash"
]);
  for(const [source,label] of [[semantics,'phase_four_presentation'],[render,'phase_four_presentation_render']]) {
    assert.ok(source.includes("local function test(name,fn)fn();cases=cases+1;print('ok "+label+" '..cases..' - '..name)end"));
    assert.ok(source.includes("local prepared=dofile('tests/lua/support/phase_four_presentation_data.lua')"));
  }
  assert.match(semantics,/eq\(cases,17\)\nprint\('phase_four_presentation: '/);
  assert.match(render,/eq\(cases,4\);eq\(rendered,602\)\nprint\('phase_four_presentation_render: '/);
});
