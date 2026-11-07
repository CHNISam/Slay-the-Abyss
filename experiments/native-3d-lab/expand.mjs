import fs from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL} from 'node:url';
import {randomUUID} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {connect,data} from './rpc.mjs';
import {shapeTools} from './upstream-shapes.mjs';
import {prepareShapeSample} from './shapes/hexaghost.mjs';
import {install as installSelector} from './selector/install.mjs';
import {installMotionProbe} from './motion-probe.mjs';
import {installNativeEffect} from './assets/native-effect.mjs';
import {expansionControls} from './expansion-layout.mjs';
import {installAssetControls,materialSample} from './assets/specimen.mjs';
import {fileRecord,sha256,writeExclusive,prepareOutputDirectory} from '../../scripts/evidence-files.mjs';
import {embeddedScripts} from '../../scripts/native-script-inventory.mjs';
import {writeScriptBatch} from '../../scripts/native-script-batch.mjs';
import {runNativeClientCheck} from '../../scripts/native-client-check.mjs';
import {assertNativeUiCapacity} from '../../scripts/build-ui.mjs';
import {toLua} from '../../scripts/build-lua-data.mjs';
import {uiEquivalent} from './ui-readback.mjs';
const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const load=name=>import(pathToFileURL(join(toolRoot,'src',name)));
function once(source,needle,replacement){if(source.split(needle).length!==2)throw Error('Expansion anchor changed: '+needle);return source.replace(needle,replacement)}
export function expansionEntry(source,oldId,newId){
 if(source.includes('local expansion'))throw Error('Expansion anchor changed: entry already extended');
 let s=source.replaceAll('\r\n','\n').replaceAll(oldId,newId);
 s=once(s,'local lab','local expansion\nlocal lab');
 s=once(s,'        script:EnableUpdate(true)',`        expansion = require('abyss_3d_expansion').attach(view,script.object,{
            lab=lab,log=lab.log,
            send=function(name,params)
                local signal=game.ServerSignal(name)
                for _,p in ipairs(params)do
                    if p.type=='integer'then signal:AddInt(p.value)
                    elseif p.type=='string'then signal:AddString(p.value)
                    else error('unsupported expansion signal parameter')end
                end
                signal:SendSignal()
            end,
            register=function(name,callback)
                script:RegisterServerSignalHandler(name,function(_,params)callback(params)end)
            end,
        })
        script:EnableUpdate(true)`);
 s=once(s,'        view:update(dt)','        view:update(dt)\n        if expansion then expansion:update(dt)end');
 return once(s,'function OnDestroy()','function OnDestroy()\n    if expansion then pcall(function()expansion:destroy()end);expansion=nil end');
}
function inputFiles(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>{
 if(e.name.startsWith('.')||['preview','manifest','tests'].includes(e.name)||/\.test\.(lua|mjs)$/.test(e.name))return [];
 const p=join(dir,e.name);return e.isDirectory()?inputFiles(p):/\.(mjs|lua|json)$/.test(e.name)?[fileRecord(p)]:[];
})}
export async function expandLab({baseReceipt,output='.artifacts/native-3d-expanded'}={}){
 const base=JSON.parse(fs.readFileSync(baseReceipt));
 if(base.statuses.staticCheck!=='pass'||fileRecord(base.mapPath).sha256!==base.candidate.sha256)throw Error('Frozen experiment base differs');
 const buildId=randomUUID(),workspace=join(prepareOutputDirectory(process.cwd(),output),buildId);fs.mkdirSync(workspace);
 let mapPath=join(workspace,'base.gil');fs.copyFileSync(base.mapPath,mapPath);
 const inputs=inputFiles(resolve('experiments/native-3d-lab'));
 const receipt={buildId,kind:'expanded_same_task_lab',task:'TASK-102',basedOn:fileRecord(baseReceipt),inputs,
  sourceCommit:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8',windowsHide:true}).trim(),
  sourceDirty:Boolean(execFileSync('git',['status','--porcelain'],{encoding:'utf8',windowsHide:true}).trim()),
  startedAt:new Date().toISOString(),operations:[],liveWriteEnabled:false,
  statuses:{staticCheck:'not_run',officialImport:'not_run',runtimeReady:'not_run',shapeMotion:'not_run',selectorTransaction:'not_run',mobile:'unverified'}};
 const c=await connect(workspace),shapes=await shapeTools(workspace);receipt.shapeToolchain=shapes.provenance;
 const wire=await load('scene/wire.mjs');
 const {clientScriptRecord,addClientUi,getClientUi}=await load('scene-save.mjs');
 const {luaSyntaxError}=await load('client-check.mjs');let n=0;
 const call=async(name,args={})=>{
  const request={mapPath,...args};
  const raw=/^scene_(add_shape_prefab|preview_shapes)$/.test(name)?await shapes.call(name,request):await c.callTool({name,arguments:request},undefined,{timeout:180000});
  const response=join(workspace,`${++n}-${name}.json`);writeExclusive(response,raw);
  const result=data(raw);if(result.error)throw Error(name+': '+JSON.stringify(result.error));
  receipt.operations.push({name,response:fileRecord(response)});if(result.mapPath)mapPath=result.mapPath;return result;
 };
 try{
  for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeExclusive(join(workspace,uri.split('//')[1]+'.json'),await c.readResource({uri}));
  const before=embeddedScripts({mapPath,includeSource:true},wire).scripts;
  if(before.length!==base.modules.length||before.some(s=>base.modules.find(m=>m.name===s.name)?.sha256!==sha256(s.source)))throw Error('Base modules differ');
  const layout=getClientUi({mapPath,ui:base.uiWrite.name||'SlayTheAbyss'}).interface;
  receipt.shape=await prepareShapeSample({call,mapPath});
  receipt.selector=await installSelector({call,mapPath,output:join(workspace,'selector')});
  receipt.motionProbe=await installMotionProbe({call,nativeScene:base.nativeScene});
  receipt.nativeEffect=await installNativeEffect({call,nativeScene:base.nativeScene});
  installAssetControls(layout);layout.controls.find(s=>s.name==='stage').children.push(expansionControls());assertNativeUiCapacity(layout);
  writeExclusive(join(workspace,'layout.json'),layout);
  const config={buildId,shape:receipt.shape.bridge,selector:receipt.selector.config,material:materialSample};
  const source=name=>fs.readFileSync(join('experiments/native-3d-lab',name),'utf8');
  const updates=[{name:'abyss_ui',source:expansionEntry(before.find(s=>s.name==='abyss_ui').source,base.buildId,buildId)},
   {name:'abyss_3d_lab',source:source('runtime.lua')},
   {name:'abyss_3d_expansion',source:source('expansion-runtime.lua')},
   {name:'abyss_3d_selector',source:source('selector/runtime.lua')},
   {name:'abyss_3d_selector_fixture',source:source('selector/fixture.lua')},
   {name:'abyss_3d_material_sample',source:source('assets/runtime.lua')},
   {name:'abyss_3d_expansion_config',source:'return '+toLua(config)+'\n'},
   {name:'abyss_3d_lab_config',source:before.find(s=>s.name==='abyss_3d_lab_config').source.replaceAll(base.buildId,buildId).replace(/}\s*$/,',motionDiagnostic=true}\n')}];
  for(const u of updates)fs.writeFileSync(join(workspace,u.name+'.lua'),u.source);
  mapPath=writeScriptBatch(mapPath,updates,workspace,{...wire,clientScriptRecord,luaSyntaxError});
  const ui=addClientUi({...layout,mapPath,replace:true,outputName:'native-3d-expanded'},workspace);mapPath=ui.mapPath;
  const checked=runNativeClientCheck({mapPath},toolRoot);writeExclusive(join(workspace,'client-check.json'),checked);
  if(checked.ok!==true||checked.errors!==0)throw Error('Expanded static check failed');
  const expected=new Map(before.map(s=>[s.name,s.source]));for(const u of updates)expected.set(u.name,u.source);
  const actual=embeddedScripts({mapPath,includeSource:true},wire).scripts;
  if(actual.length!==expected.size||actual.some(s=>expected.get(s.name)!==s.source))throw Error('Expanded script readback differs');
  const readback=getClientUi({mapPath,ui:layout.name});writeExclusive(join(workspace,'ui-readback.json'),readback);
  if(!uiEquivalent(layout,readback.interface))throw Error('Expanded UI readback differs');
  for(const p of inputs)if(fileRecord(p.path).sha256!==p.sha256)throw Error('Expansion input changed during build');
  receipt.modules=actual.map(s=>({name:s.name,sha256:sha256(s.source)}));receipt.clientCheck={errors:checked.errors,warnings:checked.warnings};
  receipt.uiWrite=ui;receipt.mapPath=join(workspace,'native-3d-expanded.gil');fs.copyFileSync(mapPath,receipt.mapPath);
  receipt.candidate=fileRecord(receipt.mapPath);receipt.statuses.staticCheck='pass';receipt.completedAt=new Date().toISOString();
  writeExclusive(join(workspace,'experiment.json'),receipt);return receipt;
 }catch(e){receipt.error=e.message;writeExclusive(join(workspace,'failure.json'),receipt);throw e}finally{await c.close()}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 try{const r=await expandLab({baseReceipt:process.argv[2]});console.log(JSON.stringify({buildId:r.buildId,mapPath:r.mapPath,sha256:r.candidate.sha256,statuses:r.statuses}));}
 catch(e){console.error(e.stack);process.exitCode=1}
}
