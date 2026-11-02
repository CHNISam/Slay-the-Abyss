import {bridge} from './rpc-long.mjs';
import {inspectorPointerCenter} from './inspector-pointer.mjs';
import {readFileSync,writeFileSync,mkdirSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';import {createHash} from 'node:crypto';
const [source='experiments/figma-map-native-spike/scene.save.json',outArg]=process.argv.slice(2);
if(!outArg)throw Error('Usage: node capture-scene.mjs <relative-save> <new-output-dir>');
const out=resolve(outArg);if(existsSync(out))throw Error('Output already exists; choose fresh evidence directory');mkdirSync(out,{recursive:true});mkdirSync(out+'/frames');
const hash=b=>createHash('sha256').update(b).digest('hex');
const manifest={source:resolve(source),sourceSHA256:hash(readFileSync(source)),toolVersion:'0.5.2',clock:'manual',sampleHz:10,scope:'Actual Simulator software LuaHost screenshots after explicit 0.1s steps; NOT device FPS',frames:[],actions:[]};
writeFileSync(out+'/source.save.json',readFileSync(source));
const b=bridge();let seq=0,frame=0,last;
const unpack=r=>r.structuredContent??JSON.parse(r.content.find(c=>c.type==='text').text);
async function action(action,args={}){const r=unpack(await b.call('qxqy_studio_play',{handle,action,args}));last=r;const id=String(seq++).padStart(3,'0');writeFileSync(`${out}/${id}-${action}.json`,JSON.stringify(r,null,2));manifest.actions.push({id,action,args,time:r.time});if(r.mountError)throw Error(r.mountError);if(r.logs?.some(l=>/error/i.test(String(l.level))))throw Error('Runtime error log');return r}
async function shot(name,isFrame=false){const r=await b.call('qxqy_studio_play_screenshot',{handle});const receipt=r.content.filter(c=>c.type!=='image');let meta;for(const c of receipt)if(c.type==='text'){try{meta=JSON.parse(c.text)}catch{}}
const data=r.content.find(c=>c.type==='image');if(!data)throw Error('No screenshot returned');const png=Buffer.from(data.data,'base64');writeFileSync(`${out}/${name}.png`,png);writeFileSync(`${out}/${name}.receipt.json`,JSON.stringify(receipt,null,2));if(meta?.assetWarnings?.length)throw Error('Missing image assets: '+JSON.stringify(meta.assetWarnings));if(isFrame)manifest.frames.push({file:name+'.png',sha256:hash(png),time:meta.time,hostFrame:meta.frame});}
async function capture(){await shot('frames/'+String(frame++).padStart(4,'0'),true)}
async function steps(n){for(let i=0;i<n;i++){await action('step',{dt:.1});await capture()}}
async function clickSuffix(suffix,type="click"){
 const state=await action('get',{inspect:true});const hits=[];
 function visit(node,path=[],visible=true,chain=[]){if(!node)return;const p=[...path,node.name];const shown=visible&&node.active!==false&&node.visible!==false;const ancestry=[...chain,node];if(shown&&p.join('/').endsWith(suffix))hits.push({node,ancestry});for(const c of node.children??[])visit(c,p,shown,ancestry)}
 for(const n of state.tree??[])visit(n);
 if(hits.length!==1||!hits[0].node.box)throw Error(`Expected one visible target ${suffix}; got ${hits.length}`);
 const {node,ancestry}=hits[0],box=node.box;const {x,y}=inspectorPointerCenter(ancestry);
 manifest.actions.push({target:suffix,rawCenter:{x:box.left+box.width/2,y:box.bottom+box.height/2},transformedCenter:{x,y}});
 await action('pointer',{type,x,y});
}
async function requireVisible(suffix){
 const state=await action('get',{inspect:true});let found=0;
 function visit(n,path=[],shown=true){const visible=shown&&n.active!==false&&n.visible!==false;const p=[...path,n.name];if(visible&&p.join('/').endsWith(suffix))found++;for(const c of n.children??[])visit(c,p,visible)}
 for(const n of state.tree??[])visit(n);if(found!==1)throw Error(`Expected visible ${suffix}, got ${found}`);
}
async function awaitReady(){
 const deadline=performance.now()+90000;let ticks=0;
 while(!last?.logs?.some(l=>l.text.includes('FIGMA_SLICE_READY'))){
  if(performance.now()>deadline)throw Error('Fixture did not reach FIGMA_SLICE_READY within90s');
  await action('step',{dt:.05});ticks++;
 }
 manifest.fixturePreparation={ticks,simulationTime:last.time,scope:'actual incremental fixture gameplay before captured presentation'};
}

let handle;
try{await b.request('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'native-scene-evidence',version:'1'}});({handle}=unpack(await b.call('qxqy_project_open',{path:source})));await action('start');await awaitReady();await shot('desktop-initial');await clickSuffix('/node9/hit','move');await action('step',{dt:.1});await shot('sealed-hover');await requireVisible('/mapTooltip');await clickSuffix('/node9/hit');await capture();await steps(4);await shot('sealed-click');if(last.logs?.some(l=>/FIGMA_SLICE_CHOOSE \S+ true/.test(l.text)))throw Error('Sealed node entered');await clickSuffix('/node8/hit','move');await capture();await steps(2);await shot('hover-node8');await requireVisible('/mapTooltip');await clickSuffix('/menuHit');await shot('menu-open');await capture();await steps(2);await clickSuffix('/menuHelpHit');await shot('menu-help');await requireVisible('/menuHelp');await capture();await steps(2);await clickSuffix('/menuDismiss');await clickSuffix('/menuHit');await clickSuffix('/menuLegend');await shot('legend-collapsed');await clickSuffix('/menuHit');await clickSuffix('/menuLegend');await shot('legend-restored');await action('pointer',{type:'move',x:800,y:850});await capture();await steps(5);await clickSuffix(process.env.TARGET_SUFFIX||'/node8/hit');await capture();await steps(12);await shot('entered-room');if(!last.logs?.some(l=>/FIGMA_SLICE_CHOOSE \S+ true/.test(l.text)))throw Error('Real node entry not observed');await clickSuffix('/roomRoute/hit');await shot('readonly-map');await capture();await steps(5);await clickSuffix('/previewReturn/hit');await shot('returned-room');await capture();await steps(3);manifest.status='passed';console.log(out);
}catch(e){manifest.status='failed';manifest.error=e.message;throw e}finally{manifest.finishedAt=new Date().toISOString();writeFileSync(out+'/capture-manifest.json',JSON.stringify(manifest,null,2));b.close()}
