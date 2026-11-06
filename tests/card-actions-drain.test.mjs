import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import luaparse from 'luaparse';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
import {preDrainActionPolicySection} from './helpers/card-actions-policy-composition.mjs';

const live='src/lua/abyss_card_actions.lua',old='tests/fixtures/card-actions-drain-before.lua';
const fixture='tests/lua/card_actions_drain.lua';
const read=file=>readFileSync(file,'utf8').replaceAll('\r\n','\n');
const sha=source=>createHash('sha256').update(source).digest('hex');
const count=75;
function execute(module,{trace=false}={}){
  const dir=mkdtempSync(join(tmpdir(),'card-drain-'));
  try{
    const driver=join(dir,'driver.lua');
    const epoch=resolve(module)===resolve(old)?'frozen-rare':'current-family';
    writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;ABYSS_DRAIN_EPOCH=${luaString(epoch)};ABYSS_DRAIN_TRACE=${trace};package.loaded.abyss_card_actions=dofile(${luaString(resolve(module).replaceAll('\\','/'))});dofile(${luaString(resolve(fixture).replaceAll('\\','/'))})`);
    if(!trace)return runLua(driver,{maxBuffer:64*1024,timeout:60000});
    const result=spawnSync(process.execPath,['tests/helpers/card-actions-drain-vm.mjs',driver],{encoding:'utf8',timeout:60000,maxBuffer:64*1024*1024});
    if(result.error)throw result.error;
    assert.equal(result.signal,null,'trace VM completed within original timeout');return result;
  }finally{rmSync(dir,{recursive:true,force:true});}
}
function success(result){assert.equal(result.status,0,result.stderr||result.stdout.slice(-2000));}
// Schema: each observation has a typed root and complete replacement field
// lists for changed table IDs. Omitted IDs retain their previous definition;
// absent fields in a replacement are deleted. Reachability excludes dead nodes.
function graphReader(){
  const definitions=new Map();
  return delta=>{
    for(const [id,fields,meta=['nil','nil']]of delta.nodes){assert(Number.isSafeInteger(id));definitions.set(id,[fields,meta]);}
    const objects=new Map(),functions=new Map(),reachable=new Map();
    function decode([kind,value]){
      if(kind==='table'){
        if(objects.has(value))return objects.get(value);
        assert(definitions.has(value),`defined reference ${value}`);
        const object=new Map();objects.set(value,object);reachable.set(value,definitions.get(value));
        const [fields,meta]=definitions.get(value);
        for(const [key,field]of fields)object.set(decode(key),decode(field));
        object.metatable=decode(meta);
        return object;
      }
      if(kind==='function'){if(!functions.has(value))functions.set(value,Object.freeze({function:value}));return functions.get(value);}
      if(kind==='number')return Number(value);
      if(kind==='boolean')return value==='true';
      assert(['string','nil'].includes(kind));return kind==='nil'?undefined:value;
    }
    const root=decode(delta.root);
    return {root,complete:[delta.root,[...reachable].sort((a,b)=>a[0]-b[0])]};
  };
}
function reconstructTrace(output){
  const read=graphReader();
  return output.trimEnd().split('\n').filter(line=>line.startsWith('DRAIN_TRACE ')).map(line=>{
    const record=JSON.parse(line.slice(line.indexOf('{')));
    return {name:record.name,graphs:[record.before,...record.observations.map(o=>o.graph),record.after].map(delta=>read(delta).complete)};
  });
}
test('graph delta roundtrip preserves aliases, cycles, deleted fields and detached nodes',()=>{
  const read=graphReader(),s=v=>['string',v],t=id=>['table',id];
  const first=read({root:t(1),nodes:[[1,[[s('self'),t(1)],[s('a'),t(2)],[s('b'),t(2)],[s('gone'),s('old')]]],[2,[[s('value'),s('first')]]]]});
  assert.equal(first.root.get('self'),first.root);assert.equal(first.root.get('a'),first.root.get('b'));
  const second=read({root:t(1),nodes:[[1,[[s('self'),t(1)],[s('a'),t(2)],[s('b'),t(2)]]],[2,[[s('value'),s('second')]]]]});
  assert(!second.root.has('gone'));assert.equal(second.root.get('a'),second.root.get('b'));assert.equal(second.root.get('a').get('value'),'second');
  const third=read({root:t(1),nodes:[[1,[[s('self'),t(1)]]]]});
  assert.equal(third.root.get('self'),third.root);assert.equal(third.complete[1].length,1);
  assert.deepEqual(first.complete[1][1],[2,[[[s('value'),s('first')]],['nil','nil']]],'earlier snapshot remains immutable');
});
test('complete base oracle is frozen and exact drain inverse recovers its full policy section',()=>{
  // develop 78e4e746 / a2457383: Git blob 2736b3302f58eb0b036e2c2babecb0c2cec81a6b.
  assert.equal(sha(read(old)),'112797fa882da595e9016f41c111a8e0cebcd12ba7ec39fd2709fc4717cf883a');
  const policy=source=>source.slice(source.indexOf('local retained='));
  assert.equal(preDrainActionPolicySection(policy(read(live))),policy(read(old)));
  for(const token of ['local function applyDrainedAction','local function refreshDrainedHand','applyDrainedAction(combat,state,item,outcome)\n','local drew=refreshDrainedHand(state,outcome)']){
    const source=policy(read(live));assert(source.includes(token));
    assert.throws(()=>preDrainActionPolicySection(source.replace(token,token.replace(/\n$/,'')+' -- drift\n')));
    assert.throws(()=>preDrainActionPolicySection(source.replace(token,token+'\n'+token)));
  }
});
test('raw drain fixture defaults to bounded output and executes all cases',()=>{
  const result=runLua(fixture);success(result);
  assert.equal(result.stdout,`CARD_ACTION_DRAIN_PASS ${count}\n`);
});
test('complete independent old/new VMs preserve every graph, alias, RNG, error and return observation',()=>{
  const before=execute(old,{trace:true}),after=execute(live,{trace:true});success(before);success(after);
  if(process.env.ABYSS_DRAIN_EVIDENCE_DIR){
    for(const [name,result]of [['before',before],['after',after]])writeFileSync(join(process.env.ABYSS_DRAIN_EVIDENCE_DIR,`${name}.trace`),result.stdout);
  }
  for(const result of [before,after]){
    assert.equal(result.stdout.match(/^DRAIN_TRACE /gm)?.length,count);
    assert(result.stdout.endsWith(`CARD_ACTION_DRAIN_PASS ${count}\n`));
    assert(Buffer.byteLength(result.stdout)>100000,'complete graph trace is captured');
    const probe=JSON.parse(result.stdout.split('\n').find(line=>line.startsWith('DRAIN_GRAPH_PROBE ')).slice('DRAIN_GRAPH_PROBE '.length));
    const read=graphReader(),[first,second,third,fourth]=probe.map(delta=>read(delta));
    assert.equal(first.root.get('a'),first.root.get('b'));assert.equal(first.root.get('self'),first.root);
    assert.equal(first.root.get(true),'bool');assert.equal(first.root.get(7),'number');
    assert.equal(first.root.get(first.root.get('fn')),first.root.get('a'));assert.equal(first.root.get(first.root.get('a')),first.root.get('fn'));
    assert.equal(first.root.metatable.get('owner'),first.root);assert.equal(first.root.metatable.get('label'),'first');
    assert.equal(first.root.get('a').get('value'),'first');assert(!second.root.has('gone'));
    assert.equal(second.root.get('a'),second.root.get('b'));assert.equal(second.root.get('a').get('value'),'second');
    assert.equal(second.root.metatable.get('label'),'second');assert.equal(second.root.metatable.get('owner'),second.root);
    assert.equal(third.root.get('a').get('value'),'first','transient child change and restore is observable');
    assert.equal(fourth.complete[1].length,1);assert.equal(fourth.root.get('self'),fourth.root);assert.equal(fourth.root.metatable,undefined);
  }
  assert.equal(after.stdout,before.stdout);
  assert.deepEqual(reconstructTrace(after.stdout),reconstructTrace(before.stdout),'complete reconstructed reachable graphs at every boundary');
  console.log(`drain independent VM trace: ${count} cases, ${Buffer.byteLength(after.stdout)} bytes per VM, SHA256 ${sha(after.stdout)}`);
});
function mutateFunction(source,name,before,after){
  const ast=luaparse.parse(source,{ranges:true});
  const nodes=ast.body.filter(node=>node.type==='FunctionDeclaration'&&
    (node.identifier?.name===name||node.identifier?.base?.name==='M'&&`M.${node.identifier.identifier.name}`===name));
  assert.equal(nodes.length,1,`real parsed function ${name}`);
  const [start,end]=nodes[0].range,body=source.slice(start,end);
  assert.equal(body.split(before).length-1,1,`unique semantic mutation in ${name}`);
  const changed=source.slice(0,start)+body.replace(before,after)+source.slice(end);
  assert.doesNotThrow(()=>luaparse.parse(changed),'mutant parses before execution');
  return changed;
}
test('real parsed drain semantic mutants fail genuine behavioral assertions',()=>{
  const source=read(live),dir=mkdtempSync(join(tmpdir(),'drain-mutants-'));
  const mutants=[
    ['guard','M.drain','if state.drainingCardActions then return end','if false then return end'],
    ['victory','applyDrainedAction','outcome=="victory" and keep','outcome=="victory" or keep'],
    ['enemy override','applyDrainedAction',"if item.effect.op=='enemyAction'then",'if false then'],
    ['effect reread','applyDrainedAction',"or item.effect.op=='silentFinal'","or false and item.effect.op=='silentFinal'"],
    ['apply dispatch','applyDrainedAction','M.apply(combat,state,item)','combat.apply(combat,state,item)'],
    ['pop order','M.drain','table.remove(state.cardActions,1)','table.remove(state.cardActions)'],
    ['queued ignored','M.drain','elseif not outcome and state.queuedCards','elseif false and state.queuedCards'],
    ['outcome ignored','M.drain','local outcome=combat.outcome(state)','local outcome=nil'],
    ['discard pause','M.drain','while not state.pendingChoice and not state.pendingDiscard','while not state.pendingChoice'],
    ['actionQueue pause','M.drain','while not state.pendingChoice and not state.pendingDiscard and not state.actionQueue','while not state.pendingChoice and not state.pendingDiscard'],
    ['extra pause','M.drain','while not state.pendingChoice','while not state.pendingPileChoice and not state.pendingChoice'],
    ['end turn refresh','refreshDrainedHand','not state.endTurnAfterCard and','true and'],
    ['owns refresh','refreshDrainedHand',"rareQueries.owns(state,'unceasing_top')",'true'],
    ['terminal require','refreshDrainedHand',"local rare=require('abyss_relic_family_combat').rare","if outcome then return false end\n    local rare=require('abyss_relic_family_combat').rare"],
    ['truthy refresh','M.drain','if not drew then break end','if drew~=true then break end'],
    ['owner finish','M.drain','state.drainingCardActions=nil','state.drainingCardActions=true'],
    ['tail return finish','M.drain','then combat.finishEarlyTurn(state)end','then return combat.finishEarlyTurn(state)end'],
    ['pause cleanup','M.drain','if not state.pendingChoice and not state.pendingDiscard and not state.actionQueue then state.cardActions=nil','if true then state.cardActions=nil'],
  ];
  try{
    for(const [label,name,before,after]of mutants){
      const path=join(dir,'mutant.lua');writeFileSync(path,mutateFunction(source,name,before,after));
      const result=execute(path);
      if(process.env.ABYSS_DRAIN_EVIDENCE_DIR){
        const stem=join(process.env.ABYSS_DRAIN_EVIDENCE_DIR,`mutant-${label.replaceAll(' ','-')}`);
        writeFileSync(`${stem}.lua`,read(path));writeFileSync(`${stem}.log`,result.stdout+result.stderr);
        writeFileSync(`${stem}.json`,JSON.stringify({label,function:name,status:result.status,parsed:true},null,2)+'\n');
      }
      assert.notEqual(result.status,0,`${label}: survived`);
      assert.match(result.stdout+result.stderr,/\[DRAIN_CONTRACT\]/,`${label}: genuine contract kill`);
      assert.doesNotMatch(result.stdout+result.stderr,/syntax error|module .* not found/,`${label}: valid runtime mutant`);
    }
    console.log(`drain semantic mutants killed: ${mutants.length}`);
  }finally{rmSync(dir,{recursive:true,force:true});}
});
