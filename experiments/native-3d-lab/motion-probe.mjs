// Diagnose the existing failure without turning a timer into animation success.
export async function installMotionProbe({call,nativeScene}){
 const unit=nativeScene.graphs.unit,decision=nativeScene.graphs.decision;
 const guard=nativeScene.prefabs.find(p=>p.model===1);
 const original=nativeScene.sources.find(s=>s.graphId===unit.graphId)?.code;
 const anchor=" const unit=evt.callerEntity,seq=f.getCustomVariable(unit,'LAB_seq').asType('int');";
 if(!guard||!original||original.split(anchor).length!==2)throw Error('Existing motion probe anchor changed');
 const graph=await call('scene_add_graph',{name:'LAB3D_skill_entry_probe',kind:'creatureSkill'});
 const code=`import {g} from 'genshin-ts/runtime/core'
g.creationSkill({id:${graph.graphId},name:'${graph.name}',prefix:false}).on('start',(_evt,f)=>{f.notifyServerNodeGraph('LAB_probe_entered','','');})`;
 const skills=[];
 for(const action of ['attack','hit']){
  const s=await call('scene_add_creature_skill',{name:'LAB3D_probe_'+action,creature:guard.asset,
   animation:guard[action],graphId:graph.graphId,graphAtMs:1,faceTarget:false,interrupts:true});
  skills.push({skill:s.skillId,firstCooldownSeconds:0,cooldownSeconds:0.5});
 }
 await call('scene_set_creature_logic',{prefab:guard.prefabId,decisionGraphId:decision.graphId,skills,
  sharedCooldownSeconds:0,logic:{sightDistance:0.01,chainRadius:0.01,territoryRadius:20}});
 const diagnostic=original.replace(anchor,anchor+`
 if(evt.parameter1==='LAB_probe_entered'){
  for(const player of f.getListOfPlayerEntitiesOnTheField())f.sendSignal(ACK,player,'diagnostic:skill_entered_1ms',seq);
  return;
 }`);
 const result=await call('write_graphs',{graphs:[{graphId:graph.graphId,code},{graphId:unit.graphId,code:diagnostic}]});
 if(result.failed||result.written?.length!==2)throw Error('Entry diagnostic did not compile/write');
 return {model:1,graph,skills,eventAtMs:1,timeoutRetained:true,
  meaning:'diagnostic receipt proves skill entry only; full motion and endpoint remain unverified',
  sources:[{graphId:graph.graphId,code},{graphId:unit.graphId,code:diagnostic}]};
}
