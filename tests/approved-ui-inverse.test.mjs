import {readBeforeMobileQaSource} from './helpers/mobile-qa-source-inverse.mjs';
import {nodeUiRefactor} from './helpers/node-ui-refactor-inverse.mjs';
import {preIntegratedNodeUiSource} from './helpers/approved-node-ui-refactor.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,existsSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {approvedUi,preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
import {p0Presentation,preAcceptedPresentation,materializeHistoricalPresentation} from './helpers/p0-presentation-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const read=p=>readBeforeMobileQaSource(p).replaceAll('\r\n','\n');
const potionPath='tests/lua/battle_ui_potion_target_failures.lua';
const potionPart=JSON.parse(read('tests/fixtures/ui-regression-partitions.json')).partitions.find(part=>part.entry===potionPath);
function originalPotionFailures(source){
 assert(source.startsWith(potionPart.prefix));assert(source.endsWith(potionPart.footer));
 source=source.slice(potionPart.prefix.length,-potionPart.footer.length);
 assert.equal(source.split(potionPart.after).length,2);
 return source.replace(potionPart.after,potionPart.before);
}
function originalApprovedNodeWitness(binding){
 const lines=nodeUiRefactor.beforeSource.split('\n');
 assert.equal(hash(lines.join('\n')),binding.beforeSha256);
 for(const hunk of binding.hunks){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.before.length),hunk.before);
  lines.splice(hunk.at,hunk.before.length,...hunk.after);
 }
 const source=lines.join('\n');assert.equal(hash(source),binding.afterSha256);
 return source;
}
test('approved UI layer binds complete current sources and restores exactly the unchanged PR302 base',()=>{
 assert.equal(approvedUi.baseHead,'53fa164a9914dd8a7a5849ff741925dd3131f5e4');
 assert.equal(Object.keys(p0Presentation.files).length,26,'all original PR302 historical bindings remain');
 assert.equal(hash(readFileSync('tests/fixtures/p0-accepted-presentation-inverses.json.gz')),'6f74bc575b24e5c830119e0309b0311017cbeba5ad5cc6d1fdcc44f69a27e164');
 for(const [path,binding] of Object.entries(approvedUi.files)){
  const live=read(path),registered=path===potionPath?originalPotionFailures(live):live;
  const source=path==='src/lua/abyss_node_ui.lua'?originalApprovedNodeWitness(binding):preIntegratedNodeUiSource(path,registered),previous=preApprovedUiSource(path,source);
  assert.equal(preApprovedUiSource(path,live),previous);
  assert.equal(hash(source),binding.afterSha256,path);
  assert.equal(previous===null?null:hash(previous),binding.beforeSha256,path);
  assert.equal(preApprovedUiSource(path,source.replaceAll('\n','\r\n')),previous);
  assert.equal(preApprovedUiSource(path,previous),previous,'exact prior witness remains usable');
  assert.throws(()=>preApprovedUiSource(path,source+'\n-- drift\n'),/unreviewed integrated/);
  const lines=source.split('\n'),hunk=binding.hunks.find(h=>h.after.length);assert(hunk,path);
  for(const replacement of [[],[...hunk.after,...hunk.after]]){
   const mutant=[...lines];mutant.splice(hunk.at,hunk.after.length,...replacement);
   const value=mutant.join('\n');
   if(value===previous)assert.equal(preApprovedUiSource(path,value),previous,'an exact whole prior witness is not partial drift');
   else assert.throws(()=>preApprovedUiSource(path,value),/unreviewed integrated/);
  }
  const moved=[...lines];moved.splice(hunk.at,hunk.after.length);moved.push(...hunk.after);
  if(moved.join('\n')!==source)assert.throws(()=>preApprovedUiSource(path,moved.join('\n')),/unreviewed integrated/);
 }
});
test('bounded potion registrar composes only its complete exact source before the unchanged frozen UI guard',()=>{
 const live=read(potionPath),original=originalPotionFailures(live),binding=approvedUi.files[potionPath];
 assert.equal(hash(live),'49dcd4b8dfeb5c8fcac998e57c1a8fdc01f8f087959fa723470fcc36136cbf75');
 assert.equal(hash(original),'47565faaad06cbf34edf208a30d922ab4975b19a5025dc751c379ff6ed2d83a9');
 assert.equal(hash(original),binding.afterSha256,'the immutable UI witness, not the partition manifest, authorizes the recovered source');
 const previous=preApprovedUiSource(potionPath,original);
 assert.equal(hash(previous),binding.beforeSha256);
 assert.equal(preApprovedUiSource(potionPath,live),previous);
 assert.equal(preApprovedUiSource(potionPath,live.replaceAll('\n','\r\n')),previous);
 assert.equal(preApprovedUiSource(potionPath,previous),previous,'the older exact witness remains accepted');
 const mutants=[
  live.replace(potionPart.prefix,''),
  live.replace('sliceLast or 3','sliceLast or 4'),
  live.replace(potionPart.after,potionPart.before),
  live.replace(potionPart.after,potionPart.after+potionPart.after),
  live.replace('originalTest(name,fn);',''),
  live.replace(potionPart.footer,''),
  live+potionPart.footer,
  live.replace('all 7 original cases must register','all 8 original cases must register'),
  live.replace('untouched(h,a,z);','untouched(h,a,z); '),
  live+'\n-- unrelated drift\n',
 ];
 for(const mutant of mutants){
  assert.notEqual(mutant,live);
  assert.throws(()=>preApprovedUiSource(potionPath,mutant),/unreviewed integrated/);
 }
 assert.throws(()=>preApprovedUiSource('tests/lua/battle_ui_potion_targeting.lua',live),/unreviewed integrated/,'a different frozen path cannot borrow this inverse');
 assert.equal(preApprovedUiSource('unrelated.lua',live),live,'unrelated paths remain untouched');
 assert.throws(()=>preApprovedUiSource(potionPath,null),/unreviewed integrated/,'a missing bound source remains rejected');
});
test('historical materialization consumes both all 26 original sources and every new UI consumer',()=>{
 for(const path of ['src/lua/abyss_card_display.lua','src/lua/abyss_card_skin.lua','src/lua/abyss_shop_ui.lua'])assert(approvedUi.files[path],path);
 const directory=mkdtempSync(join(tmpdir(),'approved-ui-inverse-'));
 try{
  const paths=[...new Set([...Object.keys(p0Presentation.files),...Object.keys(approvedUi.files)])];
  for(const path of paths){
   mkdirSync(join(directory,path,'..'),{recursive:true});
   writeFileSync(join(directory,path),read(path));
  }
  assert(existsSync(join(directory,'scripts/card-lightning.mjs')),'the added dependency must really exist before historical removal');
  materializeHistoricalPresentation(directory);
  for(const path of paths){
   const previous=preApprovedUiSource(path,read(path));
   const expected=preAcceptedPresentation(path,previous);
   if(expected===null)assert.equal(existsSync(join(directory,path)),false,path);
   else assert.equal(readFileSync(join(directory,path),'utf8'),expected,path);
  }
 }finally{rmSync(directory,{recursive:true,force:true});}
});
