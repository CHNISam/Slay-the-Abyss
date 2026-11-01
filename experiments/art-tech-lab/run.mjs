import {bridge} from './rpc.mjs';
import {writeFileSync,mkdirSync} from 'node:fs';
const b=bridge(),dir='experiments/art-tech-lab/';
const unpack=r=>r.structuredContent??JSON.parse(r.content.find(c=>c.type==='text').text);
try{
 await b.request('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'art',version:'1'}});
 const open=unpack(await b.call('qxqy_project_open',{path:dir+'sample.save.json'}));const handle=open.handle;
 let t=performance.now();const start=unpack(await b.call('qxqy_studio_play',{handle,action:'start'}));const startMs=performance.now()-t;
 writeFileSync(dir+'runtime-start.json',JSON.stringify(start,null,2));
 const shot=async name=>{let t=performance.now();const r=await b.call('qxqy_studio_play_screenshot',{handle});const pic=r.content.find(c=>c.type==='image');if(pic)writeFileSync(dir+name+'.png',Buffer.from(pic.data,'base64'));writeFileSync(dir+name+'.receipt.json',JSON.stringify(r.content.filter(c=>c.type!=='image')));return performance.now()-t};
 const firstScreenshotMs=await shot('sample');
 const select=unpack(await b.call('qxqy_studio_play',{handle,action:'click',args:{name:'hit'}}));writeFileSync(dir+'selection.json',JSON.stringify(select,null,2));
 const repeatScreenshotMs=await shot('selected');
 const play=unpack(await b.call('qxqy_studio_play',{handle,action:'click',args:{name:'hit'}}));writeFileSync(dir+'played.json',JSON.stringify(play,null,2));await shot('played');
 const exported=await b.call('qxqy_studio_export',{handle,action:'export',args:{format:'save-gia'}});
 const e=unpack(exported);mkdirSync(dir+'import',{recursive:true});
 for(const [i,file] of (e.files??[]).entries())writeFileSync(dir+'import/'+i+'-'+file.filename,Buffer.from(file.data,'base64'));
 writeFileSync(dir+'export-receipt.json',JSON.stringify({...e,files:e.files?.map(({data,...f})=>f)},null,2));
 await b.call('qxqy_studio_play',{handle,action:'device',args:{canvasId:'mobile-16-9'}});await shot('mobile');
 writeFileSync(dir+'timings.json',JSON.stringify({startMs,firstScreenshotMs,repeatScreenshotMs,scope:'host RPC + software PNG; NOT game load or FPS'},null,2));
 console.log({startMs,firstScreenshotMs,repeatScreenshotMs,export:Object.keys(e)});
}finally{b.close()}
