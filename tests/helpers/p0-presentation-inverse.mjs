import {materializeBeforeDelivery} from './delivery-source-composition.mjs';
import {preBattleLifeSource} from './battle-life-source-inverse.mjs';
import {materializeBeforeRelicCompletionSources} from './relic-completion-inverse.mjs';
import {preEventProductionSource} from './event-production-source-inverse.mjs';
import {preHeroVisualSource} from './hero-visual-source-inverse.mjs';
import {preRelicViewUiSource} from './relic-view-ui-inverse.mjs';
import {eventProductionInverse,materializeBeforeEventProduction} from './event-production-source-inverse.mjs';
import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
import {pr323AcceptedSourceInverse,requirePr323Source} from './pr323-accepted-source-inverse.mjs';
export {preCardDragClickSource} from './task76-drag-click-inverse.mjs';
import {preIntegratedNodeUiSource,nodeUiAddedPaths,nodeUiCurrentRootSha256,approvedNodeFace} from './approved-node-ui-refactor.mjs';
import {approvedUi,preApprovedUiSource} from './approved-ui-inverse.mjs';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,rmSync,mkdirSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('tests/fixtures/p0-accepted-presentation-inverses.json.gz');
assert.equal(hash(bytes),'6f74bc575b24e5c830119e0309b0311017cbeba5ad5cc6d1fdcc44f69a27e164');
export const p0Presentation=JSON.parse(gunzipSync(bytes));
export function preP0OuterSource(path,source){
 source=preBattleLifeSource(path,source);
 return p0Presentation.files[path]?preEventProductionSource(path,preRelicViewUiSource(path,preHeroVisualSource(path,source))):source;
}
export function preAcceptedPresentation(path,source){
 source=preP0OuterSource(path,source);
  source=preAcceptedPr323Source(path,source);
  if(source===null)return source;
  source=preIntegratedNodeUiSource(path,source).replaceAll('\r\n','\n');
  return invertAcceptedPresentation(path,source);
}
// Pure final inverse: callers must already have applied the full current-source
// validation pipeline. This function neither grants nor caches live permission.
function invertAcceptedPresentation(path,source){
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
  const diskRoot=preAcceptedPr323Source(root,readFileSync(root,'utf8')).replaceAll('\r\n','\n');
  assert.equal(hash(diskRoot),nodeUiCurrentRootSha256,'current-only Node materialization must validate the live refactored root before any writes');
  const diskFace=preAcceptedPr323Source(approvedNodeFace.path,readFileSync(approvedNodeFace.path,'utf8')).replaceAll('\r\n','\n');
  assert.equal(hash(diskFace),approvedNodeFace.afterSha256,'current-only Node materialization must validate the approved live face before any writes');
  materializeBeforeDelivery(directory);
  materializeBeforeRelicCompletionSources(directory);
  const nodeSource=preIntegratedNodeUiSource(root,diskRoot,{[approvedNodeFace.path]:diskFace});
  // Validate the whole combined inventory before any temporary historical writes.
  const acceptedSources=Object.keys(pr323AcceptedSourceInverse.files).map(path=>{
    const source=readFileSync(path,'utf8');requirePr323Source(path,source);
    return [path,preAcceptedPr323Source(path,source)];
  });
  materializeBeforeEventProduction(directory,{historicalPaths:[...new Set([...Object.keys(pr323AcceptedSourceInverse.files),...Object.keys(p0Presentation.files),...Object.keys(approvedUi.files),...nodeUiAddedPaths])].filter(path=>eventProductionInverse.files[path]?.beforeSource!=null)});
  for(const [path,source]of acceptedSources){
    if(source===null)rmSync(join(directory,path),{force:true});
    else {mkdirSync(dirname(join(directory,path)),{recursive:true});writeFileSync(join(directory,path),source);}
  }
  for(const path of new Set([...Object.keys(p0Presentation.files),...Object.keys(approvedUi.files)])){
    const source=preApprovedUiSource(path,preP0OuterSource(path,path===root?nodeSource:preAcceptedPr323Source(path,readFileSync(path,'utf8'))));
    if(source===null)rmSync(join(directory,path),{force:true});
    else writeFileSync(join(directory,path),p0Presentation.files[path]
      ? invertAcceptedPresentation(path,source) : preAcceptedPresentation(path,source));
  }
  for(const path of nodeUiAddedPaths)rmSync(join(directory,path),{force:true});
}
