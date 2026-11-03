import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';

test('M9 old protocol bodies are authenticated to the accepted aa4d56f5 source',()=>{
  const source=readFileSync('tests/lua/support/m9_combat_protocol_baseline.lua','utf8').replaceAll('\r\n','\n');
  const body=source.slice(source.indexOf('local function beginQueuedPlay('),source.lastIndexOf('\nreturn {begin='));
  assert.equal(createHash('sha256').update(body).digest('hex'),'64f9aad95289223b8ed6f66c7ac2a79306c12209a7ceb460ba3095fcecc9308c');
});

test('M9 preserves both complete use preparation graphs and ordered protocol traces',()=>{
  const result=runLua('tests/lua/m9_combat_protocols.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/M9_COMBAT_PROTOCOLS 14 old\/new complete graph trajectories passed/);
});

const mutations=[
  ['native retained reaction array is not cleared','abyss_combat_native_play',
    'for i=#reactions,1,-1 do reactions[i]=nil end','-- mutation: leave captured reactions for double execution'],
  ['advanced multihit forgets physical hit expansion','abyss_combat_queued_play',
    'for _=1,count do actions[#actions+1]={kind=\'effect\',effect=copy(e)}end',
    "actions[#actions+1]={kind='effect',effect=copy(e)}"],
  ['paused play is finalized early','abyss_combat_queued_play',
    "if queue.run(state,hooks.handlers)~='pause'then hooks.finish(state)end",
    "queue.run(state,hooks.handlers);hooks.finish(state)"],
  ['use hook replaces the originally captured target','abyss_combat_queued_play',
    'actionsFor(combat,state,uid,target,instance,card,enemies,uncommon)\n    hooks.queueUseCopies',
    'actionsFor(combat,state,uid,state.enemies[targetIndex],instance,card,enemies,uncommon)\n    hooks.queueUseCopies'],
];
for(const [name,module,before,after] of mutations)test(`M9 trajectory rejects mutation: ${name}`,()=>{
  const source=readFileSync(`src/lua/${module}.lua`,'utf8').replaceAll('\r\n','\n');
  assert.equal(source.split(before).length,2,'one exact mutation site');
  const directory=mkdtempSync(join(tmpdir(),'abyss-m9-combat-'));
  const script=join(directory,'mutation.lua');
  try{
    writeFileSync(script,"package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\n"
      +`package.loaded[${luaString(module)}]=assert(load(${luaString(source.replace(before,after))}))()\n`
      +"dofile('tests/lua/m9_combat_protocols.lua')\n");
    const result=runLua(script);
    assert.notEqual(result.status,0,'mutant must fail the same complete graph contract');
    assert.match(result.stderr,/state\./,'fails a state/alias/trace assertion, not loading or syntax');
  }finally{rmSync(directory,{recursive:true,force:true});}
});
