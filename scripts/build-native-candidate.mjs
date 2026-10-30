import {portraitInputs,portraitModule,bindPortraitTemplates,portraitRuntimeInventory} from './official-portraits.mjs';
import {readyArtSourceInputs,readyArtImageTemplate,readyArtGroupTemplate,bindReadyArtTemplates,readyArtRuntimeInventory} from './art/ready-card-runtime.mjs';
import { backgroundInputs, backgroundModule, backgroundTemplate, bindBackgroundTemplate, backgroundRuntimeInventory } from './official-background.mjs';
import { readFileSync, readdirSync, mkdirSync, writeFileSync, copyFileSync, constants, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileRecord, inside, sha256, writeExclusive, prepareOutputDirectory } from './evidence-files.mjs';
import { requireStartupEvidence } from './native-playtest-evidence.mjs';
import { settlementGraphSource } from './settlement-graph.mjs';
import { nativeUiVariables, candidateScriptFiles } from './native-candidate-scripts.mjs';
import { loadReleaseNotes, notesSha256, gitSourceIdentity, releaseBuildArgs } from './release-notes.mjs';
import { toLua } from './build-lua-data.mjs';
import { nativeCardArtArgs, prepareNativeCardArt, nativeCardArtBuildReceipt, verifyNativeCardArtReceipt } from './card-art-samples.mjs';

export const generatedRuntimeModules = {
  abyss_data:'scripts/build-lua-data.mjs', abyss_original_v4_data:'scripts/build-lua-data.mjs', abyss_theme:'scripts/build-ui.mjs',
  [backgroundModule]:'scripts/build-ui.mjs', [portraitModule]:'scripts/build-ui.mjs', abyss_ready_card_binding:'scripts/build-ui.mjs', abyss_ready_card_assets:'scripts/build-ui.mjs',
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
  for(const file of ['package.json','package-lock.json','CHANGELOG.md','.release-please-manifest.json',
    'release-please-config.json','tools/render_traveler_cards.py','config/architecture.json', ...backgroundInputs, ...readyArtSourceInputs(root),...portraitInputs]) {
    try { fileRecord(join(root,file)); files.push(file); } catch(error) { if(error.code!=='ENOENT')throw error; }
  }
  return files.sort().map(path=>{const {sha256,bytes}=fileRecord(join(root,path),root);return {path,sha256,bytes};});
}
export const payloadDigest = inputs => sha256(JSON.stringify(inputs));
function prepareBuild(root, directory, {releaseCandidate,workKey,nativeCardArt,readyCardArt}) {
  for(const args of [['scripts/build-lua-data.mjs','data',join(directory,'abyss_data.lua')],
    ['scripts/build-ui.mjs',directory,`--work-key=${workKey}`,...(readyCardArt===false?['--no-ready-card-art']:[]),...(releaseCandidate?['--release-candidate']:[]),
      ...(nativeCardArt?[`--native-card-art-registry=${nativeCardArt.registry}`,
        ...nativeCardArt.hosts.map(host=>`--native-card-art-host=${host}`)]:[])]]) {
    const result=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',timeout:60000,maxBuffer:4*1024*1024});
    if(result.error || result.status!==0)throw new Error(`Rebuild failed: ${result.error?.message || result.stderr}`);
  }
}
function checkTree(control) {
  if((control.children??[]).length>60)throw new Error(`MCP child limit: ${control.name}`);
  for(const child of control.children??[])checkTree(child);
}
export async function buildNativeCandidate({baseMap,output='build/candidates',root=process.cwd(),client,createClient,
  prepare,generatedModules=generatedRuntimeModules,sourceCommit,mcpVersion='injected-test-client',playtest=false,decodeLog,
  releaseCandidate=false,workKey='alpha-test',nativeCardArt,readyCardArt=true}={}) {
  root=resolve(root);
  if(prepare && nativeCardArt!==undefined)throw new Error('Custom prepare cannot be combined with native art options');
  if(nativeCardArt!==undefined) {
    if(!nativeCardArt || typeof nativeCardArt!=='object' || Array.isArray(nativeCardArt)
      || Object.keys(nativeCardArt).some(key=>!['registry','hosts','count'].includes(key)))throw new Error('Invalid native art options');
    if(nativeCardArt.count!==undefined) {
      if(nativeCardArt.hosts!==undefined || ![0,1,5,10].includes(nativeCardArt.count))throw new Error('Native art requires count 0/1/5/10 OR hosts');
      if(nativeCardArt.count===0)readyCardArt=false;
      nativeCardArt=nativeCardArt.count===0?undefined:{registry:nativeCardArt.registry,hosts:Array.from({length:nativeCardArt.count},(_,i)=>`battlePanel/card${i+1}`)};
    }
    if(nativeCardArt) {
      if(typeof nativeCardArt.registry!=='string'||!nativeCardArt.registry)throw new Error('Native art candidate requires a file registry');
    }
  }
  const art=prepareNativeCardArt(nativeCardArt,{root});
  if(art)nativeCardArt={...nativeCardArt,registry:art.inputPaths.at(-1)};
  if(art&&!Object.hasOwn(generatedModules,'abyss_presentation'))throw new Error('Native art requires the generated presentation module');
  const artInputs=art?.inputPaths.map(path=>fileRecord(path,root));
  const base=fileRecord(resolve(root,baseMap));
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
  let releaseNotes;
  if(releaseCandidate || existsSync(join(root,'package.json'))) {
    if(releaseCandidate && !Object.hasOwn(generatedModules,'abyss_narrative'))throw new Error('Release candidate must package the generated narrative module');
    if(releaseCandidate && gitSourceIdentity(root).sourceCommit!==sourceCommit)throw new Error('Release candidate source commit differs from checkout');
    releaseNotes=loadReleaseNotes({root,releaseCandidate,workKey,sourceIdentity:receipt});
    receipt.release={version:releaseNotes.build.version,workKey,
      ...(releaseNotes.currentNotice?{notesSha256:notesSha256(releaseNotes.currentNotice)}:{})};
  }
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
    if(prepare)await prepare(generated);else prepareBuild(root,generated,{releaseCandidate,workKey,nativeCardArt,readyCardArt});
    if(art) {
      if(payloadDigest(art.inputPaths.map(path=>fileRecord(path,root)))!==payloadDigest(artInputs))throw new Error('Native art input changed during preparation');
      receipt.nativeCardArt=nativeCardArtBuildReceipt(art,{root,directory:generated});
    }
    if(releaseCandidate && !readFileSync(join(generated,'abyss_narrative.lua'),'utf8')
      .includes(`["codeVersion"]=${toLua(releaseNotes.build.version)}`))throw new Error('Bundled code version differs from candidate provenance');
    const layout=JSON.parse(readFileSync(join(generated,'game-ui.json'),'utf8'));
    const templates=JSON.parse(readFileSync(join(generated,'game-ui-templates.json'),'utf8'));
    layout.controls.forEach(checkTree);templates.forEach(checkTree);
    const modules=new Map(candidateScriptFiles(join(root,'src/lua'),generated,Object.keys(generatedModules))
      .map(({name,sourceFile})=>[name,sourceFile]));
    if(!modules.has('abyss_ui'))throw new Error('Missing entry module abyss_ui');
    if(modules.has('abyss_ready_card_binding'))for(const name of [readyArtImageTemplate,readyArtGroupTemplate])
      if(templates.filter(t=>t.name===name).length!==1)throw Error('Ready artwork requires exactly one '+name+' template');
    if(modules.has(backgroundModule)&&templates.filter(template=>template.name===backgroundTemplate).length!==1)
      throw Error('Official background requires exactly one native image template');
    if(payloadDigest(sourceInputs(root))!==digest||fileRecord(base.path).sha256!==base.sha256)throw new Error('Build input changed during preparation');
    verifyNativeCardArtReceipt(receipt.nativeCardArt,{root});
    // Preflight missing/unreadable modules before starting any MCP process.
    for(const source of modules.values())fileRecord(source);
    client??=await createClient(workspace);
    for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeExclusive(join(workspace,`${uri.split('//')[1]}.json`),await client.readResource({uri}));
    const readyTemplates={};
    for(const template of templates) {
      const result=await call('scene_add_client_template',{template,mapPath,replace:true,outputName:'abyss-full-game-test'});
      if(template.name===readyArtImageTemplate)readyTemplates.image=result;
      if(template.name===readyArtGroupTemplate)readyTemplates.group=result;
      if(template.name===backgroundTemplate) {
        if(!modules.has(backgroundModule))throw Error('Official background template has no runtime module');
        bindBackgroundTemplate(generated,result,{root});
        receipt.officialBackground={...backgroundRuntimeInventory(generated),templateIndex:result.templateIndex,
          inputs:backgroundInputs.map(path=>fileRecord(join(root,path),root))};
      }
    }
    if(modules.has(backgroundModule)&&!receipt.officialBackground)throw Error('Official background runtime has no bound template');
    if(readyTemplates.image||readyTemplates.group){
      if(!modules.has('abyss_ready_card_binding'))throw Error('Ready card art templates lack binding module');
      bindReadyArtTemplates(generated,readyTemplates,{enabled:!art&&readyCardArt!==false});
      if(modules.has(portraitModule)){
        bindPortraitTemplates(generated,{image:readyTemplates.image,container:readyTemplates.group},{root});
        receipt.officialPortraits={...portraitRuntimeInventory(generated),imageTemplateIndex:readyTemplates.image.templateIndex,containerTemplateIndex:readyTemplates.group.templateIndex,inputs:portraitInputs.map(path=>fileRecord(join(root,path),root))};
      }
      receipt.readyCardArt={...readyArtRuntimeInventory(),imageTemplateIndex:readyTemplates.image.templateIndex,containerTemplateIndex:readyTemplates.group.templateIndex,
        enabled:!art&&readyCardArt!==false,inputs:readyArtSourceInputs(root).map(path=>fileRecord(join(root,path),root))};
    }
    if(modules.has(portraitModule)&&!receipt.officialPortraits)throw Error('Portrait runtime has no bound templates');
    const moduleDigests={};
    for(const [name,source] of modules) {
      const bytes=Buffer.from(readFileSync(fileRecord(source).path,'utf8').replace(/^\uFEFF/,'')),destination=join(payload,`${name}.lua`);
      writeFileSync(destination,name==='abyss_ui'?Buffer.concat([Buffer.from(`print("ABYSS_BUILD ${buildId}")\n`),bytes]):bytes,{flag:'wx'});
      receipt.outputs.push(fileRecord(destination,workspace));
      moduleDigests[name]=fileRecord(destination).sha256;
      await call('scene_set_client_script',{mapPath,name,sourceFile:destination,outputName:'abyss-full-game-test',
        ...(name==='abyss_ui'?{variables:nativeUiVariables()}:{})});
    }
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
    receipt.productionManifest={modules:[...modules.keys()].map(name=>({name,...fileRecord(join(payload,`${name}.lua`),workspace)})),
      layout:fileRecord(join(generated,'game-ui.json'),workspace),templates:fileRecord(join(generated,'game-ui-templates.json'),workspace)};
    receipt.checkedModules=names;receipt.warnings={count:checked.warnings,problems:checked.problems??[],review:'not_run'};
    if(payloadDigest(sourceInputs(root))!==digest||fileRecord(base.path).sha256!==base.sha256)throw new Error('Build input changed during packaging');
    verifyNativeCardArtReceipt(receipt.nativeCardArt,{root});
    if(releaseCandidate) {
      const identity=gitSourceIdentity(root);
      if(identity.sourceCommit!==sourceCommit||identity.sourceDirty!==false)throw new Error('Release candidate source identity changed during packaging');
    }
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

export async function buildNativeCandidateFromToolchain(options) {
    const toolRoot=process.env.MILIASTRA_MCP_ROOT||'D:/MiliastraTools/genshin-miliastra-mcp';
    const sdk=join(toolRoot,'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
    const {Client}=await import(pathToFileURL(join(sdk,'index.js'))),{StdioClientTransport}=await import(pathToFileURL(join(sdk,'stdio.js')));
    const {inspectDebugLog}=await import(pathToFileURL(join(toolRoot,'src/debug-log.mjs')));
    return buildNativeCandidate({...options,
      mcpVersion:JSON.parse(readFileSync(join(toolRoot,'package.json'),'utf8')).version,
      decodeLog:bytes=>inspectDebugLog(bytes,{limit:100000}),
      createClient:async workspace=>{const client=new Client({name:'abyss-native-candidate',version:'2.0'});
        await client.connect(new StdioClientTransport({command:process.execPath,args:[join(toolRoot,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));return client;}});
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const args=process.argv.slice(2),playtest=args.includes('--playtest');
    const native=nativeCardArtArgs(args.filter(arg=>arg!=='--playtest'));
    const {paths,options}=releaseBuildArgs(native.args);
    const [baseMap,output]=paths;
    if(!baseMap||paths.length>2)throw new Error('Usage: node scripts/build-native-candidate.mjs <base.gil> [output-directory] [--playtest] [--release-candidate] [--work-key=alpha-test] [--native-card-art-registry=<file> --native-card-art-count=0|1|5|10 | --native-card-art-host=<host>]');
    const receipt=await buildNativeCandidateFromToolchain({baseMap,output,playtest,...options,nativeCardArt:native.nativeCardArt,readyCardArt:native.readyCardArt});
    console.log(`Candidate receipt: ${receipt.receiptPath}\nStatic check passed. Official import/gameplay require separate evidence.`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
