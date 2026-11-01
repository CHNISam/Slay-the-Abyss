import {prepareMonsterArt} from '../scripts/monster-art.mjs';
import {mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {portraitInventory,portraitRuntimeInputs as portraitSourceInputs} from '../scripts/official-portraits.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {artFeatureReceipt} from '../scripts/art-features.mjs';
import {auditUiBuildArgs} from '../scripts/audit-native-candidate.mjs';
const portraitReceipt=flags=>({...portraitInventory(flags),inputs:portraitSourceInputs(flags).map(path=>({path,sha256:'d'.repeat(64),bytes:1}))});
const off={cards:false,menuBackground:false,selectionAvatar:false,battlePortrait:false,monsters:false};
const monsterRegistry=prepareMonsterArt(JSON.parse(readFileSync('data/presentation/native-monster-art.json','utf8')));
const monsterRecords=[...monsterRegistry.sourceInputs.slice(0,2),...Object.values(monsterRegistry.additionalAssets).flatMap(asset=>asset.sourceInputs)];
const monsterPaths=monsterRecords.map(row=>row.path);
const monsterReceipt=()=>({enabled:true,assetCount:1+Object.keys(monsterRegistry.additionalAssets).length,bindingCount:Object.keys(monsterRegistry.bindings).length,
 capacity:600,allocation:'per-drawable-actor-instance',inputs:monsterRecords.map(({path,sha256})=>({path,sha256,bytes:readFileSync(path).length}))});

test('audit reconstructs all thirty-two exact flag snapshots, not alpha-test defaults',()=>{
 for(let mask=0;mask<32;mask++){
  const flags={cards:!!(mask&1),menuBackground:!!(mask&2),selectionAvatar:!!(mask&4),battlePortrait:!!(mask&8),monsters:!!(mask&16)};
  const receipt={artFeatures:artFeatureReceipt(flags),...(flags.monsters?{nativeMonsterArt:monsterReceipt()}:{}),...(flags.cards?{readyCardArt:{enabled:true}}:{}),...(flags.menuBackground?{officialBackground:{}}:{}),...(flags.selectionAvatar||flags.battlePortrait||flags.cards||flags.menuBackground?{officialPortraits:portraitReceipt(flags)}:{})};
  assert.equal(receipt.artFeatures.schemaVersion,2);
  assert.deepEqual(auditUiBuildArgs(receipt),['scripts/build-ui.mjs',`--art-cards=${flags.cards}`,`--art-menu-background=${flags.menuBackground}`,`--art-selection-avatar=${flags.selectionAvatar}`,`--art-battle-portrait=${flags.battlePortrait}`,`--art-monsters=${flags.monsters}`]);
 }
});
test('audit rejects tampered, absent, malformed and category-inconsistent feature provenance',()=>{
 for(const artFeatures of [undefined,{flags:off},artFeatureReceipt({...off,cards:true}),{...artFeatureReceipt(off),flags:{...off,battlePortrait:true}},{...artFeatureReceipt(off),schemaVersion:1},{...artFeatureReceipt(off),schemaVersion:3},{...artFeatureReceipt(off),flags:{...off,bogus:true}}])
  assert.throws(()=>auditUiBuildArgs({artFeatures}),/art feature|artwork|portrait|card/i);
 assert.throws(()=>auditUiBuildArgs({artFeatures:artFeatureReceipt(off),readyCardArt:{enabled:true}}),/card|artwork/i);
 assert.throws(()=>auditUiBuildArgs({artFeatures:artFeatureReceipt(off),officialBackground:{}}),/background|artwork/i);
});
test('audit preserves explicit static-card hosts while rejecting their disabled-card conflict',()=>{
 const nativeCardArt={registry:{path:'art/frozen.json'},hosts:['battlePanel/card1']};
 const args=auditUiBuildArgs({artFeatures:artFeatureReceipt({...off,cards:true}),officialPortraits:portraitReceipt({...off,cards:true}),nativeCardArt});
 assert(args.includes('--native-card-art-registry=art/frozen.json'));assert(args.includes('--native-card-art-host=battlePanel/card1'));
 assert.throws(()=>auditUiBuildArgs({artFeatures:artFeatureReceipt(off),nativeCardArt}),/card|artwork/i);
});

test('audit selects enabled sources without consulting current optional drawings and resolves portable static provenance',async()=>{
 const audit=await import('../scripts/audit-native-candidate.mjs');
 assert.equal(typeof audit.auditAssetInputs,'function');
 assert.deepEqual(audit.auditAssetInputs({artFeatures:artFeatureReceipt({})}).paths,[]);
 assert.deepEqual(audit.auditAssetInputs({artFeatures:artFeatureReceipt({cards:true}),officialPortraits:portraitReceipt({...off,cards:true}),readyCardArt:{enabled:true}}).paths,['art/cards/traveler-geo','art/lowpoly-select/select-lowpoly.json']);
 const registry={path:'/other/build/checkout/art/frozen.json',sha256:'a'.repeat(64),bytes:100},source={path:'/other/build/checkout/art/cleave/native-art.lua',sha256:'b'.repeat(64),bytes:200};
 const receipt={artFeatures:artFeatureReceipt({cards:true}),officialPortraits:portraitReceipt({...off,cards:true}),nativeCardArt:{registry,hosts:['battlePanel/card1'],inputs:[source,registry]},inputs:[{...source,path:'art/cleave/native-art.lua'},{...registry,path:'art/frozen.json'}]};
 assert.deepEqual(audit.auditAssetInputs(receipt).paths,['art/lowpoly-select/select-lowpoly.json','art/cleave/native-art.lua','art/frozen.json']);
 assert.equal(audit.auditAssetInputs(receipt).registryPath,'art/frozen.json');
 assert.throws(()=>audit.auditAssetInputs({...receipt,inputs:[]}),/portable|provenance/i);
});


test('portrait receipt cannot claim the other category or a different control budget',()=>{
 const flags={...off,selectionAvatar:true},officialPortraits=portraitReceipt(flags),receipt={artFeatures:artFeatureReceipt(flags),officialPortraits};
 assert.doesNotThrow(()=>auditUiBuildArgs(receipt));
 for(const changed of [portraitReceipt({...off,battlePortrait:true}),{...officialPortraits,peakDynamicControls:1},{...officialPortraits,inputs:[]}])
  assert.throws(()=>auditUiBuildArgs({...receipt,officialPortraits:changed}),/portrait/i);
});


test('static audit replays archived source from another checkout and rejects changed archived bytes',async t=>{
 const {auditAssetInputs,prepareAuditStaticRegistry}=await import('../scripts/audit-native-candidate.mjs');
 const root=mkdtempSync(join(tmpdir(),'abyss-audit-rebase-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 const hash=bytes=>createHash('sha256').update(bytes).digest('hex'),original='/nonexistent/previous-checkout/';
 const paths=['art/cleave/native-art.lua','art/cleave/native-art.json'],contents=['reviewed source bytes','{"reviewed":true}'];
 const records=paths.map((path,i)=>({path:original+path,sha256:hash(contents[i]),bytes:Buffer.byteLength(contents[i])}));
 const registry={schemaVersion:2,sourceInputs:records.map((row,i)=>({path:i?row.path:'/old-symlink/../source-alias.lua',sha256:row.sha256,cardId:'cleave',kind:i?'json':'lua'})),assets:{cleave:{frozen:true}}};
 const registryBytes=JSON.stringify(registry),registryPath='art/frozen.json',registryRecord={path:original+registryPath,sha256:hash(registryBytes),bytes:Buffer.byteLength(registryBytes)};
 const inputs=[...records,registryRecord];
 const receipt={artFeatures:artFeatureReceipt({cards:true}),officialPortraits:portraitReceipt({...off,cards:true}),nativeCardArt:{registry:registryRecord,hosts:['battlePanel/card1'],inputs},inputs:inputs.map(row=>({...row,path:row.path.slice(original.length)}))};
 for(const [path,bytes]of [...paths.map((path,i)=>[path,contents[i]]),[registryPath,registryBytes]]){mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),bytes);}
 const selected=auditAssetInputs(receipt);prepareAuditStaticRegistry(root,receipt,selected);
 const rebased=JSON.parse(readFileSync(join(root,registryPath)));
 assert.deepEqual(rebased.sourceInputs.map(row=>row.path),paths);assert.deepEqual(rebased.assets,registry.assets);
 writeFileSync(join(root,registryPath),registryBytes);writeFileSync(join(root,paths[0]),'tampered');
 assert.throws(()=>prepareAuditStaticRegistry(root,receipt,selected),/Pinned static artwork differs/);
});

test('actual audit orchestration rejects tampered feature receipts before any native tool startup',async t=>{
 const {auditNativeCandidate}=await import('../scripts/audit-native-candidate.mjs');
 const root=mkdtempSync(join(tmpdir(),'abyss-audit-config-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 const candidate=join(root,'candidate.gil'),receipt=join(root,'candidate.json');writeFileSync(candidate,'offline candidate fixture');
 writeFileSync(receipt,JSON.stringify({artFeatures:{...artFeatureReceipt({}),flags:{...off,cards:true}}}));
 const report=await auditNativeCandidate({source:'a'.repeat(40),candidate,receipt,output:join(root,'audit')});
 assert.equal(report.ok,false);assert.match(report.issues[0].detail,/Art feature receipt config digest mismatch/);
 assert.equal(readFileSync(candidate,'utf8'),'offline candidate fixture');
});

test('receipt paths cannot become git archive options or pathspec magic',async()=>{
 const {auditAssetInputs}=await import('../scripts/audit-native-candidate.mjs');
 for(const path of ['--output=/tmp/not-authorized.tar',':(top)**','../outside.json']){
  const registry={path:'/former/checkout/'+path,sha256:'a'.repeat(64),bytes:10};
  const receipt={artFeatures:artFeatureReceipt({cards:true}),officialPortraits:portraitReceipt({...off,cards:true}),nativeCardArt:{registry,hosts:['battlePanel/card1'],inputs:[registry]},inputs:[{...registry,path}]};
  assert.throws(()=>auditAssetInputs(receipt),/portable|provenance/i);
 }
});


test('monster receipt binds the independent bounded inventory and every exact source path',async()=>{
 const {auditAssetInputs}=await import('../scripts/audit-native-candidate.mjs');
 const flags={...off,monsters:true},nativeMonsterArt=monsterReceipt();
 const receipt={artFeatures:artFeatureReceipt(flags),nativeMonsterArt};
 assert.doesNotThrow(()=>auditUiBuildArgs(receipt));
 assert.deepEqual(auditAssetInputs(receipt).paths,monsterPaths);
 const malformed=[undefined,{...nativeMonsterArt,enabled:false},{...nativeMonsterArt,enemyId:'cultist'},
  {...nativeMonsterArt,capacity:599},{...nativeMonsterArt,staticControls:610},
  {...nativeMonsterArt,assetCount:nativeMonsterArt.assetCount+1},{...nativeMonsterArt,bindingCount:nativeMonsterArt.bindingCount-1},
  {...nativeMonsterArt,allocation:'shared-pool'},
  {...nativeMonsterArt,inputs:nativeMonsterArt.inputs.map((row,index)=>index?{...row,sha256:'a'.repeat(64)}:row)},{...nativeMonsterArt,inputs:[]},
  {...nativeMonsterArt,inputs:nativeMonsterArt.inputs.slice(0,1)},
  {...nativeMonsterArt,inputs:[nativeMonsterArt.inputs[0],nativeMonsterArt.inputs[0]]},
  {...nativeMonsterArt,inputs:nativeMonsterArt.inputs.map((row,index)=>index?{...row,path:'../unreviewed.json'}:row)},
  {...nativeMonsterArt,inputs:nativeMonsterArt.inputs.map((row,index)=>index?{...row,sha256:'bad'}:row)},
  {...nativeMonsterArt,inputs:nativeMonsterArt.inputs.map((row,index)=>index?{...row,bytes:0}:row)}];
 for(const changed of malformed){
  assert.throws(()=>auditUiBuildArgs({...receipt,nativeMonsterArt:changed}),/monster|artwork|source/i);
  assert.throws(()=>auditAssetInputs({...receipt,nativeMonsterArt:changed}),/monster|artwork|source/i);
 }
 assert.throws(()=>auditUiBuildArgs({artFeatures:artFeatureReceipt(off),nativeMonsterArt}),/monster|artwork/i);
});

test('historical four-key receipts cannot authorize a fifth-category candidate implicitly',()=>{
 const flags={cards:false,menuBackground:false,selectionAvatar:false,battlePortrait:false};
 for(const schemaVersion of [1,2]){
  const config={schemaVersion,flags};
  const artFeatures={...config,configSha256:createHash('sha256').update(JSON.stringify(config)).digest('hex')};
  assert.throws(()=>auditUiBuildArgs({artFeatures}),/art feature/i,'old four-key snapshot must not acquire current permission');
 }
});
