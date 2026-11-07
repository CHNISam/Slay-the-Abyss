import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,copyFileSync,mkdirSync,mkdtempSync,rmSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {preLivingWallCopyArchitecture,preCombatReactionArchitecture} from './helpers/architecture-source-format.mjs';
import {preCardOriginSource} from './helpers/card-origin-source-inverse.mjs';
import {preCompendiumSource} from './helpers/compendium-source-inverse.mjs';
import {preGameUiExtractionSource} from './helpers/game-ui-extraction-source-inverse.mjs';

const path='config/architecture.json';
const source=preGameUiExtractionSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n'));
const proofBytes=readFileSync('tests/fixtures/living-wall-architecture-20261105.json','utf8').replaceAll('\r\n','\n');
const proof=JSON.parse(proofBytes);
const hash=s=>createHash('sha256').update(s).digest('hex');
const projections=[preLivingWallCopyArchitecture,preCombatReactionArchitecture,preCardOriginSource,preCompendiumSource];

test('only the complete LivingWall increment restores authenticated prior architecture and all older witnesses',()=>{
 assert.equal(hash(proofBytes),'fab9854fc185d6b185cdd9d3db564378ca3559e1a0386ed1b11396d5bd031e44');
 assert.equal(proof.schemaVersion,1);
 assert.equal(proof.baseRevision,'b4ac63145689b9dd632db100eee49087f6182b39');
 assert.equal(proof.afterRevision,'d1cd30104efaff03af287b0902263b420641697e');
 assert.equal(proof.path,path);
 assert.equal(hash(source),proof.afterSha256);
 assert.equal(hash(JSON.stringify(JSON.parse(source),null,2)+'\n'),proof.afterCanonicalSha256);
 assert.deepEqual(JSON.parse(source).dependencyBoundaries[0],proof.boundary);
 const before=preLivingWallCopyArchitecture(path,source);
 assert.equal(hash(before),proof.beforeSha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(before)+'\0').update(before).digest('hex'),proof.beforeGitBlob);
 const expected=[proof.beforeSha256,'3cc15d6f573fa5a5c637c2d2a4ef9086f444bb761a64ee1e6aef80dad40d0cc5',
  '640bb51f60c831ad2162de7907b5b7e6a241dfa6f50b15b8527234eb2da47b64',
  '8c6e10716cb4ba38d49f9164d6349e8eb2a80ca13b6c364f69181a056b7bfdbf'];
 for(const variant of [source,source.replaceAll('\n','\r\n'),JSON.stringify(JSON.parse(source)),JSON.stringify(JSON.parse(source),null,'\t'),source+'\n\t '])
  for(const [i,project]of projections.entries())assert.equal(hash(project(path,variant)),expected[i]);
 assert.equal(preLivingWallCopyArchitecture('unknown.json',source),source);
 assert.equal(preLivingWallCopyArchitecture(path,null),null);
});

test('missing, duplicate, partial or foreign LivingWall policy never enters any historical inverse',()=>{
 const variants=[];
 const mutate=fn=>{const policy=JSON.parse(source);fn(policy);variants.push(JSON.stringify(policy));};
 mutate(p=>p.dependencyBoundaries.shift());
 mutate(p=>p.dependencyBoundaries.push(structuredClone(p.dependencyBoundaries[0])));
 mutate(p=>p.dependencyBoundaries[0].id+='-changed');
 mutate(p=>p.dependencyBoundaries[0].from=[]);
 mutate(p=>p.dependencyBoundaries[0].from=['abyss_actor']);
 mutate(p=>p.dependencyBoundaries[0].forbiddenTargets=[]);
 mutate(p=>p.dependencyBoundaries[0].forbiddenTargets=['abyss_card_actions']);
 mutate(p=>p.dependencyBoundaries[0].reason+=' changed');
 mutate(p=>delete p.dependencyBoundaries[0].reason);
 mutate(p=>p.dependencyBoundaries[0].unreviewed=true);
 mutate(p=>p.unreviewed={enabled:true});
 mutate(p=>p.layers.abyss_living_wall='ui');
 mutate(p=>p.layers.abyss_actor='ui');
 mutate(p=>p.dependencyBoundaries.reverse());
 mutate(p=>p.deferredImports.reverse());
 variants.push(source.replace('"id": "living-wall-copy-isolation"','"id": "living-wall-copy-isolation", "id": "living-wall-copy-isolation"'),source+'-- foreign\n');
 for(const variant of variants)for(const ending of [variant,variant.replaceAll('\n','\r\n')])
  for(const project of projections)assert.equal(project(path,ending),ending);
});

test('warm LivingWall projections freshly bind linked policy bytes, including guard removal and deletion',async t=>{
 const root=mkdtempSync(join(tmpdir(),'living-wall-architecture-'));
 t.after(()=>rmSync(root,{recursive:true,force:true}));
 mkdirSync(join(root,'tests/helpers'),{recursive:true});mkdirSync(join(root,'config'));
 copyFileSync('tests/helpers/architecture-source-format.mjs',join(root,'tests/helpers/architecture-source-format.mjs'));
 for(const name of ['game-ui-extraction-source-inverse.mjs','game-ui-extraction-source-layer.json','core-lifecycle-source-inverse.mjs','actor-lifecycle-before.lua','combat-lifecycle-before.json','relic-query-source-inverse.mjs','relic-query-baseline-391306af.json.gz','query-living-wall-before.lua','relic-lifecycle-baseline-391306af.json.gz','relic-lifecycle-architecture-source-inverse.json','m7-core-final-source-inverse.mjs','m7-core-final-before.json.gz','power-shop-source-inverse.mjs','power-shop-before-2c85.json.gz'])copyFileSync('tests/helpers/'+name,join(root,'tests/helpers',name));
 const file=join(root,path);writeFileSync(file,source);
 const {preLivingWallCopyArchitecture:outer,preCombatReactionArchitecture:reaction}=await import(pathToFileURL(join(root,'tests/helpers/architecture-source-format.mjs')));
 const prior=outer(path,source);
 assert.equal(hash(prior),proof.beforeSha256);
 for(const changed of [source.replace('Foundation','Changed Foundation'),
  source.replace('"abyss_actor": "core"','"abyss_actor": "ui"'),prior]){
  writeFileSync(file,changed);
  assert.equal(outer(path,source),source);
  assert.equal(reaction(path,source),source);
 }
 writeFileSync(file,source.replaceAll('\n','\r\n'));
 assert.equal(hash(outer(path,source)),proof.beforeSha256);
 assert.equal(hash(reaction(path,source)),'3cc15d6f573fa5a5c637c2d2a4ef9086f444bb761a64ee1e6aef80dad40d0cc5');
 unlinkSync(file);
 assert.equal(outer(path,source),source);
 assert.equal(reaction(path,source),source);
});

test('both outer entries authenticate foreign tokens before IO and reread reviewed linked inputs after warmup',t=>{
 const root=mkdtempSync(join(tmpdir(),'living-wall-token-reads-'));
 t.after(()=>rmSync(root,{recursive:true,force:true}));
 const reads={};
 for(const mode of ['foreign','reviewed']){
  const output=join(root,mode+'.json');
  const script=`
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createTracing} from 'node:trace_events';
import {preLivingWallCopyArchitecture as outer,preCombatReactionArchitecture as reaction} from ${JSON.stringify(new URL('./helpers/architecture-source-format.mjs',import.meta.url).href)};
const path='config/architecture.json',source=readFileSync(path,'utf8');
const policy=JSON.parse(source);policy.unreviewed_token_probe=true;
const input=${JSON.stringify(mode)}==='foreign'?JSON.stringify(policy):source;
const trace=createTracing({categories:['node.fs.sync']});
trace.enable();
for(let repeat=0;repeat<2;repeat++)for(const project of [outer,reaction]){
 const result=project(path,input);
 if(${JSON.stringify(mode)}==='foreign')assert.equal(result,input);
 else assert.notEqual(result,input);
}
trace.disable();`;
  const result=spawnSync(process.execPath,['--trace-event-file-pattern='+output,'--input-type=module','-e',script],
   {encoding:'utf8',timeout:30000,maxBuffer:1024*1024,windowsHide:true});
  assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
  reads[mode]=JSON.parse(readFileSync(output,'utf8')).traceEvents
   .filter(event=>event.ph==='B'&&event.name.startsWith('fs.sync.read')).length;
 }
 assert.equal(reads.foreign,0,'neither outer entry reads a linked owner for foreign tokens');
 assert.ok(reads.reviewed>=4,'each reviewed call, including warm repeats, reads the actual linked policy');
});
