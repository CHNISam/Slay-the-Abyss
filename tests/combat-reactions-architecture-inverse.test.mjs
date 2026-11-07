import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,copyFileSync,mkdirSync,mkdtempSync,rmSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {preCombatReactionArchitecture} from './helpers/architecture-source-format.mjs';
import {preCardOriginSource} from './helpers/card-origin-source-inverse.mjs';
import {preCompendiumSource} from './helpers/compendium-source-inverse.mjs';
import {preGameUiExtractionSource} from './helpers/game-ui-extraction-source-inverse.mjs';
const path='config/architecture.json';
const source=preGameUiExtractionSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n'));
const hash=s=>createHash('sha256').update(s).digest('hex');
const prior='3cc15d6f573fa5a5c637c2d2a4ef9086f444bb761a64ee1e6aef80dad40d0cc5';
test('reaction architecture inverse restores complete prior bytes through LF, CRLF and layout variants',()=>{
 for(const variant of [source,source.replaceAll('\n','\r\n'),JSON.stringify(JSON.parse(source)),JSON.stringify(JSON.parse(source),null,'\t')]){
  assert.equal(hash(preCombatReactionArchitecture(path,variant)),prior);
  assert.equal(hash(preCardOriginSource(path,variant)),'640bb51f60c831ad2162de7907b5b7e6a241dfa6f50b15b8527234eb2da47b64');
  assert.equal(hash(preCompendiumSource(path,variant)),'8c6e10716cb4ba38d49f9164d6349e8eb2a80ca13b6c364f69181a056b7bfdbf');
 }
 assert.equal(preCombatReactionArchitecture('unrelated.json',source),source);
 assert.equal(preCombatReactionArchitecture(path,null),null);
});
test('reaction inverse never hides partial registrations, boundary drift, duplicates or reordered policy',()=>{
 const policy=JSON.parse(source),variants=[];
 const mutate=fn=>{const copy=structuredClone(policy);fn(copy);variants.push(JSON.stringify(copy));};
 mutate(p=>delete p.layers.abyss_combat_reactions);
 mutate(p=>p.layers.abyss_combat_reactions='ui');
 mutate(p=>delete p.dependencyBoundaries);
 mutate(p=>p.dependencyBoundaries=[]);
 mutate(p=>p.dependencyBoundaries.reverse());
 mutate(p=>p.dependencyBoundaries[0].forbiddenTargets=[]);
 mutate(p=>p.dependencyBoundaries[1].reason+=' changed');
 mutate(p=>p.dependencyBoundaries.push(p.dependencyBoundaries[0]));
 mutate(p=>p.deferredImports.reverse());
 mutate(p=>p.layers.abyss_actor='ui');
 const key='"abyss_combat_reactions": "core"';
 variants.push(source.replace(key,key+', '+key),source+'-- unknown\n');
 for(const variant of variants)for(const ending of [variant,variant.replaceAll('\n','\r\n')]){
  assert.notEqual(ending,source);
  assert.equal(preCombatReactionArchitecture(path,ending),ending);
  assert.equal(preCardOriginSource(path,ending),ending);
  assert.equal(preCompendiumSource(path,ending),ending);
 }
});
test('warm reaction projection freshly binds linked config and exposes disk mutation or deletion',async t=>{
 const root=mkdtempSync(join(tmpdir(),'reaction-architecture-inverse-'));
 t.after(()=>rmSync(root,{recursive:true,force:true}));
 mkdirSync(join(root,'tests/helpers'),{recursive:true});mkdirSync(join(root,'config'));
 copyFileSync('tests/helpers/architecture-source-format.mjs',join(root,'tests/helpers/architecture-source-format.mjs'));
 for(const name of ['game-ui-extraction-source-inverse.mjs','game-ui-extraction-source-layer.json','core-lifecycle-source-inverse.mjs','actor-lifecycle-before.lua','combat-lifecycle-before.json','relic-query-source-inverse.mjs','relic-query-baseline-391306af.json.gz','query-living-wall-before.lua','relic-lifecycle-baseline-391306af.json.gz','relic-lifecycle-architecture-source-inverse.json','m7-core-final-source-inverse.mjs','m7-core-final-before.json.gz','power-shop-source-inverse.mjs','power-shop-before-2c85.json.gz'])copyFileSync('tests/helpers/'+name,join(root,'tests/helpers',name));
 const file=join(root,path);writeFileSync(file,source);
 const {preCombatReactionArchitecture:project}=await import(pathToFileURL(join(root,'tests/helpers/architecture-source-format.mjs')));
 assert.equal(hash(project(path,source)),prior);
 writeFileSync(file,source.replace('"abyss_combat_reactions": "core"','"abyss_combat_reactions": "ui"'));
 assert.equal(project(path,source),source);
 writeFileSync(file,source.replaceAll('\n','\r\n'));assert.equal(hash(project(path,source)),prior);
 unlinkSync(file);assert.equal(project(path,source),source);
});
