import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {assetControls,installAssetControls,materialSample} from './specimen.mjs';
import {assertNativeUiCapacity} from '../../../scripts/build-ui.mjs';
test('single native background stays below real HUD and does not mutate its controls',()=>{
 const hud={name:'battlePanel',kind:'container',size:[1280,720],children:[{name:'hp',kind:'text',size:[100,40],text:{content:'80/80',fontSize:20}}]};
 const layout={controls:[{name:'stage',kind:'container',children:[{name:'officialBattleBackdrop',kind:'container',children:[]},hud]}]};
 const before=JSON.stringify(hud);installAssetControls(layout);assertNativeUiCapacity(layout);
 assert.equal(layout.controls[0].children[1].name,'labMaterialBackdrop');assert.equal(layout.controls[0].children[2],hud);assert.equal(JSON.stringify(hud),before);
 const sample=assetControls();assert.equal(sample.visible,false);assert.equal(sample.children.length,2);assert.equal(sample.children[0].image,107134);
 assert.throws(()=>installAssetControls(layout),/fresh/);assert.equal(materialSample.totalControls,3);
});
test('recorded source-level savings and readback keep device limitations explicit',()=>{
 const r=JSON.parse(readFileSync(new URL('./specimen-receipt.json',import.meta.url)));
 assert.equal(r.sourceComparison.baselineDrawnImages,4500);assert.equal(r.sourceComparison.candidateDrawnImages,2);
 assert.equal(r.sourceComparison.drawnImagesAvoidable,4498);assert.equal(r.sourceComparison.sameVisualContent,false);
 assert.equal(r.sourceComparison.actualCandidateCacheFreed,false);assert.equal(r.statuses.templateReadback,'pass');
 for(const key of ['officialImport','mobile','officialLoad','visualInClient'])assert.equal(r.statuses[key],'not_run');
});
