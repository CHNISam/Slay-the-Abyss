import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, linkSync, symlinkSync, realpathSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import { buildNativeCandidate, payloadDigest, sourceInputs } from '../scripts/build-native-candidate.mjs';
import { fileRecord, sha256 } from '../scripts/evidence-files.mjs';

const repo = fileURLToPath(new URL('..', import.meta.url));
const builder = join(repo, 'scripts/build-native-candidate.mjs');
const sdk = `
import {appendFileSync,readFileSync} from 'node:fs';
const scripts=new Map([['abyss_stale',{name:'abyss_stale',file:'abyss_stale.lua',source:'old'}]]);
export class Client {
 async connect(transport) {appendFileSync(process.env.ART_CALLS,JSON.stringify({name:'connect',liveWrite:transport.options.env.MILIASTRA_ALLOW_LIVE_WRITE})+'\\n');}
 async close() {}
 async readResource({uri}) {return {contents:[{uri,text:'MCP mock; not official compile'}]};}
 async callTool({name,arguments:args}) {
  appendFileSync(process.env.ART_CALLS,JSON.stringify({name,args})+'\\n');
  if(name==='scene_set_client_script')scripts.set(args.name,{name:args.name,file:args.name+'.lua',source:readFileSync(args.sourceFile,'utf8')});
  if(name==='scene_remove_client'){scripts.delete(args.script);return {structuredContent:{removed:{script:args.script}}};}
  if(name==='scene_list_client_scripts')return {structuredContent:{scripts:[...scripts.values()]}};
  if(name==='inspect_map')return {structuredContent:{graphs:[{id:23,name:'_GSTS_ABYSS_SETTLEMENT',type:20000,writable:true}]}};
  if(name==='scene_list_signals')return {structuredContent:{signals:['ABYSS_WIN','ABYSS_LOSE']}};
  if(name==='write_graphs')return {structuredContent:{written:[23]}};
  if(name==='scene_check_client')return {structuredContent:{ok:true,errors:0,warnings:0,checked:[...scripts.keys()]}};
  return {structuredContent:{mapPath:args.mapPath}};
 }
}
`;
function fixture(t) {
  mkdirSync(join(repo,'build'),{recursive:true});
  const root=mkdtempSync(join(repo,'build/native-art-entry-'));
  t.after(()=>rmSync(root,{recursive:true,force:true}));
  for(const file of ['src/lua','data','scripts','tools','package.json','package-lock.json','CHANGELOG.md','.release-please-manifest.json'])
    cpSync(join(repo,file),join(root,file),{recursive:true});
  const put=(file,bytes)=>{const path=join(root,file);mkdirSync(dirname(path),{recursive:true});writeFileSync(path,bytes);return path;};
  const registry={schemaVersion:2,editorCommit:'103025f9095d8089e3f9bf097f4d0c5fe039d546',canvas:[144,64],assets:{},sourceInputs:[]};
  for(const id of ['cleave','heavy_blade']) {
    const asset={cardId:id};
    for(const kind of ['lua','json']) {
      const bytes=`MCP mock source ${id} ${kind}`,path=put(`art/${id}/native-art.${kind}`,bytes);
      asset[kind+'Sha256']=sha256(bytes);registry.sourceInputs.push({cardId:id,kind,path,sha256:sha256(bytes)});
    }
    asset.slots=[{image:106056,imageType:'basic',position:[1.25,2.5],size:[3,4],rotation:[11,22,33],scale:[1,1],pivot:[.5,.5],anchorMin:[.5,.5],anchorMax:[.5,.5],colour:[10,20,30,255]}];
    registry.assets[id]=asset;
  }
  const literal=put('art/registry.json',JSON.stringify(registry)),baseMap=put('base.gil','MCP mock base, not a real GIL'),callsFile=put('calls.jsonl','');
  const tool=join(root,'tool');
  put('tool/package.json','{"type":"module","version":"MCP-mock"}');
  put('tool/src/debug-log.mjs','export function inspectDebugLog(){throw Error("unexpected playtest");}');
  put('tool/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js',sdk);
  put('tool/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js','export class StdioClientTransport {constructor(options){this.options=options;}}');
  function execute(args) {
    writeFileSync(callsFile,'');
    const result=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',timeout:60000,maxBuffer:1024*1024,
      env:{...process.env,MILIASTRA_MCP_ROOT:tool,ART_CALLS:callsFile}});
    const calls=readFileSync(callsFile,'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
    return {result,calls,receipt:()=>JSON.parse(readFileSync(result.stdout.match(/Candidate receipt: (.+)/)[1],'utf8'))};
  }
  const cli=(args=[])=>execute([builder,baseMap,'output',...args]);
  const api=options=>execute(['--input-type=module','-e',`import {buildNativeCandidateFromToolchain as build} from ${JSON.stringify(pathToFileURL(builder).href)};
    const receipt=await build(${JSON.stringify({root,baseMap,output:'output',...options})});console.log('Candidate receipt: '+receipt.receiptPath);`]);
  return {root,put,literal,registry,baseMap,cli,api};
}
function pools(tree){const found=[];function visit(n,p=''){if(n.name==='artSamples')found.push({path:p,pool:n});for(const c of n.children??n.controls??[])visit(c,p+'/'+(n.name??''));}visit(tree);return found;}
const success=run=>assert.equal(run.result.status,0,run.result.stderr);

test('MCP mock: formal CLI consumes opt-in art in the actual UI and dynamic presentation, baseline stays zero',t=>{
  const f=fixture(t);
  // Shared build:ui output must not be mistaken for the per-candidate payload.
  const prebuilt=spawnSync(process.execPath,['scripts/build-ui.mjs','build/lua',`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1'],{cwd:f.root,encoding:'utf8'});
  assert.equal(prebuilt.status,0,prebuilt.stderr);
  const baseline=f.cli();success(baseline);
  assert.equal(pools(baseline.calls.find(c=>c.name==='scene_add_client_ui').args).length,0);
  const one=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);success(one);
  const ui=one.calls.find(c=>c.name==='scene_add_client_ui').args,selected=pools(ui);
  assert.equal(selected.length,1);assert(selected[0].path.endsWith('/battlePanel/card1'));
  assert.equal(selected[0].pool.children[0].children.length,1);
  const script=one.calls.find(c=>c.name==='scene_set_client_script'&&c.args.name==='abyss_presentation').args;
  const presentation=readFileSync(script.sourceFile,'utf8');
  assert.match(presentation,/\["nativeArt"\]/);assert.match(presentation,/\["rotation"\]=\{11,22,33\}/);
  const receipt=one.receipt();
  assert.equal(receipt.nativeCardArt.registrySha256,fileRecord(f.literal).sha256);
  assert.equal(receipt.nativeCardArt.staticPools,1);assert.equal(receipt.nativeCardArt.staticAddedControls,3);
  assert.deepEqual(receipt.nativeCardArt.inputs.map(r=>r.sha256).sort(),[fileRecord(f.literal),...f.registry.sourceInputs.map(r=>fileRecord(r.path))].map(r=>r.sha256).sort());
  assert.equal(receipt.nativeCardArt.inputDigest,payloadDigest(receipt.nativeCardArt.inputs));
  assert.equal(receipt.payloadDigest,payloadDigest(sourceInputs(f.root)),'ordinary payload contract stays compatible');
  assert.equal(receipt.moduleDigests.abyss_presentation,sha256(presentation));
  assert(receipt.nativeCardArt.outputs.some(r=>r.sha256===sha256(presentation)));
  assert.equal(one.calls.find(c=>c.name==='connect').liveWrite,'0');
  assert.equal(receipt.statuses.playtest,'not_run');assert.equal(receipt.liveWriteEnabled,false);
  assert(!one.calls.some(c=>c.name.startsWith('playtest')));
  assert.deepEqual(one.calls.filter(c=>c.name==='scene_remove_client').map(c=>c.args.script),['abyss_stale']);
  assert.equal(one.calls.find(c=>c.name==='write_graphs').args.graphs[0].graphId,23);
  assert.deepEqual(one.calls.find(c=>c.name==='scene_set_client_script'&&c.args.name==='abyss_ui').args.variables,
    [{name:'nativeBgmEnabled',type:'boolean',value:false},{name:'experimentalCharacters',type:'boolean',value:false}]);
  assert(!one.calls.some(c=>c.name==='scene_add_graph'||c.name==='scene_add_signal'));
  assert(one.calls.some(c=>c.name==='scene_list_client_scripts'&&c.args.includeSource));
  const disabled=f.cli(['--native-card-art-count=0']);success(disabled);
  assert.equal(pools(disabled.calls.find(c=>c.name==='scene_add_client_ui').args).length,0);
  assert.equal(disabled.receipt().nativeCardArt,undefined);
});

test('MCP mock: native API cannot silently discard art or custom prepare protections',async t=>{
  const f=fixture(t);let connected=0,prepared=0;
  await assert.rejects(buildNativeCandidate({root:f.root,baseMap:f.baseMap,output:'output',
    nativeCardArt:{registry:f.literal,hosts:['battlePanel/card1']},prepare:dir=>{
      prepared++;writeFileSync(join(dir,'game-ui.json'),'{}');writeFileSync(join(dir,'game-ui-templates.json'),'[]');
    },createClient:()=>{connected++;throw new Error('custom prepare was incorrectly allowed');}}),/custom prepare.*native art|native art.*custom prepare/i);
  assert.equal(prepared,0);assert.equal(connected,0);
});

test('MCP mock: changed original source fails before client creation',t=>{
  const f=fixture(t);writeFileSync(f.registry.sourceInputs[0].path,'changed');
  const run=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);
  assert.notEqual(run.result.status,0);assert.match(run.result.stderr,/source hash mismatch/);assert.deepEqual(run.calls,[]);
});

test('MCP mock: UI acceptance rejects changed art provenance but retains ordinary payload validation',async t=>{
  const f=fixture(t),baseline=f.cli();success(baseline);
  const {verifyUiCandidateInputs}=await import('../scripts/verify-ui-acceptance.mjs');
  const plain=baseline.receipt();assert.doesNotThrow(()=>verifyUiCandidateInputs(plain,plain.mapPath,{root:f.root}));
  const one=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);success(one);
  const receipt=one.receipt();assert.doesNotThrow(()=>verifyUiCandidateInputs(receipt,receipt.mapPath,{root:f.root}));
  for(const record of [...receipt.nativeCardArt.inputs,...receipt.nativeCardArt.outputs]) {
    const original=readFileSync(record.path);writeFileSync(record.path,Buffer.concat([original,Buffer.from('\n')]));
    assert.throws(()=>verifyUiCandidateInputs(receipt,receipt.mapPath,{root:f.root}),/Native art.*changed/);
    writeFileSync(record.path,original);
  }
});

test('MCP mock: audio wrapper preserves full art receipt and rejects input changes before or during packaging',async t=>{
  const f=fixture(t),one=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);success(one);
  const full=one.receipt();
  const {buildNativeAudioGame}=await import('../scripts/build-native-audio-game.mjs');
  let runs=0;
  const packageAudio=mutate=>buildNativeAudioGame({root:f.root,baseMap:f.baseMap,output:'audio',buildFull:async()=>full,
    run:(script,[base,directory])=>{
      runs++;mkdirSync(directory,{recursive:true});const mapPath=join(directory,'audio.gil');writeFileSync(mapPath,'MCP mock audio');
      writeFileSync(join(directory,'candidate.json'),JSON.stringify({mapPath,sha256:fileRecord(mapPath).sha256,candidate:fileRecord(mapPath),
        baseSha256:full.candidate.sha256,baseAfter:full.candidate.sha256,buildId:full.buildId}));
      mutate?.();
    }});
  const audio=await packageAudio();assert.deepEqual(audio.nativeCardArt,full.nativeCardArt);
  const original=readFileSync(f.literal);writeFileSync(f.literal,Buffer.concat([original,Buffer.from('\n')]));
  await assert.rejects(packageAudio(),/Native art.*changed/);assert.equal(runs,1,'stale art must not start audio packaging');
  writeFileSync(f.literal,original);
  await assert.rejects(packageAudio(()=>writeFileSync(f.registry.sourceInputs[0].path,'changed during audio')),/Native art.*changed/);
});

for(const [label,tail,pattern] of [
  ['original source',f=>`writeFileSync(${JSON.stringify(f.registry.sourceInputs[0].path)},'changed after generation');`,/Native art input changed/],
  ['registry',f=>`writeFileSync(${JSON.stringify(f.literal)},readFileSync(${JSON.stringify(f.literal)},'utf8')+' ');`,/Native art input changed/],
  ['ordinary source',f=>`writeFileSync('data/cards.json',readFileSync('data/cards.json','utf8')+' ');`,/Build input changed/],
  ['layout consumption',f=>`writeFileSync(join(process.argv[2],'game-ui.json'),'{"controls":[]}');`,/layout.*consume/],
  ['presentation consumption',f=>`writeFileSync(join(process.argv[2],'abyss_presentation.lua'),'return {}');`,/presentation.*consume/],
  ['presentation card identity',f=>`const presentation=join(process.argv[2],'abyss_presentation.lua');writeFileSync(presentation,readFileSync(presentation,'utf8').replace('[\"cleave\"]=', '[\"not_cleave\"]='));`,/presentation.*consume/],
  ['comment-only presentation',f=>`const presentation=join(process.argv[2],'abyss_presentation.lua');writeFileSync(presentation,'--[=['+readFileSync(presentation,'utf8')+']=]'+String.fromCharCode(10)+'return {}');`,/presentation.*consume/],
  ['shadowed card table',f=>`const presentation=join(process.argv[2],'abyss_presentation.lua');writeFileSync(presentation,readFileSync(presentation,'utf8').trimEnd().slice(0,-1)+',cleave={}}');`,/presentation.*consume/],
  ['shadowed art field',f=>`const presentation=join(process.argv[2],'abyss_presentation.lua'),source=readFileSync(presentation,'utf8');
    const {default:parser}=await import('luaparse'),table=parser.parse(source,{ranges:true}).body[0].arguments[0];
    const end=table.fields.find(row=>row.key.raw==='"cleave"').value.range[1]-1;
    writeFileSync(presentation,source.slice(0,end)+',nativeArt=nil'+source.slice(end));`,/presentation.*consume/],
])test(`MCP mock: changed ${label} during prepare fails before connecting`,t=>{
  const f=fixture(t),file=join(f.root,'scripts/build-ui.mjs');writeFileSync(file,readFileSync(file,'utf8')+'\n'+tail(f));
  const run=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);
  assert.notEqual(run.result.status,0);assert.match(run.result.stderr,pattern);assert.deepEqual(run.calls,[]);
});

test('MCP mock: illegal counts/hosts/options and output aliases fail before connecting',t=>{
  const f=fixture(t);
  for(const args of [ ['--native-card-art-count=2'],['--native-card-art-count=1'],['--native-card-art-count=1','--native-card-art-count=5'],
    [`--native-card-art-registry=${f.literal}`,'--native-card-art-host=AbyssDeckCard/face'],
    [`--native-card-art-registry=${f.literal}`,'--native-card-art-host=battlePanel/card1','--native-card-art-host=battlePanel/card1'],
    ['--native-card-art-count=0','--native-card-art-host=battlePanel/card1'], ['--native-card-art-unknown=1'] ]) {
    const run=f.cli(args);assert.notEqual(run.result.status,0);assert.deepEqual(run.calls,[]);
  }
  linkSync(f.literal,join(f.root,'output'));
  const before=readFileSync(f.literal),run=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);
  assert.notEqual(run.result.status,0);assert.deepEqual(run.calls,[]);assert.deepEqual(readFileSync(f.literal),before);
});

test('MCP mock: art API requires the generated presentation in the packaged module manifest',async t=>{
  const f=fixture(t);let connected=0;
  await assert.rejects(buildNativeCandidate({root:f.root,baseMap:f.baseMap,output:'output',nativeCardArt:{registry:f.literal,count:1},
    generatedModules:{},createClient:()=>{connected++;throw Error('art was not packaged');}}),/native art.*presentation/i);
  assert.equal(connected,0);
});

test('MCP mock: explicit API host and CLI 5/10 candidates remain bounded, never implicit',async t=>{
  const f=fixture(t);
  // Accept the existing API shape, not a second renderer or inferred host expansion.
  const api=f.api({nativeCardArt:{registry:'art/registry.json',count:1}});success(api);
  assert.deepEqual(api.receipt().nativeCardArt.hosts,['battlePanel/card1']);
  const host='nodePanel/pickerView/before',run=f.cli([`--native-card-art-registry=${f.literal}`,`--native-card-art-host=${host}`]);success(run);
  assert.deepEqual(run.receipt().nativeCardArt.hosts,[host]);
  assert(pools(run.calls.find(c=>c.name==='scene_add_client_ui').args)[0].path.endsWith('/'+host));
  for(const count of [5,10]) {
    const candidate=f.cli([`--native-card-art-registry=${f.literal}`,`--native-card-art-count=${count}`]);success(candidate);
    assert.equal(pools(candidate.calls.find(c=>c.name==='scene_add_client_ui').args).length,count);
    assert.equal(candidate.receipt().nativeCardArt.staticAddedControls,3*count,'synthetic one-slot pools, not performance evidence');
  }
});

const registeredLiteral=process.env.ABYSS_NATIVE_ART_ENTRY_LITERAL;
test('MCP mock: registered Cleave/Heavy one-pool entry carries 2657/2043 slots and a 2703-control budget',{skip:!registeredLiteral},t=>{
  const f=fixture(t),registry=JSON.parse(readFileSync(registeredLiteral,'utf8'));
  for(const source of registry.sourceInputs)source.path=f.put(`art/${source.cardId}/native-art.${source.kind}`,readFileSync(source.path));
  writeFileSync(f.literal,JSON.stringify(registry));
  const run=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);success(run);
  const receipt=run.receipt();assert.equal(receipt.nativeCardArt.staticAddedControls,2703);
  assert.equal(receipt.nativeCardArt.sources.cleave.images,2657);assert.equal(receipt.nativeCardArt.sources.heavy_blade.images,2043);
  assert.equal(pools(run.calls.find(c=>c.name==='scene_add_client_ui').args).length,1);
  const presentation=readFileSync(run.calls.find(c=>c.name==='scene_set_client_script'&&c.args.name==='abyss_presentation').args.sourceFile,'utf8');
  assert.equal((presentation.match(/\["path"\]=/g)??[]).length,4700);
  console.log('MCP mock registered one-pool: '+JSON.stringify({registrySha256:receipt.nativeCardArt.registrySha256,sources:receipt.nativeCardArt.sources,controls:receipt.nativeCardArt.staticAddedControls}));
});


test('MCP mock: registry and original-source symlink/.. use filesystem identity, never lexical decoys',async t=>{
  const f=fixture(t),external=mkdtempSync(join(tmpdir(),'native-art-external-'));
  t.after(()=>rmSync(external,{recursive:true,force:true}));
  mkdirSync(join(external,'nested'));
  symlinkSync(join(external,'nested'),join(f.root,'alias'),process.platform==='win32'?'junction':'dir');
  // Same bytes outside the root still cannot be certified as a different local file.
  f.put('registry.json',readFileSync(f.literal));writeFileSync(join(external,'registry.json'),readFileSync(f.literal));
  const raw=f.root+'/alias/../registry.json';
  const {prepareNativeCardArt}=await import('../scripts/card-art-samples.mjs');
  if(realpathSync.native(raw)!==join(f.root,'registry.json')) {
    assert.throws(()=>prepareNativeCardArt({registry:raw,hosts:['battlePanel/card1']},{root:f.root}),/another root/);
    const run=f.cli([`--native-card-art-registry=${raw}`,'--native-card-art-count=1']);
    assert.notEqual(run.result.status,0);assert.match(run.result.stderr,/another root/);assert.deepEqual(run.calls,[]);
  }
  const entry=f.registry.sourceInputs[0],bytes=readFileSync(entry.path);
  f.put('native-art.lua',bytes);writeFileSync(join(external,'native-art.lua'),bytes);
  entry.path=f.root+'/alias/../native-art.lua';writeFileSync(f.literal,JSON.stringify(f.registry));
  if(realpathSync.native(entry.path)!==join(f.root,'native-art.lua')) {
    assert.throws(()=>prepareNativeCardArt({registry:f.literal,hosts:['battlePanel/card1']},{root:f.root}),/another root/);
    const run=f.cli([`--native-card-art-registry=${f.literal}`,'--native-card-art-count=1']);
    assert.notEqual(run.result.status,0);assert.match(run.result.stderr,/another root/);assert.deepEqual(run.calls,[]);
  }
});
