import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import luaparse from 'luaparse';
import {runStatic} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {actorLifecycleBefore,verifyActorLifecycleBefore,runActorLifecycle} from './helpers/actor-lifecycle.mjs';

test('frozen Actor identity accepts LF and CRLF but rejects semantic source drift',()=>{
  const source=actorLifecycleBefore();
  assert.equal(verifyActorLifecycleBefore(Buffer.from(source)),source);
  assert.equal(verifyActorLifecycleBefore(Buffer.from(source.replaceAll('\n','\r\n'))),source);
  assert.throws(()=>verifyActorLifecycleBefore(Buffer.from(source.replace('local M = {}','local M = {changed=true}'))),/complete frozen Actor source/);
});

test('Actor lifecycle complete frozen source matches independent VM state graph and failure trace',()=>{
  const before=runActorLifecycle(actorLifecycleBefore()),after=runActorLifecycle();
  assert.equal(before.status,0,before.stdout+before.stderr);
  assert.equal(after.status,0,after.stdout+after.stderr);
  assert.match(after.stdout,/ACTOR_LIFECYCLE_PASS /);
  assert.equal((after.stdout.match(/^ACTOR_LIFECYCLE_CHECKPOINT /gm)??[]).length,14,
    'explicit trace mode must transport every complete scenario checkpoint');
  assert.match(after.stdout,/^table:\d+\{/m,'trace must include complete table definitions');
  const functionDefinition=/^function:(\d+)\{\}meta=/m.exec(after.stdout);
  assert(functionDefinition,'graph must contain an actual function definition');
  assert((after.stdout.match(new RegExp(`function:${functionDefinition[1]}(?![0-9])`,'g'))??[]).length>=4,
    'same function must appear through state, anchors and nested references');
  assert.equal(after.stdout,before.stdout,'complete graph, aliases, RNG, events, returns and errors');
});
test('Actor lifecycle default raw discovery retains every scenario without graph transport',()=>{
  const result=runLua('tests/lua/actor_lifecycle.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.equal(result.stdout.trim(),'ACTOR_LIFECYCLE_PASS 121',
    'raw default runs every step within the unchanged runLua output budget');
});
test('Actor lifecycle entry points and every added function have complete CC15 measurements',()=>{
  const measured=measureSources(discoverSources(),runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics);
  assert.deepEqual(measured.errors,[]);
  const actor=measured.modules.find(m=>m.file==='src/lua/abyss_actor.lua');
  const rules=measured.modules.find(m=>m.file==='src/lua/abyss_actor_power_rules.lua');
  assert(rules,'complete rules leaf measurements');
  assert(actor.lines<=1000,`Actor ${actor.lines} exceeds 1000 physical lines`);
  assert(rules.lines<=1000,`Power rules ${rules.lines} exceeds 1000 physical lines`);
  for(const f of rules.functions)assert(f.complexity<=15,`PowerRules ${f.name}: CC${f.complexity} exceeds 15`);
  const beforeNames=new Set();
  function visit(node){if(!node||typeof node!=='object')return;if(node.type==='FunctionDeclaration'&&node.identifier?.type==='Identifier')beforeNames.add(node.identifier.name);for(const child of Object.values(node)){if(Array.isArray(child))child.forEach(visit);else if(child&&typeof child==='object')visit(child);}}
  visit(luaparse.parse(actorLifecycleBefore(),{luaVersion:'5.3'}));
  const entries=['M.status','M.applyPower','M.addStatus','M.endTurn'];
  for(const name of entries)assert.equal(actor.functions.filter(f=>f.name===name).length,1,`complete ${name}`);
  for(const f of actor.functions.filter(f=>f.kind==='chunk'||entries.includes(f.name)||!beforeNames.has(f.name)&&!f.name.startsWith('M.')))
    assert(f.complexity<=15,`${f.name}: CC${f.complexity} exceeds 15`);
});

test('Actor Power rules load independently and expose pure nonmutable rule functions',()=>{
  const result=runLua('tests/lua/actor_lifecycle_rules.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/ACTOR_POWER_RULES_PASS/);
});

test('parsed lifecycle semantic mutations change real graph and return traces',()=>{
  const source=readFileSync('src/lua/abyss_actor.lua','utf8').replaceAll('\r\n','\n');
  const rulesSource=readFileSync('src/lua/abyss_actor_power_rules.lua','utf8').replaceAll('\r\n','\n');
  const baseline=runActorLifecycle(actorLifecycleBefore());
  assert.equal(baseline.status,0,baseline.stdout+baseline.stderr);
  const mutations=[
    ['Poison constructor bonus','amount=amount+0.0+bonus','amount=amount+0.0'],
    ['signed clamp','value = math.max(-999, math.min(999, value))','value = math.max(-998, math.min(998, value))','rules'],
    ['owner acquisition order',
      'local endings,seen = {},{}\n    for _,id in ipairs(actor.powerOrder or {}) do',
      'local endings,seen = {},{}\n    for i=#(actor.powerOrder or {}),1,-1 do local id=actor.powerOrder[i]'],
    ['temporary debt clearing before application',
      'M.applyPower(state, actor, id, -temporary, actor)\n        actor[field] = 0',
      'actor[field] = 0\n        M.applyPower(state, actor, id, -temporary, actor)'],
    ['dynamic owner-end dispatch',
      'local function settleOwnerEndPower(state,actor,id)',
      'local cachedOwnerEndApplyPower=M.applyPower\nlocal function settleOwnerEndPower(state,actor,id)'],
    ['zero Power membership',"local zeroMembership=id=='slow' or id=='time_warp' or id=='invincible'","local zeroMembership=false"],
  ];
  for(const [label,before,after,target='actor'] of mutations){
    const original=target==='rules'?rulesSource:source;
    assert.equal(original.split(before).length,2,`${label}: unique mutation site`);
    let mutant=original.replace(before,after);
    if(label==='dynamic owner-end dispatch'){
      const start=mutant.indexOf('local function settleOwnerEndPower'),end=mutant.indexOf('local function clearTemporaryPowerOrder',start);
      mutant=mutant.slice(0,start)+mutant.slice(start,end).replaceAll('M.applyPower(','cachedOwnerEndApplyPower(')+mutant.slice(end);
    }
    assert.doesNotThrow(()=>luaparse.parse(mutant,{luaVersion:'5.3'}),`${label}: parsed executable mutant`);
    const result=target==='rules'?runActorLifecycle(undefined,mutant):runActorLifecycle(mutant);
    assert.equal(result.status,0,`${label}: scenario must finish; no infrastructure/runtime-error kill\n${result.stderr}`);
    assert.match(result.stdout,/ACTOR_LIFECYCLE_PASS /,`${label}: every scenario completed`);
    assert(result.stdout!==baseline.stdout,`${label}: real behavioral graph mutation survived`);
  }
});
