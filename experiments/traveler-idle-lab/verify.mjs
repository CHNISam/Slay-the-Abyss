import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {bridge} from './rpc.mjs';
const b=bridge(),unwrap=r=>r.structuredContent??JSON.parse(r.content.find(c=>c.type==='text').text);
const report={scope:'Real BeyondSimulator Lua/Host; not official game, GPU FPS or device acceptance',checks:[],candidateSha256:createHash('sha256').update(fs.readFileSync('sample.save.json')).digest('hex')};
const count=n=>1+n.children.reduce((s,c)=>s+count(c),0);
try{
 await b.request('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'traveler-idle-lab',version:'1'}});
 const {handle}=unwrap(await b.call('qxqy_project_open',{path:'sample.save.json'}));
 const call=(action,args={})=>b.call('qxqy_studio_play',{handle,action,args}).then(unwrap);
 const state=()=>call('get',{inspect:true}), step=dt=>call('step',{dt,light:true});
 const part=(s,name)=>s.tree[0].children.find(n=>n.name===name);
 const actor=(s,i)=>part(s,i===1?'traveler':'monster');
 const click=async name=>{let s=await state();return call('click',{name});};
 const check=s=>{assert(!s.mountError,JSON.stringify(s.mountError));assert(!s.logs.some(x=>x.level==='error'),JSON.stringify(s.logs));};
 const shot=async file=>{const r=await b.call('qxqy_studio_play_screenshot',{handle});fs.writeFileSync(file,Buffer.from(r.content.find(c=>c.type==='image').data,'base64'));return r.content.filter(c=>c.type!=='image');};
 await call('start');let initial=await state();check(initial);const controls=count(initial.tree[0]);assert(initial.logs.some(x=>x.text==='traveler-idle-lab-ready:original-primitives:87c944f3'));
 fs.writeFileSync('preview-receipt.json',JSON.stringify(await shot('preview.png'),null,2));
 await step(.1);let moved=await state();check(moved);assert.notEqual(actor(moved,1).children.find(n=>n.name==='head').anchoredPositionY,111);
 assert.notEqual(actor(moved,2).children.find(n=>n.name==='head').anchoredPositionY,72);
 report.checks.push('Native Lua mounts, exact ready logged, both layered actor heads move');
 // Idle feet must not translate, including all representative cycle boundaries.
 for(const dt of [.1,.016,.05,.033])for(let i=0;i<100;i++)await step(dt);
 let s=await state();check(s);
 for(let i=1;i<=2;i++){assert.equal(actor(s,i).anchoredPositionX,i===1?-350:350);assert.equal(actor(s,i).children.find(n=>n.name==='feet').anchoredPositionY,0);}
 report.checks.push('Idle roots and feet remain anchored across varied dt');
 for(const [name,index]of[['attack',1],['counter',2]]){
  await click(name);await step(.06);s=await state();check(s);assert.notEqual(actor(s,index).anchoredPositionX,index===1?-350:350);
  await step(.1);await step(.04);s=await state();assert(actor(s,3-index).children.find(n=>n.name==='impact').visible);assert.notEqual(actor(s,3-index).anchoredPositionX,index===1?350:-350);
  for(let i=0;i<8;i++)await step(.1);s=await state();check(s);
  for(let j=1;j<=2;j++){assert.equal(actor(s,j).anchoredPositionX,j===1?-350:350);assert.equal(actor(s,j).children.find(n=>n.name==='impact').visible,false);}
 }
 report.checks.push('Both attack directions, contact feedback and exact return-to-origin');
 for(let i=0;i<100;i++){await click(i%2?'attack':'counter');await step(.033);}
 await click('reset');s=await state();check(s);assert.equal(count(s.tree[0]),controls);
 for(let j=1;j<=2;j++)assert.equal(actor(s,j).anchoredPositionX,j===1?-350:350);
 report.checks.push('100 interrupted/repeated attacks, reset, fixed control count');
 // Interrupt while the victim's hit feedback is actually visible, not only wind-up.
 for(const next of ['counter','reset']){
  await click('attack');await step(.1);await step(.1);
  s=await state();assert(actor(s,2).children.find(n=>n.name==='impact').visible);
  await click(next);s=await state();assert.equal(actor(s,2).children.find(n=>n.name==='impact').visible,false);
  for(let i=0;i<20;i++)await step(i%2?.017:.041);
  s=await state();check(s);
  for(let j=1;j<=2;j++){assert.equal(actor(s,j).anchoredPositionX,j===1?-350:350);assert.equal(actor(s,j).children.find(n=>n.name==='impact').visible,false);}
 }
 report.checks.push('Interrupt active hit flash by counterattack/reset; varied dt recovery');

 await assert.rejects(step(-1),/finite non-negative/);s=await state();check(s);
 await step(10);s=await state();check(s);assert.equal(count(s.tree[0]),controls);
 report.checks.push('Host rejects negative dt; long dt capped without Lua error or control growth');
 await call('start');await click('auto');const t=performance.now();let lat=[];
 for(let i=0;i<18000;i++){const t0=performance.now();await step(1/30);lat.push(performance.now()-t0);}
 s=await state();check(s);assert.equal(count(s.tree[0]),controls);lat.sort((a,b)=>a-b);
 report.stress={simulatedSeconds:600,steps:18000,controls,wallMs:performance.now()-t,rpcP95Ms:lat[17100],note:'IPC plus Lua update cost, not GPU or device frame time'};
 report.checks.push('600 simulated seconds automatic alternating attacks; no control growth or Lua errors');
 await call('start',{clockMode:'realtime'});await new Promise(r=>setTimeout(r,1000));await call('pause');const paused=await state();await new Promise(r=>setTimeout(r,300));assert.equal((await state()).time,paused.time);await call('resume');await new Promise(r=>setTimeout(r,400));assert((await state()).time>paused.time);
 report.checks.push('Realtime pause/resume');
 for(let i=0;i<3;i++){await call('stop');await call('start');check(await state());}
 const logsBefore=(await state()).logs.filter(x=>x.text==='idle-lab-attack:1').length;await click('attack');assert.equal((await state()).logs.filter(x=>x.text==='idle-lab-attack:1').length-logsBefore,1);
 report.checks.push('Three stop/start remounts; single click emits exactly one attack log');
 fs.mkdirSync('frames',{recursive:true});await call('start');
 for(let i=0;i<240;i++){
  if(i===90)await click('attack');if(i===150)await click('counter');
  if(i)await step(1/30);await shot('frames/'+String(i).padStart(3,'0')+'.png');
 }
 s=await state();check(s);fs.writeFileSync('final-state.json',JSON.stringify(s,null,2));
 report.video={frames:240,dt:1/30,seconds:8,note:'Real Host screenshots at deterministic 30 Hz simulation; offline encoded, not live GPU capture'};
 const e=unwrap(await b.call('qxqy_studio_export',{handle,action:'export',args:{format:'save-gia'}}));
 fs.mkdirSync('import',{recursive:true});
 for(const [i,f]of(e.files??[]).entries())fs.writeFileSync('import/'+i+'-'+f.filename,Buffer.from(f.data,'base64'));
 report.export={warnings:e.warnings,files:e.files?.map(({data,...f})=>f)};
 fs.writeFileSync('verification.json',JSON.stringify(report,null,2));console.log('ALL PASSED',report.checks,report.stress);
}catch(e){report.failure=e.stack;fs.writeFileSync('verification-failed.json',JSON.stringify(report,null,2));throw e;}finally{b.close();}
