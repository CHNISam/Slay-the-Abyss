import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {prepareMonsterArt,attachMonsterArt,monsterActorTemplate} from '../scripts/monster-art.mjs';
import {nativeArtPool} from '../scripts/card-art-samples.mjs';
import {battleLayout} from '../scripts/ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const walk=n=>[n,...(n.children??n.controls??[]).flatMap(walk)];
const registry=JSON.parse(readFileSync('data/presentation/native-monster-art.json','utf8'));
delete registry.candidateAssets; // Retained full-source catalog still validates every asset below.
const production=prepareMonsterArt(registry);
test('per-instance template preserves scene geometry and accepts every explicit enemy binding',()=>{
 const tree=battleLayout(),before=structuredClone(tree);attachMonsterArt(tree,production);assertNativeUiCapacity(tree);
 assert.deepEqual(tree,before,'template attachment cannot move the scene');
 assert.equal(walk(tree).filter(n=>n.name==='actorLayer').length,1);
 assert(!walk(tree).some(n=>/^enemy\d+$/.test(n.name)),'scene must not impose a five-monster visibility cap');
 const actor=monsterActorTemplate(production);assertNativeUiCapacity(actor);
 // Two source intent-particle layers surround the icon and precede damage text.
 assert.equal(walk(actor).length,647);assert.equal(actor.visible,false);
 const names=actor.children.map(child=>child.name);
 assert(names.indexOf('intentVfxBehind')>=0&&names.indexOf('intentVfxBehind')<names.indexOf('intentIcon'));
 assert(names.indexOf('intentVfxAfter')>names.indexOf('intentIcon')&&names.indexOf('intentVfxAfter')<names.indexOf('intent'));
 assert.equal(actor.children[0].name,'monsterArt');assert.equal(actor.children[0].visible,false);
 assert.equal(Object.keys(production.assets).length,18);assert.equal(Object.keys(production.bindings).length,19);
 assert.equal(production.surfaceAllocation,'per-drawable-actor-instance');
});

for(const [id,metadata]of Object.entries(production.assets))test('actual source export matches every runtime primitive for '+id,()=>{
 const folder=mkdtempSync(join(tmpdir(),'abyss-monster-catalog-'));
 try {
  const source=readFileSync(id==='acid_slime_m'?'art/monsters/acid_slime_m/native-art-r02/native-art.lua':metadata.sourceInputs[0].path,'utf8');
  const path=join(folder,'source.lua');
  writeFileSync(path,`ABYSS_EXPECTED_GALLERY_COUNT=0\nABYSS_EXPORTED_ART=${toLua(source)}\nABYSS_NATIVE_POOL=${toLua(nativeArtPool(production.poolCapacity))}\nABYSS_METADATA=${toLua(metadata)}\ndofile('tests/lua/support/native_card_art_source_equivalence.lua')\n`);
  const result=runLua(path);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,new RegExp('shapes='+metadata.slots.length));
 }finally{rmSync(folder,{recursive:true,force:true});}
});
