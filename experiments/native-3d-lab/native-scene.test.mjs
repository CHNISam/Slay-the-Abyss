import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {mkdtempSync,readFileSync,existsSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {nativeGraphSources,nativeModels,seedCreaturePrefabs} from './native-scene.mjs';

function harness(){
  const graphs=Object.fromEntries(['server','unit','decision','attack','hit','idle','skill_attack','skill_hit'].map((name,index)=>[name,{graphId:index+1,name:'_GSTS_'+name}]));
  const prefabs=nativeModels.map((p,index)=>({...p,prefabId:1082130433+index}));
  const handlers={},ack=[],timers=[],units=[],variables=new Map([[100,{LAB_lastseq:0n}]]);let next=1000;
  const owner=()=>({onSignal(name,callback){handlers[name]=callback;return this},on(name,callback){handlers[name]=callback;return this}});
  const sources=nativeGraphSources({graphs,prefabs,statusId:200,anchor:[0,2000.4,0]});
  for(const source of sources.slice(0,2)){
    const code=source.code.replace(/^import .*$/gm,'').replace(/ as (const|bigint\[\]|string\[\]|number\[\])/g,'');
    vm.runInNewContext(code,{g:{server:owner},defineSignal:name=>name});
  }
  const f={getSelfEntity:()=>100,getCustomVariable:(id,key)=>({asType:()=>variables.get(id)?.[key]??0n}),
    setCustomVariable:(id,key,value)=>{if(!variables.has(id))variables.set(id,{});variables.get(id)[key]=value},
    getListOfPlayerEntitiesOnTheField:()=>[900],getAllCharacterEntitiesOfSpecifiedPlayer:()=>[901],
    sendSignal:(_signal,_player,message,seq)=>ack.push({message,seq}),
    getEntitiesWithSpecifiedPrefabOnTheField:prefab=>units.filter(p=>p.prefab===prefab).map(p=>p.id),
    create3dVector:(x,y,z)=>[x,y,z],createPrefab:(prefab,position)=>{const id=next++;units.push({id,prefab,position});variables.set(id,{});return id},
    removeEntity:id=>{units.splice(units.findIndex(u=>u.id===id),1)},
    destroyEntity:id=>{units.splice(units.findIndex(u=>u.id===id),1)},
    queryEntityFaction:()=>1,modifyEntityFaction(){},addUnitStatus(){},createDictionary:()=>({}),
    startTimer:(id,name,_loop,intervals)=>timers.push({id,name,intervals}),stopTimer(){}};
  let seq=0n;
  return {prefabs,sources,ack,timers,units,variables,f,handlers,
    command:(command,model=1,actor=1,sequence=++seq)=>{handlers.LAB3D_COMMAND({params:{command,model:BigInt(model),actor:BigInt(actor),seq:sequence}},f);return ack.at(-1)},
    ready:unit=>handlers.whenTimerIsTriggered({eventSourceEntity:unit.id,timerName:'LAB_READY'},f),
    finish:(unit,action)=>handlers.whenSkillNodeIsCalled({callerEntity:unit.id,parameter1:'LAB_'+action},f)};
}

test('three enemy slots coexist and hide all removes every native actor',()=>{
 const h=harness();for(let slot=1;slot<=3;slot++){assert.equal(h.command('show',slot,slot).message,'created:initializing_4.5s');h.ready(h.units.at(-1));}
 assert.equal(h.units.length,3);assert.equal(new Set(h.units.map(u=>u.position[0])).size,3);
 assert.equal(new Set(h.units.map(u=>u.position[2])).size,1);
 assert.equal(h.command('hide',1,0).message,'hidden');assert.equal(h.units.length,0);
});
test('stale commands and busy initialization cannot replay animation',()=>{
 const h=harness();h.command('show');const unit=h.units[0];
 assert.equal(h.command('attack').message,'busy:wait_ready_or_animation');
 h.ready(unit);assert.equal(h.command('attack').message,'requested:await_skill_event');
 assert.equal(h.variables.get(unit.id).LAB_command,1n);
 assert.equal(h.command('attack',1,1,1n).message,'duplicate_or_stale');
 h.finish(unit,'attack');assert.equal(h.ack.at(-1).message,'completed:attack');
 assert.equal(h.variables.get(unit.id).LAB_command,0n);assert.equal(h.variables.get(unit.id).LAB_busy,0n);
});
test('unsupported clip does not block next command and player animation is explicit',()=>{
 const h=harness();h.command('show',2);const unit=h.units[0];h.ready(unit);
 assert.equal(h.command('hit',2).message,'unsupported:hit');
 assert.equal(h.command('attack',2).message,'requested:await_skill_event');h.finish(unit,'attack');
 assert.equal(h.command('attack',2,0).message,'unsupported:player_animation');
 assert.equal(h.command('death',2).message,'completed:death');assert.equal(h.units.length,0);
});
test('missing native skill event reports timeout without claiming completion',()=>{
 const h=harness();h.command('show');const unit=h.units[0];h.ready(unit);h.command('attack');
 h.handlers.whenTimerIsTriggered({eventSourceEntity:unit.id,timerName:'LAB_TIMEOUT'},h.f);
 assert.equal(h.ack.at(-1).message,'error:animation_timeout');assert.equal(h.variables.get(unit.id).LAB_command,0n);
});
test('native graphs never invoke an attack, HP loss, hitbox, or Lua rule mutation',()=>{
 const h=harness();const code=h.sources.map(s=>s.code).join('\n');
 assert.doesNotMatch(code,/trigger\w*Hitbox|hpLoss\(|performAttack|recoverHp|abyss_core|require\(/);
 assert.match(code,/destroyEntity/);assert.match(code,/f\.notifyServerNodeGraph/);
});

const base=resolve('.artifacts/native-3d-base/base.gil');
test('official-seed adaptation writes a new GIL and preserves the input bytes',{skip:!existsSync(base)},async()=>{
 const input=readFileSync(base),dir=mkdtempSync(join(tmpdir(),'abyss-native-scene-'));
 const result=await seedCreaturePrefabs({mapPath:base,outputPath:join(dir,'seeded.gil')});
 assert.deepEqual(readFileSync(base),input);assert.equal(result.prefabs.length,3);
 assert.equal(new Set(result.prefabs.map(p=>p.prefabId)).size,3);
 assert.equal(result.provenance.officialImport,'not_run');
 await assert.rejects(seedCreaturePrefabs({mapPath:base,outputPath:base}),/overwrite input/);
});
