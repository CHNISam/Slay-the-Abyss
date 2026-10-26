import { readFileSync, readdirSync, mkdirSync, writeFileSync, copyFileSync, constants } from 'node:fs';
import { resolve, join, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileRecord, inside, sha256, writeExclusive, prepareOutputDirectory } from './evidence-files.mjs';
import { requireStartupEvidence } from './native-playtest-evidence.mjs';
import { settlementGraphSource } from './settlement-graph.mjs';

export const generatedRuntimeModules = {
  abyss_data:'scripts/build-lua-data.mjs', abyss_original_v4_data:'scripts/build-lua-data.mjs', abyss_theme:'scripts/build-ui.mjs',
  abyss_presentation:'scripts/build-ui.mjs', abyss_map_layout:'scripts/build-ui.mjs', abyss_narrative:'scripts/build-ui.mjs',
};
export function sourceInputs(root) {
  const files=[];
  function walk(dir) {
    for(const entry of readdirSync(join(root,dir),{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
      const name=`${dir}/${entry.name}`;
      if(entry.isDirectory())walk(name);
      else if(/\.(lua|json|mjs|py)$/.test(name))files.push(name);
    }
  }
  for(const dir of ['src/lua','data','scripts']) {
    try{walk(dir);}catch(error){if(error.code!=='ENOENT')throw error;}
  }
  for(const file of ['package.json','package-lock.json','tools/render_traveler_cards.py','config/architecture.json']) {
    try { fileRecord(join(root,file)); files.push(file); } catch(error) { if(error.code!=='ENOENT')throw error; }
  }
  return files.sort().map(path=>{const {sha256,bytes}=fileRecord(join(root,path),root);return {path,sha256,bytes};});
}
export const payloadDigest = inputs => sha256(JSON.stringify(inputs));
function prepareBuild(root, directory) {
  for(const args of [['scripts/build-lua-data.mjs','data',join(directory,'abyss_data.lua')],['scripts/build-ui.mjs',directory]]) {
    const result=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',timeout:60000,maxBuffer:4*1024*1024});
    if(result.error || result.status!==0)throw new Error(`Rebuild failed: ${result.error?.message || result.stderr}`);
  }
}
function checkTree(control) {
  if((control.children??[]).length>60)throw new Error(`MCP child limit: ${control.name}`);
  for(const child of control.children??[])checkTree(child);
}
export async function buildNativeCandidate({baseMap,output='build/candidates',root=process.cwd(),client,createClient,
  prepare=dir=>prepareBuild(root,dir),generatedModules=generatedRuntimeModules,sourceCommit,mcpVersion='injected-test-client',playtest=false,decodeLog}={}) {
  root=resolve(root); const base=fileRecord(resolve(baseMap));
  const outputRoot=prepareOutputDirectory(root,output);
  const buildId=randomUUID(),workspace=join(outputRoot,buildId); mkdirSync(workspace); inside(root,workspace);
  const generated=join(workspace,'generated'),payload=join(workspace,'payload'); mkdirSync(generated);mkdirSync(payload);
  const inputs=sourceInputs(root),digest=payloadDigest(inputs);
  sourceCommit??=spawnSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).stdout?.trim();
  if(!/^[a-f0-9]{40}$/.test(sourceCommit??''))throw new Error('Unknown source commit');
  const dirtyResult=spawnSync('git',['status','--porcelain'],{cwd:root,encoding:'utf8'});
  const receipt={schemaVersion:1,buildId,sourceCommit,sourceDirty:dirtyResult.status===0?Boolean(dirtyResult.stdout.trim()):null,
    payloadDigest:digest,startedAt:new Date().toISOString(),mcpVersion,inputs,baseMap:base,outputs:[],
    liveWriteEnabled:false,statuses:{staticCheck:'not_run',officialImport:'not_run',playtest:'not_run'}};
  let mapPath=join(workspace,'base.gil');copyFileSync(base.path,mapPath,constants.COPYFILE_EXCL);
  let sequence=0;
  async function call(name,args) {
    const result=await client.callTool({name,arguments:args},undefined,{timeout:120000});
    writeExclusive(join(workspace,`${++sequence}-${name}.json`),result);
    if(result.isError)throw new Error(`${name}: ${JSON.stringify(result)}`);
    const data=result.structuredContent??JSON.parse(result.content.find(item=>item.type==='text').text);
    if(data.error)throw new Error(`${name}: ${JSON.stringify(data)}`);
    if(data.mapPath){ const record=fileRecord(data.mapPath,workspace); if(record.path===base.path)throw new Error('Input alias returned by MCP');mapPath=record.path; }
    return data;
  }
  try {
    prepare(generated);
    const layout=JSON.parse(readFileSync(join(generated,'game-ui.json'),'utf8'));
    const templates=JSON.parse(readFileSync(join(generated,'game-ui-templates.json'),'utf8'));
    layout.controls.forEach(checkTree);templates.forEach(checkTree);
    const modules=new Map();
    for(const file of readdirSync(join(root,'src/lua')).filter(file=>file.endsWith('.lua')).sort())modules.set(basename(file,'.lua'),join(root,'src/lua',file));
    for(const name of Object.keys(generatedModules).sort()) {
      if(modules.has(name))throw new Error(`Duplicate module: ${name}`);
      modules.set(name,join(generated,`${name}.lua`));
    }
    if(!modules.has('abyss_ui'))throw new Error('Missing entry module abyss_ui');
    client??=await createClient(workspace);
    for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeExclusive(join(workspace,`${uri.split('//')[1]}.json`),await client.readResource({uri}));
    const moduleDigests={};
    for(const [name,source] of modules) {
      const bytes=Buffer.from(readFileSync(fileRecord(source).path,'utf8').replace(/^\uFEFF/,'')),destination=join(payload,`${name}.lua`);
      writeFileSync(destination,name==='abyss_ui'?Buffer.concat([Buffer.from(`print("ABYSS_BUILD ${buildId}")\n`),bytes]):bytes,{flag:'wx'});
      receipt.outputs.push(fileRecord(destination,workspace));
      moduleDigests[name]=fileRecord(destination).sha256;
      await call('scene_set_client_script',{mapPath,name,sourceFile:destination,outputName:'abyss-full-game-test',
        ...(name==='abyss_ui'?{variables:[{name:'nativeBgmEnabled',type:'boolean',value:false}]}:{})});
    }
    for(const template of templates)await call('scene_add_client_template',{template,mapPath,replace:true,outputName:'abyss-full-game-test'});
    await call('scene_add_client_ui',{...layout,mapPath,replace:true,outputName:'abyss-full-game-test'});
    // Preserve the integrated builder's ownership checks when reusing a base.
    const expectedScripts=new Set(modules.keys());
    async function scriptInventory() {
      const listed=await call('scene_list_client_scripts',{mapPath});
      if(!Array.isArray(listed.scripts)||listed.scripts.some(script=>!script
        ||typeof script.name!=='string'||typeof script.file!=='string')
        ||new Set(listed.scripts.map(script=>script.name)).size!==listed.scripts.length)
        throw new Error('Cannot read an unambiguous client script inventory');
      return listed.scripts;
    }
    const beforeScripts=await scriptInventory();
    const obsolete=beforeScripts.filter(script=>!expectedScripts.has(script.name));
    if(obsolete.some(script=>!/^abyss_[a-z0-9_]+$/.test(script.name)||script.file!==`${script.name}.lua`))
      throw new Error('Unknown client script ownership; rebuild from a clean base');
    for(const script of obsolete) {
      const removed=await call('scene_remove_client',{mapPath,script:script.name,outputName:'abyss-full-game-test'});
      if(removed.removed?.script!==script.name)throw new Error(`Client script removal was not acknowledged: ${script.name}`);
    }
    const afterScripts=await scriptInventory();
    if(afterScripts.length!==expectedScripts.size||afterScripts.some(script=>!expectedScripts.has(script.name)))
      throw new Error('Final client script inventory differs from production manifest');
    writeExclusive(join(workspace,'script-cleanup.json'),{expected:[...expectedScripts],before:beforeScripts,
      removed:obsolete.map(script=>script.name),after:afterScripts});
    await call('scene_set_player_count',{mapPath,min:1,max:1,outputName:'abyss-full-game-test'});
    const inspected=await call('inspect_map',{mapPath}),listedSignals=await call('scene_list_signals',{mapPath});
    if(!Array.isArray(inspected.graphs)||!Array.isArray(listedSignals.signals)
      ||listedSignals.signals.some(name=>typeof name!=='string'))throw new Error('Cannot read settlement graph and signal inventory');
    const matches=inspected.graphs.filter(graph=>graph.name==='_GSTS_ABYSS_SETTLEMENT');
    if(matches.length>1||matches.some(graph=>graph.type!==20000||!graph.writable
      ||!Number.isSafeInteger(graph.id)||graph.id<=0||graph.id>0xffffffff))throw new Error('Existing settlement graph is ambiguous, incompatible or not writable');
    for(const name of ['ABYSS_WIN','ABYSS_LOSE'])if(!listedSignals.signals.includes(name))
      await call('scene_add_signal',{mapPath,name,outputName:'abyss-full-game-test'});
    const graph=matches.length?{graphId:matches[0].id,name:matches[0].name}
      :await call('scene_add_graph',{mapPath,name:'ABYSS_SETTLEMENT',kind:'server',outputName:'abyss-full-game-test'});
    const code=settlementGraphSource({id:graph.graphId,name:graph.name});writeFileSync(join(workspace,'settlement.ts'),code,{flag:'wx'});
    const compiled=await call('write_graphs',{mapPath,graphs:[{graphId:graph.graphId,code}]});
    if(compiled.failed||compiled.error||compiled.errors?.length||compiled.written?.length!==1)throw new Error('Settlement graph did not compile/write completely');
    const checked=await call('scene_check_client',{mapPath});
    const names=[...modules.keys()].sort();
    if(checked.ok!==true||checked.errors!==0||!Array.isArray(checked.checked)||JSON.stringify([...checked.checked].sort())!==JSON.stringify(names))throw new Error('Candidate module check is incomplete or failed');
    const readback=await call('scene_list_client_scripts',{mapPath,includeSource:true});
    if(!Array.isArray(readback.scripts)||JSON.stringify(readback.scripts.map(row=>row.name).sort())!==JSON.stringify(names))throw new Error('Candidate readback module set differs');
    for(const row of readback.scripts)if(typeof row.source!=='string'||sha256(row.source)!==moduleDigests[row.name])throw new Error(`Candidate content digest mismatch: ${row.name}`);
    for(const record of receipt.outputs)if(fileRecord(record.path,workspace).sha256!==record.sha256)throw new Error('Packaged output changed during build');
    receipt.moduleDigests=moduleDigests;
    receipt.checkedModules=names;receipt.warnings={count:checked.warnings,problems:checked.problems??[],review:'not_run'};
    if(payloadDigest(sourceInputs(root))!==digest||fileRecord(base.path).sha256!==base.sha256)throw new Error('Build input changed during packaging');
    const finalMap=join(workspace,'candidate.gil');copyFileSync(mapPath,finalMap,constants.COPYFILE_EXCL);mapPath=finalMap;
    receipt.mapPath=mapPath;receipt.candidate=fileRecord(mapPath,workspace);receipt.outputs.push(receipt.candidate,fileRecord(join(generated,'game-ui.json')),fileRecord(join(generated,'game-ui-templates.json')));
    receipt.statuses.staticCheck='pass';receipt.completedAt=new Date().toISOString();receipt.receiptPath=join(workspace,'candidate.json');
    writeExclusive(receipt.receiptPath,receipt);
    if(playtest) {
      const startedAt=Date.now(),candidateHash=fileRecord(mapPath).sha256;
      const started=await call('playtest_start',{mapPath,durationSeconds:12,screenshotsAt:[2,8],clientScriptLog:true,graphName:graph.name});
      const expected={runId:started.runId,runDir:started.runDir,mapPath,candidateHash,buildId,startedAt};
      const deadline=Date.now()+240000;let status;
      do{status=await call('playtest_status',{runId:started.runId,waitSeconds:15});}while(status.state==='running'&&Date.now()<deadline);
      const evidence=requireStartupEvidence(status,expected,{decodeLog,parserVersion:`${mcpVersion}/inspectDebugLog`});writeExclusive(join(workspace,'startup-evidence.json'),evidence);
    }
    return receipt;
  } catch(error) {
    writeExclusive(join(workspace,'failure.json'),{...receipt,statuses:{...receipt.statuses,build:'fail'},error:error.message});throw error;
  } finally { await client?.close?.(); }
}

if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [baseMap,output,mode]=process.argv.slice(2);if(!baseMap)throw new Error('Usage: node scripts/build-native-candidate.mjs <base.gil> [output-directory] [--playtest]');
    const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
    const sdk=join(toolRoot,'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
    const {Client}=await import(pathToFileURL(join(sdk,'index.js'))),{StdioClientTransport}=await import(pathToFileURL(join(sdk,'stdio.js')));
    const {inspectDebugLog}=await import(pathToFileURL(join(toolRoot,'src/debug-log.mjs')));
    const receipt=await buildNativeCandidate({baseMap,output,playtest:mode==='--playtest',
      mcpVersion:JSON.parse(readFileSync(join(toolRoot,'package.json'),'utf8')).version,
      decodeLog:bytes=>inspectDebugLog(bytes,{limit:100000}),
      createClient:async workspace=>{const client=new Client({name:'abyss-native-candidate',version:'2.0'});
        await client.connect(new StdioClientTransport({command:process.execPath,args:[join(toolRoot,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));return client;}});
    console.log(`Candidate receipt: ${receipt.receiptPath}\nStatic check passed. Official import/gameplay require separate evidence.`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
