import {readBeforeMobileQaSource} from './helpers/mobile-qa-source-inverse.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {preIntegratedNodeUiSource,postNodeUi} from './helpers/approved-node-ui-refactor.mjs';
import {nodeUiRefactor} from './helpers/node-ui-refactor-inverse.mjs';
import {approvedUi,preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
import {p0Presentation,materializeHistoricalPresentation} from './helpers/p0-presentation-inverse.mjs';
import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';
const read=p=>readBeforeMobileQaSource(p).replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const root='src/lua/abyss_node_ui.lua',face='src/lua/abyss_node_ui_faces.lua';
const paths=Object.keys(nodeUiRefactor.afterSha256);
const layer=JSON.parse(read('tests/fixtures/approved-node-ui-faces-layer.json'));
test('approved face changes project through the immutable complete Node refactor before the original UI layer',()=>{
 assert.equal(paths.length,11);assert.equal(layer.hunks.length,4);
 assert.equal(layer.beforeSha256,nodeUiRefactor.afterSha256[face]);
 assert.equal(layer.approvedMonolithSha256,approvedUi.files[root].afterSha256);
 assert.equal(hash(read(face)),layer.afterSha256);
 const source=read(root),expected=nodeUiRefactor.beforeSource;
 assert.equal(preIntegratedNodeUiSource(root,source),expected);
 assert.equal(preIntegratedNodeUiSource(root,source.replaceAll('\n','\r\n')),expected);
 assert.equal(preIntegratedNodeUiSource(root,expected),expected);
 assert.equal(preApprovedUiSource(root,source),expected);
});
test('all eleven Node identities and caller overrides reject unrelated or partial drift',()=>{
 const source=read(root);
 for(const path of paths){
  const changed=read(path)+'\n-- unrelated drift\n';
  assert.throws(()=>preIntegratedNodeUiSource(root,path===root?changed:source,{[path]:changed}),/unreviewed integrated/);
 }
 const lines=read(face).split('\n');
 for(const hunk of layer.hunks){
  for(const after of [[],[...hunk.after,...hunk.after],hunk.before]){
   const moved=[...lines];moved.splice(hunk.at,hunk.after.length,...after);
   assert.throws(()=>preIntegratedNodeUiSource(root,source,{[face]:moved.join('\n')}),/unreviewed integrated/);
  }
  const moved=[...lines];moved.splice(hunk.at,hunk.after.length);moved.push(...hunk.after);
  assert.throws(()=>preIntegratedNodeUiSource(root,source,{[face]:moved.join('\n')}),/unreviewed integrated/);
 }
 assert.equal(preIntegratedNodeUiSource(root,source,{[face]:read(face).replaceAll('\n','\r\n')}),nodeUiRefactor.beforeSource);
});
test('temporary historical materialization removes exactly the ten genuinely added Node modules',()=>{
 const directory=mkdtempSync(join(tmpdir(),'approved-node-history-'));
 try{
  for(const path of new Set([...paths,...Object.keys(p0Presentation.files),...Object.keys(approvedUi.files)])){mkdirSync(join(directory,path,'..'),{recursive:true});writeFileSync(join(directory,path),readFileSync(path,'utf8'));}
  for(const path of paths.filter(p=>p!==root))assert(existsSync(join(directory,path)),path);
  materializeHistoricalPresentation(directory);
  for(const path of paths.filter(p=>p!==root))assert.equal(existsSync(join(directory,path)),false,path);
  assert(existsSync(join(directory,root)));
  assert.equal(hash(readFileSync('tests/fixtures/approved-ui-latest-to-53fa.json')),'39f651e8ec7a3037947d1a76123c2d03a521dd4a05168565f80f7222590ec89a');
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('post-Node config and minimal native fixes retain complete-source identities and reject unknown hunks',()=>{
 for(const [path,binding] of Object.entries(postNodeUi.files)){
  const source=read(path),prior=preIntegratedNodeUiSource(path,source);
  assert.equal(hash(prior),binding.beforeSha256,path);
  assert.equal(preIntegratedNodeUiSource(path,source.replaceAll('\n','\r\n')),prior);
  assert.equal(preIntegratedNodeUiSource(path,prior),prior);
  assert.throws(()=>preIntegratedNodeUiSource(path,source+'\n-- drift\n'),/unreviewed integrated/);
  for(const hunk of binding.hunks){
   const lines=source.split('\n');lines.splice(hunk.at,hunk.after.length,...hunk.before);
   const value=lines.join('\n');
   if(hash(value)===binding.beforeSha256)assert.equal(preIntegratedNodeUiSource(path,value),prior);
   else assert.throws(()=>preIntegratedNodeUiSource(path,value),/unreviewed integrated/);
  }
 }
});

test('the two pre-existing frozen glyph-theme identities traverse only their exact historical path',()=>{
 const path='data/presentation/ui_theme.json';
 const fixture=read('tests/fixtures/task77-current-source-layers-20261028.json');
 assert.equal(hash(fixture),'f5d61e2809daadc3a2d559d54e3de2b1846f4ad1001a44a12436a1f0d08bee3a');
 const source=JSON.parse(fixture).historicalGlyphTheme;
 assert.equal(hash(source),'f88fac509e27f23db8e7f65c50236377fd7c230356695987e51f93881f6ec128');
 const metadata=read('docs/reviews/formal-entry-source-inverses-20261028.json');
 assert.equal(hash(metadata),'cb1c42674c3a4ca3e399e63ea61a4c919513a452e80d7fc95881dfa4262c9893');
 const lines=source.split('\n');
 for(const hunk of [...JSON.parse(metadata).files[path].hunks].reverse()){
  const at=hunk.at+10;
  assert.deepEqual(lines.slice(at,at+hunk.after.length),hunk.after);
  lines.splice(at,hunk.after.length,...hunk.before);
 }
 const before=lines.join('\n');
 assert.equal(hash(before),'992e36ac0923209eb0ae09eac564e2685b0768a5cbbe211762e6b62b723478cf');
 for(const witness of [source,before]){
  assert.equal(preIntegratedNodeUiSource(path,witness),witness);
  assert.equal(preIntegratedNodeUiSource(path,witness.replaceAll('\n','\r\n')),witness);
  assert.throws(()=>preIntegratedNodeUiSource(path,witness+' '),/unreviewed integrated/);
  assert.throws(()=>preIntegratedNodeUiSource('scripts/card-face.mjs',witness),/unreviewed integrated/);
  assert.throws(()=>preFormalEntrySource('src/lua/abyss_game_ui.lua',witness),/unreviewed integrated/);
 }
 assert.equal(preFormalEntrySource(path,source),before);
});

test('live materialization refuses a historical root plus drifted or missing extracted module before touching the destination',()=>{
 const previous=process.cwd(),directory=mkdtempSync(join(tmpdir(),'node-live-guard-'));
 const currentRoot=read(root),faceLines=read(face).split('\n');
 for(const hunk of [...layer.hunks].reverse())faceLines.splice(hunk.at,hunk.after.length,...hunk.before);
 const priorFace=faceLines.join('\n');assert.equal(hash(priorFace),layer.beforeSha256);
 try{
  mkdirSync(join(directory,root,'..'),{recursive:true});
  writeFileSync(join(directory,root),nodeUiRefactor.beforeSource);
  const target=join(directory,'destination');mkdirSync(target);writeFileSync(join(target,'keep'),'untouched');
  for(const missing of [false,true]){
   if(missing)rmSync(join(directory,face),{force:true});else writeFileSync(join(directory,face),read(face)+'\n-- drift\n');
   process.chdir(directory);
   assert.throws(()=>materializeHistoricalPresentation(target),/current-only Node materialization/);
   assert.deepEqual(readdirSync(target),['keep']);assert.equal(readFileSync(join(target,'keep'),'utf8'),'untouched');
   process.chdir(previous);
  }
  writeFileSync(join(directory,root),currentRoot);writeFileSync(join(directory,face),priorFace);
  process.chdir(directory);
  assert.throws(()=>materializeHistoricalPresentation(target),/current-only Node materialization.*approved live face/);
  assert.deepEqual(readdirSync(target),['keep']);
 }finally{process.chdir(previous);rmSync(directory,{recursive:true,force:true});}
});
