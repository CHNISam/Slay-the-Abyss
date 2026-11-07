import {readFileSync,writeFileSync,mkdirSync,copyFileSync,readdirSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {connect,data} from './rpc.mjs';
import {labControls} from './layout.mjs';
import {prepareNativeScene} from './native-scene.mjs';
import {instrumentCardTween} from './card-tween.mjs';
import {fileRecord,sha256,writeExclusive,prepareOutputDirectory} from '../../scripts/evidence-files.mjs';
import {writeScriptBatch} from '../../scripts/native-script-batch.mjs';
import {embeddedScripts} from '../../scripts/native-script-inventory.mjs';
import {runNativeClientCheck} from '../../scripts/native-client-check.mjs';
import {assertNativeUiCapacity} from '../../scripts/build-ui.mjs';
import {uiEquivalent} from './ui-readback.mjs';
import {toLua} from '../../scripts/build-lua-data.mjs';
const here=dirname(fileURLToPath(import.meta.url));
const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const toolModule=name=>import(pathToFileURL(join(toolRoot,'src',name)));

function once(source,needle,replacement){
  if(source.split(needle).length!==2)throw Error('Entry integration anchor changed: '+needle);
  return source.replace(needle,replacement);
}
export function instrumentEntry(source,buildId){
  if(!/^[a-f0-9-]{36}$/.test(buildId))throw Error('Invalid experiment build ID');
  let text=source.replace(/\r\n/g,'\n').replace(/^print\("ABYSS_BUILD [a-f0-9-]+"\)\n/,'');
  text=once(text,'local view, Viewport, background, cardArt, portraits','local lab\nlocal view, Viewport, background, cardArt, portraits');
  text=once(text,'        view:resize(width, height)\n        canvasWidth, canvasHeight = width, height',`        view:resize(width, height)
        lab = require('abyss_3d_lab').attach(view, script.object, {
            send = function(command, model, actor, sequence)
                local signal = game.ServerSignal('LAB3D_COMMAND')
                signal:AddString(command)
                signal:AddInt(model)
                signal:AddInt(actor)
                signal:AddInt(sequence)
                signal:SendSignal()
            end,
            register = function(callback)
                script:RegisterServerSignalHandler('LAB3D_ACK', function(_, params)
                    callback(params[1], params[2])
                end)
            end,
        })
        canvasWidth, canvasHeight = width, height`);
  text=once(text,'        view:update(dt)',`        view:update(dt)
        if lab then
            local updated, why = pcall(lab.update, lab, dt)
            if not updated then lab.log('ERROR update '..tostring(why)) end
        end`);
  text=once(text,'function OnDestroy()','function OnDestroy()\n    if lab then pcall(function()lab:destroy()end);lab=nil end');
  return `print("ABYSS_BUILD ${buildId}")\nprint("ABYSS_3D_LAB ${buildId}")\n${text}`;
}
export async function buildLab({productionReceipt,output='.artifacts/native-3d-lab',anchor=[0,2000.4,0]}={}){
  const root=resolve(here,'../..');
  const original=JSON.parse(readFileSync(productionReceipt,'utf8'));
  if(original.statuses?.staticCheck!=='pass'||fileRecord(original.mapPath).sha256!==original.candidate.sha256)
    throw Error('Production source candidate is missing, changed or unchecked');
  const buildId=randomUUID(),workspace=join(prepareOutputDirectory(root,output),buildId);
  mkdirSync(workspace,{recursive:true});
  let mapPath=join(workspace,'base.gil');copyFileSync(original.mapPath,mapPath);
  const inputNames=readdirSync(here).filter(n=>/\.(lua|mjs)$/.test(n));
  const inputs=[...inputNames.map(n=>fileRecord(join(here,n))),
    ...['native-candidate-audit.mjs','native-script-batch.mjs','native-client-check.mjs','native-script-inventory.mjs','build-ui.mjs','evidence-files.mjs']
      .map(n=>fileRecord(join(root,'scripts',n)))];
  const receipt={schemaVersion:1,kind:'isolated-native-3d-experiment',task:'TASK-102',buildId,
    startedAt:new Date().toISOString(),sourceCommit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8',windowsHide:true}).trim(),
    sourceDirty:Boolean(execFileSync('git',['status','--porcelain'],{cwd:root,encoding:'utf8',windowsHide:true}).trim()),
    productionSourceCommit:original.sourceCommit,productionReceipt:fileRecord(productionReceipt),
    productionCandidate:original.candidate,inputs,liveWriteEnabled:false,operations:[],
    statuses:{staticCheck:'not_run',officialImport:'not_run',runtimeReady:'not_run',visualAnimations:'not_run',mobile:'not_run'}};
  const client=await connect(workspace);
  const {container,fields,field,one,replace,wrap}=await toolModule('scene/wire.mjs');
  const {clientScriptRecord,addClientUi,getClientUi}=await toolModule('scene-save.mjs');
  const {luaSyntaxError}=await toolModule('client-check.mjs');
  const wire={container,fields,field,one,replace,wrap};
  let sequence=0;
  async function call(name,args={}){
    const request={name,arguments:{mapPath,...args}};
    const result=await client.callTool(request,undefined,{timeout:120000});
    const record=join(workspace,`${++sequence}-${name}.json`);writeExclusive(record,result);
    const value=data(result);if(value.error)throw Error(name+': '+JSON.stringify(value.error));
    receipt.operations.push({name,response:fileRecord(record)});
    if(value.mapPath)mapPath=value.mapPath;
    return value;
  }
  try{
    for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeExclusive(join(workspace,uri.split('//')[1]+'.json'),await client.readResource({uri}));
    const native=await prepareNativeScene({call,mapPath,anchor});
    if(native.mapPath)mapPath=native.mapPath;
    receipt.nativeScene=native;
    const layout=JSON.parse(readFileSync(original.productionManifest?.layout?.path||join(dirname(productionReceipt),'generated/game-ui.json'),'utf8'));
    const stage=layout.controls.find(n=>n.name==='stage');
    if(!stage||stage.children.some(n=>n.name==='labPanel'))throw Error('Expected fresh production stage');
    stage.children.push(labControls());assertNativeUiCapacity(layout);
    writeExclusive(join(workspace,'game-ui.json'),layout);
    const before=embeddedScripts({mapPath,includeSource:true},wire).scripts;
    const entry=before.find(n=>n.name==='abyss_ui');if(!entry)throw Error('Missing production entry');
    const config={buildId,nativeAvailable:native.available!==false,reason:native.reason||'',
      models:native.capabilities?.models||[{name:'遗迹守卫',hit:true},{name:'大型风史莱姆',hit:false},{name:'打手丘丘人',hit:false}],
      deathClip:false,playerAnimation:false,maxActors:native.capabilities?.actors||3};
    const cardView=before.find(n=>n.name==='abyss_battle_card_view');if(!cardView)throw Error('Missing production card view');
    const updates=[{name:'abyss_ui',source:instrumentEntry(entry.source,buildId)},
      {name:'abyss_3d_lab',source:readFileSync(join(here,'runtime.lua'),'utf8')},
      {name:'abyss_3d_lab_config',source:'return '+toLua(config)+'\n'},
      {name:'abyss_3d_card_tween',source:readFileSync(join(here,'card-tween.lua'),'utf8')},
      {name:'abyss_battle_card_view',source:instrumentCardTween(cardView.source)}];
    for(const update of updates)writeFileSync(join(workspace,update.name+'.lua'),update.source,{flag:'wx'});
    mapPath=writeScriptBatch(mapPath,updates,workspace,{...wire,clientScriptRecord,luaSyntaxError});
    const ui=addClientUi({...layout,mapPath,replace:true,outputName:'native-3d-lab'},workspace);
    if(!ui.mapPath)throw Error('UI encoder returned no candidate');mapPath=ui.mapPath;
    receipt.uiWrite=ui;
    const checked=runNativeClientCheck({mapPath},toolRoot);writeExclusive(join(workspace,'client-check.json'),checked);
    if(checked.ok!==true||checked.errors!==0)throw Error('Native client script check failed; inspect client-check.json');
    receipt.clientCheck={checked:checked.checked,warnings:checked.warnings,problems:checked.problems};
    const actual=embeddedScripts({mapPath,includeSource:true},wire).scripts;
    const expected=new Map(before.map(n=>[n.name,n.source]));for(const u of updates)expected.set(u.name,u.source);
    if(actual.length!==expected.size||actual.some(n=>expected.get(n.name)!==n.source))throw Error('Final embedded script readback differs');
    receipt.modules=actual.map(n=>({name:n.name,sha256:sha256(n.source),bytes:Buffer.byteLength(n.source)}));
    receipt.payloadDigest=sha256(JSON.stringify({productionPayload:original.payloadDigest,inputs,modules:receipt.modules,nativeConfig:config}));
    const uiRead=getClientUi({mapPath,ui:layout.name});writeExclusive(join(workspace,'ui-readback.json'),uiRead);
    if(!uiEquivalent(layout,uiRead.interface))throw Error('Final UI readback differs; inspect ui-readback.json');
    receipt.uiReadbackKeys=Object.keys(uiRead);
    for(const input of inputs)if(fileRecord(input.path).sha256!==input.sha256)throw Error('Experiment input changed during build');
    const finalMap=join(workspace,'native-3d-lab.gil');copyFileSync(mapPath,finalMap);
    receipt.mapPath=finalMap;receipt.candidate=fileRecord(finalMap);receipt.statuses.staticCheck='pass';
    receipt.completedAt=new Date().toISOString();writeExclusive(join(workspace,'experiment.json'),receipt);
    return receipt;
  }catch(error){receipt.error=error.message;writeExclusive(join(workspace,'failure.json'),receipt);throw error}
  finally{await client.close()}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
  try{const r=await buildLab({productionReceipt:process.argv[2],...(process.argv[3]?{output:process.argv[3]}:{})});console.log(JSON.stringify({mapPath:r.mapPath,sha256:r.candidate.sha256,statuses:r.statuses}));}
  catch(e){console.error(e.stack);process.exitCode=1}
}
