import test from 'node:test';
import assert from 'node:assert/strict';
import luaparse from 'luaparse';
import {actorLifecycleBefore} from './helpers/actor-lifecycle.mjs';
import {runStatic} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';
import {combatLifecycleFile,combatLifecycleHash,combatLifecycleCurrent,combatLifecycleBefore,executeCombatLifecycle} from './helpers/combat-lifecycle-input.mjs';

for(const group of ['damage','draw','owners'])test(`Combat complete lifecycle differential in independent VMs: ${group}`,t=>{
  const before=executeCombatLifecycle(combatLifecycleBefore,group,true);
  const after=executeCombatLifecycle(combatLifecycleCurrent(),group,true);
  for(const result of [before,after]){
    assert.equal(result.status,0,result.stdout.slice(-1500)+result.stderr);
    assert.match(result.stdout,/COMBAT_LIFECYCLE_PASS/);
  }
  assert.ok(before.stdout===after.stdout,`${group}: full state, original references, RNG, event, return/error graph differs`);
  t.diagnostic(`${group}: ${Buffer.byteLength(after.stdout)} bytes, SHA256 ${combatLifecycleHash(after.stdout)}`);
});

test('combined frozen Actor + Combat retain public Run/Combat owner graphs against both current modules',()=>{
  const before=executeCombatLifecycle(combatLifecycleBefore,'owners',true,{actorSource:actorLifecycleBefore()});
  const after=executeCombatLifecycle(combatLifecycleCurrent(),'owners',true);
  for(const result of [before,after])assert.equal(result.status,0,result.stdout.slice(-1500)+result.stderr);
  assert.ok(before.stdout===after.stdout,'combined full state, alias, RNG, events and return/error trajectory');
});

test('Combat damage/draw and every extracted lifecycle responsibility have complete CC15 measurements',()=>{
  const measurements=measureSources(discoverSources(),runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics);
  assert.deepEqual(measurements.errors,[]);
  const module=measurements.modules.find(m=>m.file===combatLifecycleFile);
  const required=['M.damage','draw','damagePoison','damageThornsCallback','damagePreview','recordDamagePreview','completeDamage',
    'notifyDrawShuffle','drawSourcePile','drawVoid','drawStatusPowers','applyDrawHooks'];
  for(const name of required){
    const matches=module.functions.filter(f=>f.name===name);
    assert.equal(matches.length,1,`${name}: mandatory complete measurement`);
    assert(matches[0].complexity<=15,`${name}: CC${matches[0].complexity} exceeds 15`);
  }
  // New anonymous/helper declarations cannot escape the explicit required list.
  const oldNames=new Set(measureSources({[combatLifecycleFile]:combatLifecycleBefore},[]).modules[0].functions.map(f=>f.id));
  for(const fn of module.functions)if(!oldNames.has(fn.id))assert(fn.complexity<=15,`${fn.id}: new responsibility exceeds CC15`);
  assert(module.functions.find(f=>f.kind==='chunk').complexity<=15);
});

function mutateNode(source,owner,predicate,replacement){
  const ast=luaparse.parse(source,{luaVersion:'5.3',ranges:true});
  const named=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.identifier?.name===owner);
  assert(named,`${owner}: real parsed function`);
  const matches=[];
  function visit(node){
    if(!node||typeof node!=='object')return;
    if(predicate(node))matches.push(node);
    for(const [key,value]of Object.entries(node))if(key!=='range'){
      if(Array.isArray(value))value.forEach(visit);else if(value&&typeof value==='object')visit(value);
    }
  }
  visit(named);assert.equal(matches.length,1,`${owner}: unique parsed semantic mutation`);
  const [start,end]=matches[0].range;
  const result=source.slice(0,start)+replacement(source.slice(start,end))+source.slice(end);
  luaparse.parse(result,{luaVersion:'5.3'});return result;
}
test('parsed Envenom, source shuffle, Void and draw-order mutations fail actual lifecycle behavior',()=>{
  const source=combatLifecycleCurrent();
  const call=name=>n=>n.type==='CallStatement'&&n.expression.type==='CallExpression'&&source.slice(...n.expression.base.range)===name;
  const changes=[
    ['fixed Envenom','damage','damagePoison',n=>n.type==='UnaryExpression'&&n.operator==='not'&&n.argument.name==='fixed',()=> 'true',/fixed damage cannot Envenom/],
    ['source shuffle order','draw','drawSourcePile',call('shuffle'),s=>s.replace('shuffle(state, state.discard)','assert(true)'),/one source nextLong per shuffle/],
    ['Void energy','draw','drawVoid',n=>n.type==='AssignmentStatement'&&source.slice(...n.variables[0].range)==='state.energy',()=> 'state.energy=state.energy',/Void energy timing/],
    ['status draw order','owners','drawStatusPowers',n=>n.type==='CallStatement'&&source.slice(...n.expression.base.range)==='CardActions.enqueue'&&source.slice(...n.range).includes("op='draw'"),s=>s.replace('CardActions.enqueue(state,','CardActions.enqueueReaction(state,').replace(/\)$/,',true)'),/BOTTOM draw follows randomization/],
  ];
  for(const group of new Set(changes.map(change=>change[1]))){
    const control=executeCombatLifecycle(source,group);
    assert.equal(control.status,0,`${group}: unmodified control must pass\n${control.stdout+control.stderr}`);
  }
  for(const [label,group,owner,predicate,replacement,marker]of changes){
    const mutant=mutateNode(source,owner,predicate,replacement);
    const result=executeCombatLifecycle(mutant,group);
    assert.notEqual(result.status,0,`${label}: mutant survived`);
    assert.match(result.stdout+result.stderr,/\[COMBAT_LIFECYCLE\]/,`${label}: lifecycle assertion, not runner/parser failure`);
    assert.match(result.stdout+result.stderr,marker,`${label}: intended sensitive assertion`);
  }
});
