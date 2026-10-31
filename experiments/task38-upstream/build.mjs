import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
const tool=process.env.MILIASTRA_TOOL_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
const sdk=tool+'/node_modules/@modelcontextprotocol/sdk/dist/esm/client/';
const {Client}=await import(pathToFileURL(sdk+'index.js'));
const {StdioClientTransport}=await import(pathToFileURL(sdk+'stdio.js'));
const python=process.env.MILIASTRA_PYTHON||'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe';
const workspace=path.resolve('.artifacts/task38-upstream/build-'+Date.now());fs.mkdirSync(workspace,{recursive:true});
const upstream=path.resolve('experiments/task38-upstream/upstream/examples/pairs');
const args=JSON.parse(fs.readFileSync(upstream+'/pairs_win.json'));
const hash=p=>createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const base=path.resolve(process.argv[2]);let mapPath=workspace+'/base.gil';fs.copyFileSync(base,mapPath);
const report={stage:'UPSTREAM',upstreamCommit:'eb05fd35075b2635e851a2f58b202ac2eadd187b',baseSha256:hash(base),toolCommit:execFileSync('git',['-C',tool,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),calls:[],officialImport:'not_run',ready:'not_run',phone:'NOT_TESTED'};
const save=()=>fs.writeFileSync(workspace+'/receipt.json',JSON.stringify(report,null,2));
const client=new Client({name:'task38-upstream',version:'1'});
await client.connect(new StdioClientTransport({command:process.execPath,args:[tool+'/src/server.mjs'],cwd:tool,env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0',MILIASTRA_PYTHON:python}}));
async function call(name,a){const r=await client.callTool({name,arguments:a},undefined,{timeout:240000});report.calls.push({name,arguments:a,result:r});save();if(r.isError)throw Error(JSON.stringify(r));return r.structuredContent;}
try {
const before=await call('inspect_map',{mapPath});console.log('BASE',JSON.stringify(before).slice(0,2500));
if(before.graphs?.length)throw Error('Base contains graphs; refuse contamination');
await call('scene_list_entities',{mapPath,namePrefix:'PR_'});
for(const name of args.signals)mapPath=(await call('scene_add_signal',{mapPath,name,outputName:'pairs-signal-'+name})).mapPath;
const graphs=[];for(const {key,...g} of args.graphs){const made=await call('scene_add_graph',{mapPath,...g,outputName:'pairs-graph'});mapPath=made.mapPath;graphs.push(made);}
for(const s of args.clientScripts)mapPath=(await call('scene_set_client_script',{mapPath,name:s.name,sourceFile:upstream+'/'+s.file,variables:s.variables,outputName:'pairs-script'})).mapPath;
for(const template of args.clientTemplates)mapPath=(await call('scene_add_client_template',{mapPath,template,outputName:'pairs-template'})).mapPath;
for(const ui of args.clientUis)mapPath=(await call('scene_add_client_ui',{mapPath,...ui,outputName:'pairs-ui'})).mapPath;
await call('scene_list_prefabs',{mapPath});
const graph=graphs[0],guids=workspace+'/guids.json',source=workspace+'/stage.ts';
fs.writeFileSync(guids,JSON.stringify({'graph:id':graph.graphId,'graph:name':graph.name}));
execFileSync(python,[upstream+'/gen_pairs.py',guids,source,'0','0','0','stage']);
const written=await call('write_graphs',{mapPath,graphs:[{graphId:graph.graphId,code:fs.readFileSync(source,'utf8')}]});if(written.failed?.length)throw Error(JSON.stringify(written.failed));mapPath=written.mapPath;
await call('scene_list_components',{mapPath,prefab:'player'});await call('inspect_map',{mapPath});await call('scene_check_client',{mapPath});
const candidate=workspace+'/UPSTREAM-Pairs-eb05fd35.gil';fs.copyFileSync(mapPath,candidate);report.candidate=candidate;report.sha256=hash(candidate);save();console.log(JSON.stringify({candidate,sha256:report.sha256}));
}catch(e){report.error=String(e.stack);save();throw e;}finally{await client.close();}
