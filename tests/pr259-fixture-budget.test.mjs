import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=text=>createHash('sha256').update(text).digest('hex');
const lua='tests/lua/';
const held=['looter_potion_ui_held.lua',...Array.from({length:4},(_,i)=>`looter_potion_ui_held_slice_${i+2}.lua`)];
const released=['looter_potion_ui_released.lua',...Array.from({length:4},(_,i)=>`looter_potion_ui_released_slice_${i+2}.lua`)];
const rollback=['run_turn_reward_rollback.lua','run_turn_reward_rollback_choice.lua','run_turn_reward_rollback_retain.lua'];
const frozen={held:'33452a04a83845dde9245e29cdbbddc677cdf1a76622712e3b98c329d098a1f7',
 helper:'e6caed3bfcd76916758d6a4a2ed91a8654a3a216824f36c41b2f3f9a6162ffa7',
 released:'a94564d0d34467ef3c240333365d83a57cc810a5626aa382f15ed414ea70fcd8',
 rollback:'e0e3ca30e53838d1feef2ce3690fa6f682cce5d77a7eed87b0c600ae4362fd4f'};
const rollbackHeader="local activeKind=... or 'turn'\nassert(activeKind=='turn'or activeKind=='choice'or activeKind=='retain','invalid rollback budget slice')\n";
const selectedHeader=" assert(selected==nil or type(selected)=='number'and selected%1==0 and selected>=1 and selected<=5,'invalid held budget slice')\n local executed=0\n";
function restoreHelper(source){return source
 .replace('changedRewardActions(released,selected)','changedRewardActions(released)')
 .replace(selectedHeader,'').replace('for index,name in ipairs(','for _,name in ipairs(')
 .replace('  if selected==nil or index==selected then\n','')
 .replace('   executed=executed+1\n','').replace('  end -- held budget boundary\n','').replace(' return executed\n','');}
function restoreRollback(source){return source.replace(rollbackHeader,'').replace('for _,kind in ipairs({activeKind})do',"for _,kind in ipairs({'turn','choice','retain'})do");}

test('budget split retains all original held and rollback bodies, source seeds, assertions and released coverage',()=>{
 const heldSource=read(lua+held[0]);
 assert.ok(heldSource.startsWith('local selected=... or 1\n'),'held fixture must have an explicit bounded split');
 assert.equal(sha(heldSource.replace('local selected=... or 1\n','')
  .replace("assert(F.changedRewardActions(false,selected)==5,'five original held changes per slice')",'F.changedRewardActions(false)')),frozen.held);
 const helper=read(lua+'support/looter_potion_ui_fixture.lua');assert.equal(sha(restoreHelper(helper)),frozen.helper);
 const original=read(lua+rollback[0]);assert.ok(original.includes(rollbackHeader));assert.equal(sha(restoreRollback(original)),frozen.rollback);
 const releasedSource=read(lua+released[0]);
 assert.ok(releasedSource.startsWith('local selected=... or 1\n'),'released fixture must have the same explicit bounded split');
 assert.equal(sha(releasedSource.replace('local selected=... or 1\n','')
  .replace("assert(F.changedRewardActions(true,selected)==5,'five original released changes per slice')",'F.changedRewardActions(true)')),frozen.released);
 assert.notEqual(sha(restoreHelper(helper.replace("Run.new(H.F.Data,42)","Run.new(H.F.Data,43)"))),frozen.helper,'seed drift must be detected');
 assert.notEqual(sha(restoreRollback(original.replace('verify();eq(run.phase',"eq(run.phase"))),frozen.rollback,'removing rollback verification must be detected');
 assert.match(read('scripts/test-lua.mjs'),/timeout \?\?= normalizedScript\.endsWith\('tests\/lua\/encounter_coverage\.lua'\) \? 120000 : mapProperties \? 120000 : fixture \|\| composedHost \? 60000 : 30000;/,
  'raw discovery keeps the original default 30s budget; these files have no timeout exception');
});

test('budget split raw discovery and wrappers select every held/released control and rollback kind exactly once',()=>{
 const actual=readdirSync(lua).filter(f=>/^looter_potion_ui_(?:held|released)(?:_slice_\d+)?\.lua$/.test(f)||/^run_turn_reward_rollback(?:_choice|_retain)?\.lua$/.test(f));
 assert.deepEqual(actual.sort(),[...held,...released,...rollback].sort());
 for(let i=1;i<held.length;i++)assert.equal(read(lua+held[i]),`assert(loadfile('tests/lua/looter_potion_ui_held.lua'))(${i+1})\n`);
 for(let i=1;i<released.length;i++)assert.equal(read(lua+released[i]),`assert(loadfile('tests/lua/looter_potion_ui_released.lua'))(${i+1})\n`);
 for(const kind of ['choice','retain'])assert.equal(read(lua+`run_turn_reward_rollback_${kind}.lua`),`assert(loadfile('tests/lua/run_turn_reward_rollback.lua'))('${kind}')\n`);
 assert.match(read(lua+held[0]),/local selected=\.\.\. or 1/);assert.match(read(lua+rollback[0]),/local activeKind=\.\.\. or 'turn'/);
});

for(const file of [...held,...released,...rollback])test(`PR259 original coverage within unchanged 30s: ${file}`,()=>{
 const result=runLua(lua+file,{timeout:30_000});
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,file.startsWith('run_turn')?/RUN_TURN_REWARD_ROLLBACK 2 passed; 0 failed/:/LOOTER_POTION_UI_(?:HELD|RELEASED) 1 passed 0 failed/);
});
