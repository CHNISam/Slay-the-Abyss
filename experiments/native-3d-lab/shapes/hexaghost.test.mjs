import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {shapeSample,shapeGraphSource,prepareShapeSample} from './hexaghost.mjs';
test('six-petal shape stays within budget, with an open center and no collisions',()=>{
 assert.equal(shapeSample.parts.length,24);
 for(const prefix of ['rim','ceramic','socket','fire'])assert.equal(shapeSample.parts.filter(p=>p.name.startsWith(prefix+'_')).length,6);
 assert.ok(shapeSample.parts.every(p=>p.solid===false));
 assert.ok(shapeSample.parts.every(p=>p.shape!=='sphere'&&p.size.every(n=>n>0)));
 // No center-filling core mesh; six separate rim segments surround the hole.
 assert.ok(shapeSample.parts.every(p=>Math.hypot(p.position[0],p.position[1]-2)>.40));
});
test('shape motion commands preserve the one-object assembly and never cause game damage',()=>{
 let handler,timer,next=100;const stage=1,variables={SHAPE_seq:0n,SHAPE_pendingseq:0n,SHAPE_busy:false,SHAPE_yaw:180n},entities=[],acks=[],motions=[];
 const code=shapeGraphSource({graphId:10,name:'_GSTS_shape',shapePrefabId:20,anchorPrefabId:21});
 assert.doesNotMatch(code,/hpLoss|trigger\w*Hitbox|performAttack|recoverHp/);
 const context={g:{server:()=>({onSignal(_name,fn){handler=fn;return this},on(_name,fn){timer=fn;return this}})},defineSignal:n=>n,FollowCoordinateSystem:{WorldCoordinateSystem:1},FollowLocationType:{FollowLocation:1}};
 vm.runInNewContext(code.replace(/^import .*$/gm,'').replace(/ as (const|bigint\[\])/g,''),context);
 const remove=id=>entities.splice(entities.findIndex(e=>e.id===id),1);
 const f={getSelfEntity:()=>stage,getCustomVariable:(_e,key)=>({asType:()=>variables[key]}),setCustomVariable:(_e,key,v)=>{variables[key]=v},
  getListOfPlayerEntitiesOnTheField:()=>[2],sendSignal:(_signal,_player,message,seq)=>acks.push({message,seq}),
  getEntitiesWithSpecifiedPrefabOnTheField:prefab=>entities.filter(e=>e.prefab===prefab).map(e=>e.id),
  createPrefab:(prefab,pos,rotation)=>{entities.push({id:next,prefab,pos,rotation});return next++},removeEntity:remove,destroyEntity:remove,
  stopTimer(){},startTimer(){},switchFollowMotionDeviceTargetByEntity:(shape,mover)=>{assert.equal(entities.find(e=>e.id===shape).prefab,20);assert.equal(entities.find(e=>e.id===mover).prefab,21)},activateDisableFollowMotionDevice(){},
  pauseBasicMotionDevice:(id,name)=>motions.push({id,name}),activateBasicMotionDevice:(id,name)=>motions.push({id,name}),recoverBasicMotionDevice:(id,name)=>motions.push({id,name}),
  getEntityLocationAndRotation:id=>({location:entities.find(e=>e.id===id).pos}),create3dVector:(x,y,z)=>[x,y,z],dataTypeConversion:Number};
 let seq=0n;const command=name=>{handler({params:{command:name,seq:++seq}},f);return acks.at(-1)};
 assert.equal(command('show').message,'ready:whole_object_not_rigged');assert.equal(entities.length,2);
 assert.equal(command('turn').message,'completed:rotation_by_recreation_not_rotation_motor');assert.equal(entities.length,2);
 assert.equal(entities.find(e=>e.prefab===20).rotation[1],270);
 assert.equal(command('move').message,'completed:idle_native_bob');
 assert.equal(command('attack').message,'requested:whole_object_motion');
 const pending=seq;assert.equal(command('hit').message,'busy');
 timer({timerName:'SHAPE_DONE',eventSourceEntity:stage},f);assert.equal(acks.at(-1).seq,pending);
 assert.ok(motions.every(m=>entities.find(e=>e.id===m.id).prefab===21));
 assert.equal(command('death').message,'completed:death_whole_object');assert.equal(entities.length,0);
 command('show');assert.equal(command('hide').message,'hidden');assert.equal(entities.length,0);
});
test('installer adds only one new graph, no motions on the visible shape',async()=>{
 const calls=[];let id=100;
 const result=await prepareShapeSample({mapPath:'copy.gil',call:async(name,args)=>{
  calls.push({name,args});
  if(name==='scene_add_shape_prefab')return {mapPath:'shape.gil',prefabId:20,parts:24};
  if(name==='scene_add_prefab')return {prefabId:21};
  if(name==='scene_add_graph')return {graphId:++id,name:'_GSTS_shape'};
  if(name==='write_graphs')return {written:[{graphId:101}]};
  if(name==='scene_list_prefabs')return {prefabs:[{prefabId:20},{prefabId:21}]};
  return {};
 }});
 assert.equal(calls.filter(c=>c.name==='scene_add_graph').length,1);
 assert.equal(calls.find(c=>c.args.motions)?.args.prefab,21);
 assert.ok(!calls.some(c=>c.args.prefab===20&&c.args.motions));
 assert.equal(result.inventory.shapeParts,24);assert.equal(result.inventory.damageNodes,0);
 assert.equal(result.capabilities.nativeLoad,'unverified');
});
