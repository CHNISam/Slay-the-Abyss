import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
import {preRosterConfigSource} from './competition-roster-config-composition.mjs';
import {preRosterSource} from './competition-roster-source-inverse.mjs';
import {preCardDragClickSource} from './task76-drag-click-inverse.mjs';
import {preNodesBattleMaxHpConfig} from './nodes-battle-max-hp-config-inverse.mjs';
import {preCompositeBattleMaxHpConfig} from './battle-max-hp-config-inverse.mjs';
import {preBattleRefactorLayer} from './battle-refactor-projection.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {nodeUiRefactor,preNodeUiRefactorSource} from './node-ui-refactor-inverse.mjs';
import {preMaxHpSource} from './max-hp-accepted-source-inverse.mjs';
import {preCoreArchitectureSource} from './core-architecture-inverse.mjs';
const hash=value=>createHash('sha256').update(value).digest('hex');
const normalized=value=>value.replaceAll('\r\n','\n');
const bytes=readFileSync(new URL('../fixtures/approved-node-ui-faces-layer.json',import.meta.url));
assert.equal(hash(bytes),'d1e253724b880a9b1779588eb222153675044806ae83a3dba1d63b1fb0b9331b','complete reviewed Node face layer');
export const approvedNodeFace=JSON.parse(bytes);
const outerBytes=readFileSync(new URL('../fixtures/approved-ui-post-node-layer.json',import.meta.url));
assert.equal(hash(outerBytes),'7d12b5b51d93795162ed4fa9869f5585db30d77fe99650de86ef3938caa737ee','complete reviewed post-Node source layer');
export const postNodeUi=JSON.parse(outerBytes);
function prePostNodeSource(path,source){
 const binding=postNodeUi.files[path];
 if(!binding)return source;
 source=preCoreArchitectureSource(path,normalized(source));
 if([binding.beforeSha256,...binding.intermediateSha256].includes(hash(source)))return source;
 assert.equal(hash(source),binding.afterSha256,'unreviewed integrated presentation source drift; unreviewed integrated retirement source drift; post-Node source: '+path);
 const lines=source.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact post-Node hunk and position');
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.beforeSha256,'complete prior UI source recovered: '+path);
 return previous;
}

export const nodeUiCurrentRootSha256=nodeUiRefactor.afterSha256[approvedNodeFace.nodeRoot];
export const nodeUiAddedPaths=Object.keys(nodeUiRefactor.afterSha256).filter(path=>path!==approvedNodeFace.nodeRoot);
assert.equal(approvedNodeFace.beforeSha256,nodeUiRefactor.afterSha256[approvedNodeFace.path]);
assert.equal(nodeUiAddedPaths.length,10);
function beforeApprovedFace(source){
 source=normalized(source);
 if(hash(source)===approvedNodeFace.beforeSha256)return source;
 assert.equal(hash(source),approvedNodeFace.afterSha256,'unreviewed integrated presentation source drift; unreviewed integrated retirement source drift; unreviewed Node UI refactor source drift: face');
 const lines=source.split('\n');
 for(const hunk of [...approvedNodeFace.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact Node face hunk and position');
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),approvedNodeFace.beforeSha256,'complete PR310 face recovered');
 return previous;
}
// The old 58-source and PR310 archives remain immutable. Only the three known
// face edits are inverted, then the original PR310 guard checks every module.
export function preIntegratedNodeUiSource(path,source,overrides={}){
 source=preAcceptedPr323Source(path,source);
 source=preRosterConfigSource(path,source);
 if(source!==null)source=preRosterSource(path,source);
 source=preCardDragClickSource(path,source);
 source=preNodesBattleMaxHpConfig(path,source);
 source=preCompositeBattleMaxHpConfig(path,source);
 if(source!==null)source=preMaxHpSource(path,source);
 source=preCoreArchitectureSource(path,source);
 source=preBattleRefactorLayer(path,source);
 source=prePostNodeSource(path,source);
 if(path!==approvedNodeFace.nodeRoot)return source;
 assert.equal(typeof source,'string','unreviewed integrated Node root must exist');
 source=normalized(source);
 const projected={...overrides};
 for(const [file,raw] of Object.entries(overrides)){
  const value=preAcceptedPr323Source(file,raw);
  if(file===approvedNodeFace.path)projected[file]=beforeApprovedFace(value);
  else if(Object.hasOwn(nodeUiRefactor.afterSha256,file))
   assert.equal(hash(normalized(value)),nodeUiRefactor.afterSha256[file],'unreviewed integrated presentation source drift; unreviewed integrated retirement source drift; unreviewed Node UI refactor source drift: override: '+file);
 }
 if([nodeUiRefactor.beforeSha256,approvedNodeFace.approvedMonolithSha256].includes(hash(source)))return source;
 if(!Object.hasOwn(projected,approvedNodeFace.path))
  projected[approvedNodeFace.path]=beforeApprovedFace(preAcceptedPr323Source(approvedNodeFace.path,readFileSync(approvedNodeFace.path,'utf8')));
 return preNodeUiRefactorSource(path,source,projected);
}
