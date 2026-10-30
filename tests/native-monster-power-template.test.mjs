import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {enemyPowerTemplate,enemyUnitTemplate,battleLayout} from '../scripts/ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {bindMonsterActorTemplates,writeMonsterActorBinding,monsterPowerTemplateName,monsterActorBindingModule} from '../scripts/monster-art.mjs';
import {compareNativeCandidate} from '../scripts/native-candidate-audit.mjs';
import {readyArtRuntimeInventory} from '../scripts/art/ready-card-runtime.mjs';
const all=n=>[n,...(n.children??n.controls??[]).flatMap(all)];
test('enemy powers use empty unmasked origin and independent seven-control template; hero is byte-identical',()=>{
 assert.equal(readyArtRuntimeInventory().maxLivePools,10);
 const layer=enemyUnitTemplate().children.find(n=>n.name==='statusRow');
 assert.deepEqual(layer.children,[]);assert.deepEqual(layer.position,[0,0]);assert(!layer.mask);
 const power=enemyPowerTemplate();assert.equal(power.name,monsterPowerTemplateName);assert.equal(all(power).length,7);
 assert.deepEqual(power.children.map(n=>n.name),['edge','body','icon','badge','count','hit']);
 assert.equal(power.visible,false);assert(power.children.every(n=>n.visible===false));assertNativeUiCapacity(power);
 const hero=all(battleLayout()).find(n=>n.name==='hero');
 assert.equal(createHash('sha256').update(JSON.stringify(hero)).digest('hex'),'ee457437376d90ded5fe29ce2018ed9266eda755a59779022c9571b8439a3d97');
 // Physical page limit remains 60, never a logical power visibility limit.
 assertNativeUiCapacity({children:Array.from({length:60},()=>enemyPowerTemplate())});
 assert.throws(()=>assertNativeUiCapacity({children:Array.from({length:61},()=>enemyPowerTemplate())}),/60/);
});
test('power binding requires actual distinct positive index and offline remains disabled',t=>{
 const dir=mkdtempSync(join(tmpdir(),'power-binding-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 writeMonsterActorBinding(dir);assert.match(readFileSync(join(dir,monsterActorBindingModule+'.lua'),'utf8'),/powerTemplateIndex=0,enabled=false/);
 for(const value of [undefined,null,0,-1,1.5,'123',Infinity,Number.MAX_SAFE_INTEGER+1,50,51])assert.throws(()=>bindMonsterActorTemplates(dir,{actor:{templateIndex:50},group:{templateIndex:51},power:{templateIndex:value}}));
 bindMonsterActorTemplates(dir,{actor:{templateIndex:50},group:{templateIndex:51},power:{templateIndex:52}});
 assert.match(readFileSync(join(dir,monsterActorBindingModule+'.lua'),'utf8'),/powerTemplateIndex=52,enabled=true/);
});
test('power native readback compares candidate index and every chip child',()=>{
 const {actual,expected}=JSON.parse(readFileSync('tests/fixtures/native-candidate-audit/readback-slice.json'));
 const template=enemyPowerTemplate();expected.runtimeTemplates=[{template,templateIndex:1025}];actual.runtimeTemplates=[{template:structuredClone(template),templateIndex:1025}];
 const issues=()=>compareNativeCandidate({actual,expected,sourceSha:'a'.repeat(40),candidateBefore:'b',candidateAfter:'b'}).issues.filter(i=>i.code.startsWith('RUNTIME_TEMPLATE'));
 assert.deepEqual(issues(),[]);actual.runtimeTemplates[0].templateIndex++;assert(issues().some(i=>i.code==='RUNTIME_TEMPLATE_BINDING'));
 actual.runtimeTemplates[0].templateIndex=1025;actual.runtimeTemplates[0].template.children.find(n=>n.name==='icon').image=100003;assert(issues().some(i=>i.code==='RUNTIME_TEMPLATE_MISMATCH'));
});
