import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync,readFileSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {luaString} from '../scripts/build-lua-data.mjs';
import {monsterEnabledLua} from './helpers/monster-enabled-ui.mjs';
const runLua=monsterEnabledLua({fullCatalog:true});
const fixture='tests/lua/support/native_monster_multi_instance.lua';
for (const name of ['six-duplicate-geometry','six-mixed-exact-art','normal-middle-death','fast-contact-rgb-death','failed-dynamic-art-isolation','real-summons-no-render-rng','source-summon-insertion']) {
 test(`dynamic original monster contract: ${name}`,()=>{
  const result=runLua(fixture,{caseName:name});
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`MULTI_INSTANCE_PASS ${name}`));
 });
}
test('real middle-death feedback rejects severing only actorPainter to native-art forwarding',()=>{
 const source=readFileSync('src/lua/abyss_feedback_actor_painter.lua','utf8');
 const hook='MonsterArt.pose(box,x,y,sx,sy,tone,alpha)';
 assert.equal(source.split(hook).length,2,'one exact production forwarding call');
 const directory=mkdtempSync(join(tmpdir(),'abyss-dynamic-monster-painter-'));
 try {
  const script=join(directory,'painter.lua');
  writeFileSync(script,`package.preload.abyss_feedback_actor_painter=function()return assert(load(${luaString(source.replace(hook,'-- mutation: omit forwarding only'))},'@mutated-actor-painter'))()end\nABYSS_MUTATION_CASE='normal-middle-death'\ndofile(${luaString(fixture)})\n`);
  const result=runLua(script);assert.notEqual(result.status,0);
  assert.match(result.stderr,/real actorPainter death pose must reach native middle drawing/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
