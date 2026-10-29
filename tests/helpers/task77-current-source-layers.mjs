import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
import {preIntegratedNodeUiSource} from './approved-node-ui-refactor.mjs';
import {approvedUi,preApprovedUiSource} from './approved-ui-inverse.mjs';
import assert from 'node:assert/strict';
import {p0Presentation,preAcceptedPresentation} from './p0-presentation-inverse.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
export const currentSourceLayers=JSON.parse(readFileSync('tests/fixtures/task77-current-source-layers-20261028.json','utf8'));
const historicalCompetition=JSON.parse(readFileSync('tests/fixtures/competition-two-act-host-projection.json','utf8'));
const hash=value=>createHash('sha256').update(value).digest('hex');
function inverse(source,binding){
 if(!binding || hash(source)!==binding.afterSha256)return source;
 for(const edit of binding.edits){
  assert.equal(source.split(edit.after).length,2,'one exact current-source integration hunk');
  source=source.replace(edit.after,edit.before);
 }
 assert.equal(hash(source),binding.beforeSha256,'complete original source recovered');
 return source;
}
// Test-only exact complete-identity layers. No runtime values or old goldens change.
export function preCurrentSource(path,source){
 source=preAcceptedPr323Source(path,source);
 if(source===null)return null;
 source=preIntegratedNodeUiSource(path,source.replaceAll('\r\n','\n'));
 if(approvedUi.files[path]?.afterSha256===hash(source))source=preApprovedUiSource(path,source);
 // Older layers also accept their own complete intermediate witnesses. Apply
 // the newest inverse only to its exact after identity, then let each older
 // contract validate or reject its own input instead of consuming its witness.
 if(p0Presentation.files[path]?.afterSha256===hash(source))source=preAcceptedPresentation(path,source);
 if(path===historicalCompetition.path)source=inverse(source,historicalCompetition);
 if(path==='src/lua/abyss_ui.lua' && hash(source)==='6a073dda56608f8d4e8f6b9c922a43041f42ded9923c4c3281a3dd8f98deb864')
  source=source.replace('campaignProfile = "competition-two-act", ','');
 source=inverse(source,currentSourceLayers.competition[path]);
 return inverse(source,currentSourceLayers.acceptedUi[path]);
}
