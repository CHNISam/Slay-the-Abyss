import {materializeBeforePreservedUi} from './pr323-preserved-ui-inverse.mjs';
export {preCardDragClickSource} from './task76-drag-click-inverse.mjs';
import {preIntegratedNodeUiSource,nodeUiAddedPaths,nodeUiCurrentRootSha256,approvedNodeFace} from './approved-node-ui-refactor.mjs';
import {approvedUi,preApprovedUiSource} from './approved-ui-inverse.mjs';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('tests/fixtures/p0-accepted-presentation-inverses.json.gz');
assert.equal(hash(bytes),'6f74bc575b24e5c830119e0309b0311017cbeba5ad5cc6d1fdcc44f69a27e164');
export const p0Presentation=JSON.parse(gunzipSync(bytes));
export function preAcceptedPresentation(path,source){
  if(source===null)return source;
  source=preIntegratedNodeUiSource(path,source).replaceAll('\r\n','\n');
  const binding=p0Presentation.files[path];
  if(!binding || hash(source)===binding.beforeSha256)return source;
  assert.equal(hash(source),binding.afterSha256,'unreviewed integrated presentation source drift; unreviewed integrated retirement source drift: '+path);
  for(const edit of binding.edits){
    assert.equal(source.split(edit.after).length,2,'one exact reviewed presentation inverse hunk: '+path);
    source=source.replace(edit.after,edit.before);
  }
  assert.equal(hash(source),binding.beforeSha256,'complete original presentation source recovered: '+path);
  return source;
}
export function materializeHistoricalPresentation(directory){
  // Validate all eleven original current files before any temporary writes/deletes.
  const root='src/lua/abyss_node_ui.lua';
  const diskRoot=readFileSync(root,'utf8').replaceAll('\r\n','\n');
  assert.equal(hash(diskRoot),nodeUiCurrentRootSha256,'current-only Node materialization must validate the live refactored root before any writes');
  const diskFace=readFileSync(approvedNodeFace.path,'utf8').replaceAll('\r\n','\n');
  assert.equal(hash(diskFace),approvedNodeFace.afterSha256,'current-only Node materialization must validate the approved live face before any writes');
  const nodeSource=preIntegratedNodeUiSource(root,diskRoot,{[approvedNodeFace.path]:diskFace});
  materializeBeforePreservedUi(directory);
  for(const path of new Set([...Object.keys(p0Presentation.files),...Object.keys(approvedUi.files)])){
    const source=preApprovedUiSource(path,path===root?nodeSource:readFileSync(path,'utf8'));
    if(source===null)rmSync(join(directory,path),{force:true});
    else writeFileSync(join(directory,path),preAcceptedPresentation(path,source));
  }
  for(const path of nodeUiAddedPaths)rmSync(join(directory,path),{force:true});
}
