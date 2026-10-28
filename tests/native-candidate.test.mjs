import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, linkSync, symlinkSync, rmSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { loadReleaseNotes, notesSha256, gitSourceIdentity } from '../scripts/release-notes.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';
import { sha256 } from '../scripts/evidence-files.mjs';

const script = new URL('../scripts/build-native-candidate.mjs', import.meta.url);

async function fixture(t, overrides = {}) {
  const mod = await import(script);
  assert.equal(typeof mod.buildNativeCandidate, 'function', 'builder must be importable without CLI side effects');
  const root = mkdtempSync(join(tmpdir(), 'abyss-candidate-'));
  t.after(() => rmSync(root,{recursive:true,force:true}));
  mkdirSync(join(root,'src/lua'),{recursive:true}); mkdirSync(join(root,'data'));
  writeFileSync(join(root,'src/lua/abyss_ui.lua'),'return {}');
  writeFileSync(join(root,'data/input.json'),'{}');
  writeFileSync(join(root,'base.gil'),'ORIGINAL');
  const output=join(root,'output'); mkdirSync(output);
  const names=[],sources=new Map(),calls=[]; let workspace;
  const {scriptContent,existingScripts=[],graphs=[],signals=[],prepareGenerated,...checkOverrides}=overrides;
  const client={async readResource(){return {contents:[]};},async callTool({name,arguments:args}) {
    calls.push({name,args});
    let data={};
    const mapPath=join(workspace,'mock.gil');
    if(name==='scene_set_client_script'){ names.push(args.name);sources.set(args.name,readFileSync(args.sourceFile,'utf8')); writeFileSync(mapPath,'candidate'); data={mapPath}; }
    if(name==='scene_add_graph')data={graphId:7,name:'ABYSS_SETTLEMENT'};
    if(name==='write_graphs')data={written:[7]};
    if(name==='scene_check_client')data={ok:true,errors:0,warnings:0,problems:[],checked:[...names],...checkOverrides};
    if(name==='scene_list_client_scripts')data={scripts:[...sources].map(([name,source])=>({name,file:name+'.lua',source:scriptContent??source})).concat(existingScripts)};
    if(name==='scene_remove_client') {const at=existingScripts.findIndex(script=>script.name===args.script);if(at>=0)existingScripts.splice(at,1);data={removed:{script:args.script}};}
    if(name==='inspect_map')data={graphs};
    if(name==='scene_list_signals')data={signals};
    return {structuredContent:data};
  }};
  // The fake SDK has no native process; filesystem and manifest checks stay real.
  const prepare=dir=>{workspace=dirname(dir);names.length=0;writeFileSync(join(dir,'game-ui.json'),'{"controls":[]}');writeFileSync(join(dir,'game-ui-templates.json'),'[]');prepareGenerated?.(dir);};
  return {root,output,calls,run:extra=>mod.buildNativeCandidate({root,baseMap:join(root,'base.gil'),output,client,prepare,
    generatedModules:{},sourceCommit:'f'.repeat(40),...extra})};
}

test('missing fresh generated module cannot use a stale shared build',async t=>{
  const f=await fixture(t);mkdirSync(join(f.root,'build/lua'),{recursive:true});
  writeFileSync(join(f.root,'build/lua/abyss_data.lua'),'return {}');
  await assert.rejects(f.run({generatedModules:{abyss_data:'builder'}}),/ENOENT/);
});

test('every production entry parameter is registered by both native package routes',async t=>{
  const f=await fixture(t);
  const source=readFileSync('src/lua/abyss_ui.lua','utf8');
  writeFileSync(join(f.root,'src/lua/abyss_ui.lua'),source);
  await f.run();
  const {candidateScriptFiles}=await import('../scripts/native-candidate-scripts.mjs');
  const generated=join(f.root,'generated');mkdirSync(generated);
  for(const name of ['abyss_data','abyss_original_v4_data','abyss_map_layout','abyss_narrative','abyss_presentation','abyss_theme'])
    writeFileSync(join(generated,name+'.lua'),'return {}');
  const packaged=candidateScriptFiles(join(f.root,'src/lua'),generated).find(row=>row.name==='abyss_ui');
  const parameters=[...source.matchAll(/:GetParam\(["']([^"']+)["']\)/g)].map(match=>match[1]);
  assert(parameters.length>0);
  for(const variables of [packaged.variables,f.calls.find(c=>c.name==='scene_set_client_script').args.variables])
    for(const name of parameters)assert.deepEqual(variables.find(row=>row.name===name),
      {name,type:'boolean',value:false},'Missing production entry parameter: '+name);
});

test('reused base removes only owned stale modules and reuses its writable settlement graph',async t=>{
  const f=await fixture(t,{existingScripts:[{name:'abyss_stale',file:'abyss_stale.lua'}],
    graphs:[{id:23,name:'_GSTS_ABYSS_SETTLEMENT',type:20000,writable:true}],signals:['ABYSS_WIN','ABYSS_LOSE']});
  await f.run();
  assert.equal(f.calls.filter(c=>c.name==='scene_remove_client').length,1);
  assert.equal(f.calls.filter(c=>c.name==='scene_add_graph'||c.name==='scene_add_signal').length,0);
  assert.equal(f.calls.find(c=>c.name==='write_graphs').args.graphs[0].graphId,23);
  assert.deepEqual(f.calls.find(c=>c.name==='scene_set_client_script').args.variables,
    [{name:'nativeBgmEnabled',type:'boolean',value:false},
      {name:'experimentalCharacters',type:'boolean',value:false}]);
  assert.equal(f.calls.find(c=>c.name==='scene_add_client_ui').args.replace,true);
});

test('unknown script ownership and ambiguous settlement graphs remain hard failures',async t=>{
  const foreign=await fixture(t,{existingScripts:[{name:'foreign_script',file:'foreign.lua'}]});
  await assert.rejects(foreign.run(),/ownership/);
  assert.equal(foreign.calls.some(c=>c.name==='scene_remove_client'),false);
  const repeated=await fixture(t,{graphs:[{id:2,name:'_GSTS_ABYSS_SETTLEMENT',type:20000,writable:true},
    {id:3,name:'_GSTS_ABYSS_SETTLEMENT',type:20000,writable:true}]});
  await assert.rejects(repeated.run(),/ambiguous/);
});

test('source/generated module collisions are rejected',async t=>{
  const f=await fixture(t);await assert.rejects(f.run({generatedModules:{abyss_ui:'builder'}}),/Duplicate module/);
});

test('extracted UI subviews are embedded, read back and checked with the entry module',async t=>{
  const f=await fixture(t);
  const sources=new Map(['abyss_battle_card_view','abyss_battle_info_content','abyss_battle_info_view',
    'abyss_battle_intent_view','abyss_battle_potion_view','abyss_battle_reward_owner',
    'abyss_battle_status_view','abyss_battle_unit_view','abyss_shop_ui'].map(name=>[
    name,readFileSync(new URL(`../src/lua/${name}.lua`,import.meta.url),'utf8')
  ]));
  for(const [name,source] of sources)writeFileSync(join(f.root,`src/lua/${name}.lua`),source);
  const receipt=await f.run();
  assert.deepEqual(receipt.checkedModules,[...sources.keys(),'abyss_ui'].sort());
  for(const [name,source] of sources) {
    const write=f.calls.find(call=>call.name==='scene_set_client_script'&&call.args.name===name);
    assert.equal(readFileSync(write.args.sourceFile,'utf8'),source);
  }
  assert.equal(f.calls.some(call=>call.name==='scene_list_client_scripts'),true);
});

test('readback with correct module names but stale contents is rejected',async t=>{
  const f=await fixture(t,{scriptContent:'return "old contents"'});await assert.rejects(f.run(),/content|digest|readback/i);
});

test('parent alias outside root is rejected before creating any output directory',async t=>{
  const f=await fixture(t),outside=mkdtempSync(join(tmpdir(),'abyss-external-'));
  t.after(()=>rmSync(outside,{recursive:true,force:true}));
  try{symlinkSync(outside,join(f.root,'escape'),'junction');}catch(error){if(['EPERM','EACCES'].includes(error.code)){t.skip('Directory alias creation requires filesystem privilege');return;}throw error;}
  await assert.rejects(f.run({output:join(f.root,'escape/new')}),/root|outside/i);
  assert.equal(existsSync(join(outside,'new')),false,'Rejected output must not create directories outside root');
});

test('complete fake SDK builds unique receipts without replacing historical input aliases',async t=>{
  const f=await fixture(t); linkSync(join(f.root,'base.gil'),join(f.output,'candidate.json'));
  const a=await f.run(),b=await f.run();
  assert.notEqual(a.buildId,b.buildId); assert.equal(readFileSync(join(f.root,'base.gil'),'utf8'),'ORIGINAL');
  assert.equal(a.statuses.staticCheck,'pass'); assert.equal(a.statuses.playtest,'not_run');
  assert.match(a.candidate.sha256,/^[a-f0-9]{64}$/); assert.match(a.payloadDigest,/^[a-f0-9]{64}$/);
  assert.deepEqual(a.checkedModules,['abyss_ui']); assert(existsSync(a.receiptPath));
});
for(const [label,override] of [['empty',{checked:[]}],['missing',{checked:['other']}],['duplicate',{checked:['abyss_ui','abyss_ui']}],['errors',{ok:true,errors:1}]]) {
  test(`rejects ${label} module-check results without success receipt`,async t=>{
    const f=await fixture(t,override); await assert.rejects(f.run(),/check|module/i);
    assert.equal(existsSync(join(f.output,'candidate.json')),false);
  });
}

async function releaseFixture(t, stale = false, mutate = () => {}) {
  let root;
  const f=await fixture(t,{prepareGenerated:dir=>{
    const notes=loadReleaseNotes({root,releaseCandidate:true});
    writeFileSync(join(dir,'abyss_narrative.lua'),stale ? (stale === 'wrong-version' ? 'return {["codeVersion"]="v0.0.1"}' : 'return {}')
      : `return {["codeVersion"]=${toLua(notes.build.version)}}`);
    mutate(root);
  }});
  root=f.root;mkdirSync(join(root,'data/release'));
  writeFileSync(join(root,'package.json'),'{"version":"0.1.1"}');
  writeFileSync(join(root,'package-lock.json'),'{"version":"0.1.1","packages":{"":{"version":"0.1.1"}}}');
  writeFileSync(join(root,'.release-please-manifest.json'),'{".":"0.1.1"}');
  writeFileSync(join(root,'CHANGELOG.md'),'## 0.1.1 (2026-10-27)\n\n### 新增\n\n* 与候选绑定的版本说明。\n');
  writeFileSync(join(root,'data/release/publications.json'),'{"schemaVersion":1,"releases":[]}');
  writeFileSync(join(root,'.gitignore'),'output/\n');
  for(const args of [['init','-q'],['add','.'],['-c','user.name=Release Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture']]) {
    const git=spawnSync('git',args,{cwd:root,encoding:'utf8'});assert.equal(git.status,0,git.stderr);
  }
  return {...f,run:extra=>f.run({sourceCommit:gitSourceIdentity(root).sourceCommit,
    generatedModules:{abyss_narrative:'scripts/build-ui.mjs'},releaseCandidate:true,...extra})};
}
test('explicit frozen native candidate packages exact menu version and binds source/notes hash without publication',async t=>{
  const f=await releaseFixture(t),receipt=await f.run();
  const notes=loadReleaseNotes({root:f.root,releaseCandidate:true});
  assert.deepEqual(receipt.release,{version:'v0.1.1',workKey:'alpha-test',notesSha256:notesSha256(notes.currentNotice)});
  assert.equal(receipt.sourceDirty,false);assert.equal(receipt.sourceCommit,notes.build.sourceCommit);
  assert(receipt.checkedModules.includes('abyss_narrative'));
  assert.equal(receipt.inputs.find(input=>input.path==='CHANGELOG.md').sha256,
    sha256(readFileSync(join(f.root,'CHANGELOG.md'))), 'candidate still binds the exact official-log source text');
  assert.deepEqual(JSON.parse(readFileSync(join(f.root,'data/release/publications.json'))).releases,[]);
});
test('stale, wrong-version or omitted native narrative cannot claim frozen release provenance',async t=>{
  const stale=await releaseFixture(t,true);await assert.rejects(stale.run(),/Bundled code version differs/);
  const wrong=await releaseFixture(t,'wrong-version');await assert.rejects(wrong.run(),/Bundled code version differs/);
  const omitted=await releaseFixture(t);await assert.rejects(omitted.run({generatedModules:{}}),/must package.*narrative/);
});
test('frozen native candidate rejects dirty source and misleading source SHA',async t=>{
  const f=await releaseFixture(t);
  await assert.rejects(f.run({sourceCommit:'f'.repeat(40)}),/differs from checkout/);
  writeFileSync(join(f.root,'data/input.json'),'{"dirty":true}');
  await assert.rejects(f.run(),/clean source checkout/);
  const concurrent=await releaseFixture(t,false,root=>writeFileSync(join(root,'untracked.txt'),'late change'));
  await assert.rejects(concurrent.run(),/source identity changed during packaging/);
});
