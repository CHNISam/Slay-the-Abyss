import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {reusableUi} from '../scripts/native-candidate-ui-cache.mjs';
import {fileRecord} from '../scripts/evidence-files.mjs';
function fixture(t){
 const root=mkdtempSync(join(tmpdir(),'abyss-ui-reuse-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 const generated=join(root,'generated');mkdirSync(generated);
 for(const name of ['game-ui.json','game-ui-templates.json'])writeFileSync(join(generated,name),'{}');
 const map=join(root,'candidate.gil');writeFileSync(map,'frozen base');const base=fileRecord(map);
 const receipt={candidate:base,statuses:{staticCheck:'pass'},productionManifest:{layout:fileRecord(join(generated,'game-ui.json')),templates:fileRecord(join(generated,'game-ui-templates.json'))},
 readyCardArt:{imageTemplateIndex:11,containerTemplateIndex:12},officialPortraits:{imageTemplateIndex:11,containerTemplateIndex:12},officialBackground:{templateIndex:13}};
 return {root,base,generated,receipt,save:()=>writeFileSync(join(root,'candidate.json'),JSON.stringify(receipt))};
}
test('only hash-bound verified unchanged UI can skip encoding',t=>{
 const f=fixture(t);f.save();const cached=reusableUi(f.base,f.generated);assert(cached);
 assert.equal(cached.templateResults.AbyssReadyCardImage.templateIndex,11);
 writeFileSync(join(f.generated,'game-ui.json'),'changed');assert.equal(reusableUi(f.base,f.generated),null);
});
for(const mutation of ['base','templates','status','binding'])test('UI reuse rejects mismatched '+mutation,t=>{
 const f=fixture(t);
 if(mutation==='base')f.receipt.candidate={sha256:'0'.repeat(64)};
 if(mutation==='templates')f.receipt.productionManifest.templates={sha256:'0'.repeat(64)};
 if(mutation==='status')f.receipt.statuses.staticCheck='not_run';
 if(mutation==='binding')f.receipt.officialPortraits.containerTemplateIndex=99;
 f.save();assert.equal(reusableUi(f.base,f.generated),null);
});
