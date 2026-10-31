import {monsterSourceInputs,prepareMonsterArt,monsterActorTemplate,monsterPowerTemplateName,monsterActorTemplateName,monsterActorBindingModule,bindMonsterActorTemplates,monsterActorInventory} from './monster-art.mjs';
import {resolveArtFeatures,artFeatureArgs,artFeatureBuildArgs,artFeatureReceipt,artFeaturesSource,artFeatureModule} from './art-features.mjs';
import {portraitSourceInputs,lowpolySelectPath,portraitModule,bindPortraitTemplates,portraitRuntimeInventory} from './official-portraits.mjs';
import {readyArtSourceInputs,readyArtImageTemplate,readyArtGroupTemplate,bindReadyArtTemplates,readyArtRuntimeInventory} from './art/ready-card-runtime.mjs';
import { backgroundInputs, backgroundModule, backgroundTemplate, bindBackgroundTemplate, backgroundRuntimeInventory } from './official-background.mjs';
import { readFileSync, readdirSync, mkdirSync, writeFileSync, copyFileSync, constants, existsSync } from 'node:fs';
import { resolve, join, relative } from 'node:path';
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
import {reusableUi} from './native-candidate-ui-cache.mjs';
import {embeddedScripts} from './native-script-inventory.mjs';
import {runNativeClientCheck} from './native-client-check.mjs';
import {writeScriptBatch} from './native-script-batch.mjs';

export const generatedRuntimeModules = {
  abyss_data:'scripts/build-lua-data.mjs', abyss_original_v4_data:'scripts/build-lua-data.mjs', abyss_theme:'scripts/build-ui.mjs',
  [artFeatureModule]:'scripts/build-ui.mjs', [backgroundModule]:'scripts/build-ui.mjs', [portraitModule]:'scripts/build-ui.mjs', abyss_ready_card_binding:'scripts/build-ui.mjs', abyss_ready_card_assets:'scripts/build-ui.mjs',
  abyss_monster_actor_binding:'scripts/build-ui.mjs', abyss_monster_art_data:'scripts/build-ui.mjs', abyss_presentation:'scripts/build-ui.mjs', abyss_map_layout:'scripts/build-ui.mjs', abyss_narrative:'scripts/build-ui.mjs',
};
export function sourceInputs(root,{artFeatures,nativeCardArt,readyCardArt}={}) {
  const flags=resolveArtFeatures({artFeatures,nativeCardArt,readyCardArt});
  const staticOptions=nativeCardArt?.count>0?{registry:nativeCardArt.registry,hosts:Array.from({length:nativeCardArt.count},(_,i)=>`battlePanel/card${i+1}`)}:nativeCardArt;
  const staticInputs=flags.cards&&staticOptions?prepareNativeCardArt(staticOptions,{root}).inputPaths.map(path=>relative(root,path).replaceAll('\\','/')):[];
  const files=[];
  function walk(dir) {
    for(const entry of readdirSync(join(root,dir),{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
      const name=`${dir}/${entry.name}`;
      if(name==='data/presentation/native-monster-art.json'&&!flags.monsters)continue;
      if(entry.isDirectory())walk(name);
      else if(/\.(lua|json|mjs|py)$/.test(name))files.push(name);
    }
  }
  for(const dir of ['src/lua','data','scripts']) {
    try{walk(dir);}catch(error){if(error.code!=='ENOENT')throw error;}
  }
  for(const file of ['package.json','package-lock.json','CHANGELOG.md','.release-please-manifest.json',
    'release-please-config.json','tools/render_traveler_cards.py','config/architecture.json', ...(flags.menuBackground?backgroundInputs:[]), ...(flags.cards&&!nativeCardArt?readyArtSourceInputs(root):[]),...portraitSourceInputs(flags),...(flags.selectionAvatar||flags.cards?[lowpolySelectPath]:[]),...staticInputs]) {
    try { fileRecord(join(root,file)); files.push(file); } catch(error) { if(error.code!=='ENOENT')throw error; }
  }
  if(flags.monsters){
    const registry=prepareMonsterArt(JSON.parse(readFileSync(join(root,'data/presentation/native-monster-art.json'),'utf8')));
    files.push(...monsterSourceInputs,...Object.values(registry.additionalAssets??{}).flatMap(asset=>asset.sourceInputs.map(record=>record.path)));
  }
  return files.sort().map(path=>{const {sha256,bytes}=fileRecord(join(root,path),root);return {path,sha256,bytes};});
}
export const payloadDigest = inputs => sha256(JSON.stringify(inputs));
function prepareBuild(root, directory, {releaseCandidate,workKey,nativeCardArt,readyCardArt,artFeatures}) {
  for(const args of [['scripts/build-lua-data.mjs','data',join(directory,'abyss_data.lua')],
    ['scripts/build-ui.mjs',directory,...artFeatureBuildArgs(artFeatures),`--work-key=${workKey}`,...(readyCardArt===false?['--no-ready-card-art']:[]),...(releaseCandidate?['--release-candidate']:[]),
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
  prepare,writeScripts,generatedModules=generatedRuntimeModules,sourceCommit,mcpVersion='injected-test-client',playtest=false,decodeLog,
  releaseCandidate=false,workKey='alpha-test',nativeCardArt,readyCardArt,artFeatures}={}) {
  root=resolve(root);
  const flags=resolveArtFeatures({artFeatures,readyCardArt,nativeCardArt});
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
  const inputOptions={artFeatures:flags,nativeCardArt,readyCardArt};
  const inputs=sourceInputs(root,inputOptions),digest=payloadDigest(inputs);
  sourceCommit??=spawnSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).stdout?.trim();
  if(!/^[a-f0-9]{40}$/.test(sourceCommit??''))throw new Error('Unknown source commit');
  const dirtyResult=spawnSync('git',['status','--porcelain'],{cwd:root,encoding:'utf8'});
  const receipt={schemaVersion:1,buildId,artFeatures:artFeatureReceipt(flags),sourceCommit,sourceDirty:dirtyResult.status===0?Boolean(dirtyResult.stdout.trim()):null,
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
    if(prepare)await prepare(generated);else prepareBuild(root,generated,{releaseCandidate,workKey,nativeCardArt,readyCardArt,artFeatures:flags});
    if(Object.hasOwn(generatedModules,artFeatureModule)&&readFileSync(join(generated,artFeatureModule+'.lua'),'utf8')!==artFeaturesSource(flags))throw Error('Generated art feature configuration differs from candidate');
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
    const dynamicCards=flags.cards&&!art,portraits=flags.selectionAvatar||flags.battlePortrait;
    const sharedTemplates=dynamicCards||portraits||flags.menuBackground;
    const blockedTemplates=[...(!flags.menuBackground?[backgroundTemplate]:[]),...(!sharedTemplates?[readyArtImageTemplate]:[])];
    if(templates.some(template=>blockedTemplates.includes(template.name)))throw Error('Disabled artwork must not register templates');
    const blockedHosts=[...(!flags.monsters?['monsterArt','monsterSamples']:[]),...(!flags.cards?['artSamples']:[]),...(!flags.menuBackground?['officialBackground']:[]),...(!flags.selectionAvatar?['officialAvatar']:[]),...(!flags.battlePortrait?['officialFigure']:[])];
    function rejectDisabledHosts(node){
      if(blockedHosts.includes(node.name))throw Error('Disabled artwork must not register hosts');
      for(const child of node.controls??node.children??[])rejectDisabledHosts(child);
    }
    for(const tree of [layout,...templates])rejectDisabledHosts(tree);
    const requiredArtModules=[monsterActorBindingModule,...(Object.values(flags).some(Boolean)?[artFeatureModule]:[]),...(flags.menuBackground?[backgroundModule]:[]),
      ...(flags.monsters?['abyss_monster_art_data']:[]),...(dynamicCards?['abyss_ready_card_binding','abyss_ready_card_assets']:[]),...(portraits?[portraitModule]:[])];
    for(const name of requiredArtModules)if(!modules.has(name))throw Error('Enabled artwork missing runtime module: '+name);

    if(Object.hasOwn(generatedModules,'abyss_monster_art_data')) {
      let monster=null;
      if(flags.monsters){
        const registry=JSON.parse(readFileSync(join(root,'data/presentation/native-monster-art.json'),'utf8'));
        monster=prepareMonsterArt(registry);
        if(!monster)throw Error('Enabled monster artwork requires its registry');
        for(const [index,path] of monsterSourceInputs.entries())if(registry.sourceInputs?.[index]?.path!==path
          ||registry.sourceInputs[index].sha256!==registry.asset[index===0?'luaSha256':'jsonSha256'])throw Error('Monster base source provenance differs');
        const records=[...monster.sourceInputs.slice(0,2),...Object.values(monster.additionalAssets??{}).flatMap(asset=>asset.sourceInputs)];
        for(const record of records)if(fileRecord(join(root,record.path),root).sha256!==record.sha256)throw Error('Monster native source hash mismatch');
        monster.inputPaths=records.map(record=>record.path);monster.hostOrigin=[0,0];
        receipt.nativeMonsterArt={enabled:true,assetCount:Object.keys(monster.assets).length,bindingCount:Object.keys(monster.bindings).length,
          capacity:monster.poolCapacity,allocation:'per-drawable-actor-instance',
          inputs:records.map(({path})=>({...fileRecord(join(root,path),root),path}))};
      }
      const actorTemplates=templates.filter(template=>template.name===monsterActorTemplateName);
      if(actorTemplates.length!==1||JSON.stringify(actorTemplates[0])!==JSON.stringify(monsterActorTemplate(monster)))throw Error('Monster actor template differs from candidate features or source');
      const expected=`-- Generated from the bounded native monster registry.\nreturn ${toLua(monster??{})}\n`;
      if(readFileSync(join(generated,'abyss_monster_art_data.lua'),'utf8')!==expected)throw Error('Monster artwork payload differs from candidate features or source');
    }

    if(sharedTemplates)for(const name of [readyArtImageTemplate,readyArtGroupTemplate])
      if(templates.filter(t=>t.name===name).length!==1)throw Error('Ready artwork requires exactly one '+name+' template');
    for(const name of [monsterActorTemplateName,monsterPowerTemplateName,readyArtGroupTemplate])
      if(templates.filter(t=>t.name===name).length!==1)throw Error('Monster actors require exactly one '+name+' template');
    if(flags.menuBackground&&templates.filter(template=>template.name===backgroundTemplate).length!==1)
      throw Error('Official background requires exactly one native image template');
    if(payloadDigest(sourceInputs(root,inputOptions))!==digest||fileRecord(base.path).sha256!==base.sha256)throw new Error('Build input changed during preparation');
    verifyNativeCardArtReceipt(receipt.nativeCardArt,{root});
    // Preflight missing/unreadable modules before starting any MCP process.
    for(const source of modules.values())fileRecord(source);
    client??=await createClient(workspace);
    for(const uri of ['miliastra://workflow','miliastra://platform-rules'])writeExclusive(join(workspace,`${uri.split('//')[1]}.json`),await client.readResource({uri}));
    const readyTemplates={};let monsterTemplate,monsterPowerTemplate,cachedUi=reusableUi(base,generated);
    if(cachedUi){
      const cached=JSON.parse(readFileSync(cachedUi.receipt.path,'utf8')), actors=cached.monsterActors;
      if(!actors||![actors.templateIndex,actors.powerTemplateIndex,actors.containerTemplateIndex].every(n=>Number.isSafeInteger(n)&&n>0)
        ||new Set([actors.templateIndex,actors.powerTemplateIndex,actors.containerTemplateIndex]).size!==3
        ||actors.containerTemplateIndex!==cachedUi.templateResults[readyArtGroupTemplate]?.templateIndex)cachedUi=null;
      else {cachedUi.templateResults[monsterActorTemplateName]={templateIndex:actors.templateIndex};cachedUi.templateResults[monsterPowerTemplateName]={templateIndex:actors.powerTemplateIndex};}
    }
    if(cachedUi)receipt.reusedUi=cachedUi.receipt;
    for(const template of templates) {
      const result=cachedUi?(cachedUi.templateResults[template.name]??{reused:true}):await call('scene_add_client_template',{template,mapPath,replace:true,outputName:'abyss-full-game-test'});
      if(template.name===monsterActorTemplateName)monsterTemplate=result;
      if(template.name===monsterPowerTemplateName)monsterPowerTemplate=result;
      if(template.name===readyArtImageTemplate)readyTemplates.image=result;
      if(template.name===readyArtGroupTemplate)readyTemplates.group=result;
      if(template.name===backgroundTemplate) {
        if(!modules.has(backgroundModule))throw Error('Official background template has no runtime module');
        readyTemplates.background=result;
      }
    }
    if(readyTemplates.background){
      bindBackgroundTemplate(generated,readyTemplates.background,{root,containerTemplateIndex:readyTemplates.group.templateIndex});
      receipt.officialBackground={...backgroundRuntimeInventory(generated),templateIndex:readyTemplates.background.templateIndex,
        imageTemplateIndex:readyTemplates.image.templateIndex,containerTemplateIndex:readyTemplates.group.templateIndex,inputs:backgroundInputs.map(path=>fileRecord(join(root,path),root))};
    }
    if(flags.menuBackground&&!receipt.officialBackground)throw Error('Official background runtime has no bound template');
    if(readyTemplates.image||readyTemplates.group){
      if(dynamicCards){
        if(!modules.has('abyss_ready_card_binding'))throw Error('Ready card art templates lack binding module');
        bindReadyArtTemplates(generated,readyTemplates,{enabled:true});
        receipt.readyCardArt={...readyArtRuntimeInventory(generated),imageTemplateIndex:readyTemplates.image.templateIndex,containerTemplateIndex:readyTemplates.group.templateIndex,
          enabled:true,inputs:readyArtSourceInputs(root).map(path=>fileRecord(join(root,path),root))};
      }
      if(portraits){
        if(!modules.has(portraitModule))throw Error('Portrait templates lack runtime module');
        bindPortraitTemplates(generated,{image:readyTemplates.image,container:readyTemplates.group},{root,...flags});
        receipt.officialPortraits={...portraitRuntimeInventory(generated),imageTemplateIndex:readyTemplates.image.templateIndex,containerTemplateIndex:readyTemplates.group.templateIndex,
          inputs:portraitSourceInputs(flags).map(path=>fileRecord(join(root,path),root))};
      }
    }
    if(portraits&&!receipt.officialPortraits)throw Error('Portrait runtime has no bound templates');
    bindMonsterActorTemplates(generated,{actor:monsterTemplate,group:readyTemplates.group,power:monsterPowerTemplate});
    receipt.monsterActors={...monsterActorInventory(templates.find(t=>t.name===monsterActorTemplateName)),
      powerTemplateIndex:monsterPowerTemplate.templateIndex,templateIndex:monsterTemplate.templateIndex,containerTemplateIndex:readyTemplates.group.templateIndex};
    const reusable=await call('scene_list_client_scripts',{mapPath,includeSource:true});
    const existingSources=new Map((reusable.scripts??[]).filter(row=>typeof row.source==='string').map(row=>[row.name,row.source]));
    receipt.reusedModules=[];
    const moduleDigests={},pendingScripts=[];
    for(const [name,source] of modules) {
      const bytes=Buffer.from(readFileSync(fileRecord(source).path,'utf8').replace(/^\uFEFF/,'')),destination=join(payload,`${name}.lua`);
      writeFileSync(destination,name==='abyss_ui'?Buffer.concat([Buffer.from(`print("ABYSS_BUILD ${buildId}")\n`),bytes]):bytes,{flag:'wx'});
      receipt.outputs.push(fileRecord(destination,workspace));
      moduleDigests[name]=fileRecord(destination).sha256;
      if(name!=='abyss_ui'&&existingSources.get(name)===readFileSync(destination,'utf8')) {
        receipt.reusedModules.push(name);
        continue;
      }
      const update={mapPath,name,sourceFile:destination,outputName:'abyss-full-game-test',
        ...(name==='abyss_ui'?{variables:nativeUiVariables()}:{})};
      if(writeScripts)pendingScripts.push(update);else await call('scene_set_client_script',update);
    }
    if(writeScripts&&pendingScripts.length)mapPath=await writeScripts(mapPath,pendingScripts,workspace);
    if(!cachedUi)await call('scene_add_client_ui',{...layout,mapPath,replace:true,outputName:'abyss-full-game-test'});
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
    if(payloadDigest(sourceInputs(root,inputOptions))!==digest||fileRecord(base.path).sha256!==base.sha256)throw new Error('Build input changed during packaging');
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
    const {luaSyntaxError}=await import(pathToFileURL(join(toolRoot,'src/client-check.mjs')));
    const {clientScriptRecord,addClientUi}=await import(pathToFileURL(join(toolRoot,'src/scene-save.mjs')));
    const {container,fields,field,one,replace,wrap}=await import(pathToFileURL(join(toolRoot,'src/scene/wire.mjs')));
    return buildNativeCandidate({...options,
      writeScripts:async(mapPath,updates,workspace)=>{
        return writeScriptBatch(mapPath,updates,workspace,{container,fields,field,one,replace,wrap,clientScriptRecord,luaSyntaxError});
      },
      mcpVersion:JSON.parse(readFileSync(join(toolRoot,'package.json'),'utf8')).version,
      decodeLog:bytes=>inspectDebugLog(bytes,{limit:100000}),
      createClient:async workspace=>{const client=new Client({name:'abyss-native-candidate',version:'2.0'});
        await client.connect(new StdioClientTransport({command:process.execPath,args:[join(toolRoot,'src/server.mjs')],env:{...process.env,MILIASTRA_WORKSPACE:workspace,MILIASTRA_ALLOW_LIVE_WRITE:'0'}}));
        const remoteCall=client.callTool.bind(client);
        client.callTool=(request,...args)=>{
          if(request.name==='scene_check_client')return Promise.resolve({structuredContent:runNativeClientCheck(request.arguments,toolRoot)});
          if(request.name==='scene_list_client_scripts'){
            return Promise.resolve({structuredContent:embeddedScripts(request.arguments,{container,fields,one})});
          }
          // Full UI trees exceed the installed core HTTP request limit. Use the
          // same official-toolchain encoder in process, including its checks.
          if(request.name==='scene_add_client_ui')return Promise.resolve({structuredContent:addClientUi(request.arguments,workspace)});
          return remoteCall(request,...args);
        };
        return client;}});
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const args=process.argv.slice(2),playtest=args.includes('--playtest');
    const features=artFeatureArgs(args.filter(arg=>arg!=='--playtest'));
    const native=nativeCardArtArgs(features.args);
    const {paths,options}=releaseBuildArgs(native.args);
    const [baseMap,output]=paths;
    if(!baseMap||paths.length>2)throw new Error('Usage: node scripts/build-native-candidate.mjs <base.gil> [output-directory] [--playtest] [--release-candidate] [--work-key=alpha-test] [--native-card-art-registry=<file> --native-card-art-count=0|1|5|10 | --native-card-art-host=<host>]');
    const receipt=await buildNativeCandidateFromToolchain({baseMap,output,playtest,...options,artFeatures:withCandidateArtDefaults(features.artFeatures,{cardsDecided:native.nativeCardArt!==undefined||native.readyCardArt!==undefined}),nativeCardArt:native.nativeCardArt,readyCardArt:native.readyCardArt});
    console.log(`Candidate receipt: ${receipt.receiptPath}\nStatic check passed. Official import/gameplay require separate evidence.`);
  }catch(error){console.error(error.message);process.exitCode=1;}
}
