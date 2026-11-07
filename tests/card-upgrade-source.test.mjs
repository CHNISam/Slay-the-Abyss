import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync,symlinkSync,renameSync,copyFileSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {cardUpgradeBefore,cardUpgradeSourceProof as proof,preCardUpgradeSource as project,cardUpgradeReader,prepareCardUpgradeRetirement as retire} from './helpers/card-upgrade-source-inverse.mjs';
import {m7FinalBefore,preM7FinalSource,m7FinalReader} from './helpers/m7-core-final-source-inverse.mjs';
import {preRelicQuerySource,relicQueryReader} from './helpers/relic-query-source-inverse.mjs';
import {prepareRound3CatalogModuleRetirement as retireHistoricalCatalog} from './helpers/round3-catalog-source-inverse.mjs';
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const owners=Object.keys(proof.files),originals=owners.filter(p=>Object.hasOwn(proof.files[p],'beforeSource'));
const leaf='src/lua/abyss_card_upgrade.lua',config='config/architecture.json';
const isolated=t=>{const directory=mkdtempSync(join(tmpdir(),'card-upgrade-source-'));t.after(()=>rmSync(directory,{recursive:true,force:true}));return directory;};
function write(root,path,source){const target=join(root,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source);return target;}
function link(t,target,path,type){
 try{symlinkSync(target,path,type);return true;}
 catch(error){if(!['EPERM','EACCES','ENOTSUP'].includes(error.code))throw error;t.skip('symlink unavailable: '+error.code);return false;}
}

test('the immutable archive authenticates all 333 complete sources without inventing leaf history',()=>{
 assert.equal(Object.keys(cardUpgradeBefore.files).length,333);
 assert.equal(cardUpgradeBefore.revision,'2ad07111e3d5b5cb52b4229860b3b780941e29a9');
 for(const [name,row]of Object.entries(cardUpgradeBefore.files)){
  assert.equal(row.path,'src/lua/'+name+'.lua');assert.equal(hash(row.source),row.sha256);
  assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(row.source)}\0`).update(row.source).digest('hex'),row.gitBlob);
  assert(Object.isFrozen(row));
 }
 assert.equal(cardUpgradeBefore.files.abyss_card_upgrade,undefined);
 assert.deepEqual(Object.keys(proof.files[leaf]),['afterSha256']);
 assert(Object.isFrozen(cardUpgradeBefore)&&Object.isFrozen(cardUpgradeBefore.files));
 assert(Object.isFrozen(proof)&&Object.isFrozen(proof.files));
 assert.equal(owners.length,5);assert.equal(originals.length,4);
 assert.equal(proof.baseRevision,'d8a57cae2a867200ca8e588abc0d368e6cdb3799');
 assert.equal(proof.corpusRevision,cardUpgradeBefore.revision);
 assert.notEqual(proof.baseRevision,proof.corpusRevision);
 assert.equal(proof.baseLuaCorpus.sourceCount,333);
 assert.equal(proof.baseLuaCorpus.gitBlobManifestSha256,'45ab772c9bb36e979a3ce0b61a00ebaf4878f04d85b9c7f4d3ecd3265e9de643');
 assert(Object.isFrozen(proof.baseLuaCorpus));
});

test('every exact entry freshly reads each of the five raw owners once through nested readers',()=>{
 for(const path of originals)for(const wrapper of [r=>r,cardUpgradeReader,r=>cardUpgradeReader(cardUpgradeReader(r))]){
  const counts=new Map(),reader=wrapper(p=>{counts.set(p,(counts.get(p)??0)+1);return read(p);});
  for(let repeat=1;repeat<=2;repeat++){
   assert.equal(project(path,read(path),{readSource:reader}),proof.files[path].beforeSource);
   assert.deepEqual([...counts.entries()],owners.map(p=>[p,repeat]));
  }
 }
 for(const path of originals){
  let reads=0;const wrapped=cardUpgradeReader(p=>{reads++;return read(p);});
  assert.equal(cardUpgradeReader(wrapped),wrapped);
  assert.equal(wrapped(path),proof.files[path].beforeSource);assert.equal(reads,owners.length+1);
 }
});

test('warm source authorization rejects changed, missing and non-string raw owners rather than caching permission',()=>{
 for(const path of originals)for(const bad of owners)for(const kind of ['changed','old','missing','null','buffer','throw']){
  let broken=false;
  const raw=p=>{
   if(p===bad&&broken){
    if(kind==='throw')throw Error('reader sentinel');
    return kind==='changed'?read(p)+'\n':kind==='old'?proof.files[p].beforeSource:kind==='missing'?undefined:kind==='buffer'?Buffer.from(read(p)):null;
   }
   return read(p);
  };
  const wrapped=cardUpgradeReader(raw);
  assert.equal(project(path,read(path),{readSource:wrapped}),proof.files[path].beforeSource);broken=true;
  assert.throws(()=>project(path,read(path),{readSource:wrapped}),/Card Upgrade linked owner/);
  broken=false;assert.equal(project(path,read(path),{readSource:wrapped}),proof.files[path].beforeSource);
 }
 for(const reader of [null,{},'invalid'])assert.throws(()=>project(originals[0],read(originals[0]),{readSource:reader}),/linked reader/);
});

test('linked owner failures stop in exact owner order and preserve the first error',()=>{
 for(const path of originals)for(const bad of owners)for(const kind of ['identity','missing']){
  const seen=[],reader=p=>{
   seen.push(p);
   if(p===bad){if(kind==='missing')throw Error('first failure');return read(p)+'\n';}
   return read(p);
  };
  assert.throws(()=>project(path,read(path),{readSource:cardUpgradeReader(reader)}),{
   message:'Card Upgrade linked owner '+kind+': '+bad+(kind==='missing'?': first failure':''),
  });
  assert.deepEqual(seen,owners.slice(0,owners.indexOf(bad)+1));
 }
});

test('old, foreign, partial and witness-only inputs grant no linked I/O, even with an invalid reader',()=>{
 let reads=0;const readSource=()=>{reads++;throw Error('unexpected read');};
 const cases=[];
 for(const path of originals)for(const value of [proof.files[path].beforeSource,read(path)+'\n-- foreign',null,undefined,false,17,{},Buffer.from(read(path)),'',read(path).slice(1)])cases.push([path,value]);
 cases.push([leaf,read(leaf)],['foreign',read(originals[0])]);
 for(const [path,value]of cases)for(const reader of [readSource,null])assert.equal(project(path,value,{readSource:reader}),value);
 assert.equal(reads,0);
});

test('CRLF and input-only JSON layout equivalence never relax linked raw bytes or exact tokens',()=>{
 for(const path of originals)assert.equal(project(path,read(path).replaceAll('\n','\r\n'),{readSource:cardUpgradeReader(p=>read(p).replaceAll('\n','\r\n'))}),proof.files[path].beforeSource);
 const source=read(config),compact=JSON.stringify(JSON.parse(source));
 for(const formatted of [compact,JSON.stringify(JSON.parse(source),null,'\t'),source+'\n\t ']){
  assert.equal(project(config,formatted),proof.files[config].beforeSource);
  for(const wrapper of [r=>r,cardUpgradeReader,r=>cardUpgradeReader(cardUpgradeReader(r))])
   assert.throws(()=>project(config,formatted,{readSource:wrapper(p=>p===config?formatted:read(p))}),/linked owner identity/);
 }
 const foreign=JSON.parse(source);foreign.unreviewed=true;
 const reordered=Object.fromEntries(Object.entries(JSON.parse(source)).reverse());
 const variants=[source.replace('"abyss_card_upgrade": "core"','"abyss_card_upgrade": "core", "abyss_card_upgrade": "core"'),source.replace('"layers"','"laye\\u0072s"'),source.replace('"abyss_card_upgrade": "core"','"abyss_card_upgrade": "co\\u0072e"'),source.replace('"abyss_card_upgrade"','"abyss_act3_enemy_definition\\u0073"'),JSON.stringify(foreign),JSON.stringify(reordered),'\ufeff'+source,source+'-- invalid'];
 let reads=0;for(const value of variants){assert.notEqual(value,source);assert.equal(project(config,value,{readSource:()=>{reads++;throw Error('unexpected');}}),value);}assert.equal(reads,0);
});

test('the final M7 outer seam and existing relic chain preserve their exact older epochs',()=>{
 for(const path of originals){
  const expected=path==='src/lua/abyss_combat.lua'?m7FinalBefore.files.abyss_combat.source:proof.files[path].beforeSource;
  assert.equal(preM7FinalSource(path,read(path)),expected);
  assert.equal(m7FinalReader(read)(path),expected);
  assert.equal(preM7FinalSource(path,read(path),{readSource:m7FinalReader(m7FinalReader(read))}),expected);
 }
 for(const path of ['src/lua/abyss_combat.lua',config]){
  const projected=preRelicQuerySource(path,read(path));assert.notEqual(projected,read(path));assert.notEqual(projected,proof.files[path].beforeSource);
  assert.equal(relicQueryReader(read)(path),projected);
  assert.throws(()=>preRelicQuerySource(path,read(path),{readSource:p=>p===leaf?read(p)+'\n':read(p)}),/linked owner/);
 }
});

test('a detached source-only import observes actual file drift and deletion after warmup',async t=>{
 const root=isolated(t);
 for(const path of owners)write(root,path,read(path));
 for(const name of ['card-upgrade-source-inverse.mjs','card-upgrade-source-proof.json','colorless-catalog-before-2ad07111.json.gz'])copyFileSync('tests/helpers/'+name,write(root,'tests/helpers/'+name,''));
 const {preCardUpgradeSource:detached}=await import(pathToFileURL(join(root,'tests/helpers/card-upgrade-source-inverse.mjs')));
 const raw=p=>readFileSync(join(root,p),'utf8');
 for(const owner of owners){
  const path=originals[0],source=read(path);
  assert.equal(detached(path,source,{readSource:raw}),proof.files[path].beforeSource);
  write(root,owner,read(owner)+'\n');assert.throws(()=>detached(path,source,{readSource:raw}),/linked owner identity/);
  rmSync(join(root,owner));assert.throws(()=>detached(path,source,{readSource:raw}),/linked owner missing/);
  write(root,owner,read(owner));
 }
});

test('Card Upgrade retirement verifies bytes twice and rejects live tree or file aliases',t=>{
 assert.throws(()=>retire(process.cwd()),/separate historical destination/);
 const root=isolated(t),target=write(root,leaf,read(leaf));
 const cleanup=retire(root);assert(existsSync(target));
 write(root,leaf,read(leaf)+'\n');assert.throws(cleanup,/unreviewed/);assert(existsSync(target));
 write(root,leaf,read(leaf));retire(root)();assert(!existsSync(target));assert(existsSync(leaf));
 retire(root)();
 if(!link(t,join(process.cwd(),leaf),target,'file'))return;
 assert.throws(()=>retire(root),/aliases live source/);assert(existsSync(leaf));
});

test('Card Upgrade retirement rejects retargeting between preparation and deletion',t=>{
 const root=isolated(t),source=join(root,'source'),destination=join(root,'destination');
 write(source,leaf,read(leaf));write(destination,leaf,read(leaf));
 const cleanup=retire(destination,{sourceRoot:source});
 renameSync(join(destination,'src/lua'),join(destination,'src/saved-lua'));
 if(!link(t,join(source,'src/lua'),join(destination,'src/lua'),process.platform==='win32'?'junction':'dir'))return;
 assert.throws(cleanup,/target changed/);assert(existsSync(join(source,leaf)));assert(existsSync(join(destination,'src/saved-lua/abyss_card_upgrade.lua')));
});

test('the existing historical retirement entry handles Card Upgrade leaf present and absent without weakening old guards',t=>{
 const catalog='src/lua/abyss_combat_catalog.lua';
 for(const present of [false,true])for(const oldPresent of [false,true]){
  const root=isolated(t);if(present)write(root,leaf,read(leaf));if(oldPresent)write(root,catalog,read(catalog));
  const cleanup=retireHistoricalCatalog(root);assert.equal(existsSync(join(root,leaf)),present);assert.equal(existsSync(join(root,catalog)),oldPresent);
  cleanup();assert(!existsSync(join(root,leaf)));assert(!existsSync(join(root,catalog)));assert(existsSync(leaf)&&existsSync(catalog));
 }
 const root=isolated(t);write(root,leaf,read(leaf));write(root,catalog,read(catalog));
 const cleanup=retireHistoricalCatalog(root);write(root,leaf,read(leaf)+'\n');
 assert.throws(cleanup,/unreviewed Card Upgrade/);assert(existsSync(join(root,leaf))&&existsSync(join(root,catalog)));
 write(root,catalog,read(catalog)+'\n');
 assert.throws(cleanup,/unreviewed catalog module destination/);assert.throws(()=>retireHistoricalCatalog(root),/unreviewed catalog module destination/);
 assert(existsSync(join(root,leaf))&&existsSync(join(root,catalog)));
});

test('default linked reads use only the isolated five-owner tree, including warm missing witnesses',t=>{
 const root=isolated(t),cwd=process.cwd(),current=Object.fromEntries(owners.map(path=>[path,read(path)]));
 for(const path of owners)write(root,path,current[path]);
 try{
  process.chdir(root);
  for(const path of originals)for(const bad of owners){
   assert.equal(project(path,current[path]),proof.files[path].beforeSource);
   write(root,bad,current[bad]+'\n');assert.throws(()=>project(path,current[path]),/linked owner identity/);
   rmSync(join(root,bad));assert.throws(()=>project(path,current[path]),/linked owner missing/);
   write(root,bad,current[bad]);assert.equal(project(path,current[path]),proof.files[path].beforeSource);
  }
 }finally{process.chdir(cwd);}
});

test('complete bytes from another owner and duplicated complete sources authorize no I/O',()=>{
 let reads=0;const readSource=()=>{reads++;throw Error('unexpected read');};
 for(const path of originals)for(const other of owners.filter(p=>p!==path)){
  const source=read(other);assert.equal(project(path,source,{readSource}),source);
 }
 for(const path of originals){const source=read(path)+read(path);assert.equal(project(path,source,{readSource}),source);}
 assert.equal(reads,0);
});

test('Card Upgrade retirement rejects directory aliases, nested escapes, live Lua descendants and source ancestors',t=>{
 const root=isolated(t),source=join(root,'source');write(source,leaf,read(leaf));
 const alias=join(root,'source-alias');
 if(!link(t,source,alias,process.platform==='win32'?'junction':'dir'))return;
 assert.throws(()=>retire(alias,{sourceRoot:source}),/separate historical destination/);
 const destination=join(root,'destination');mkdirSync(join(destination,'src'),{recursive:true});
 if(!link(t,join(source,'src/lua'),join(destination,'src/lua'),process.platform==='win32'?'junction':'dir'))return;
 assert.throws(()=>retire(destination,{sourceRoot:source}),/aliases live source/);
 const within=join(source,'src/lua/history');write(within,leaf,read(leaf));
 assert.throws(()=>retire(within,{sourceRoot:source}),/aliases live source/);
 write(root,leaf,read(leaf));assert.throws(()=>retire(root,{sourceRoot:source}),/separate historical destination/);
 assert(existsSync(join(source,leaf))&&existsSync(join(within,leaf))&&existsSync(join(root,leaf)));
});

test('Card Upgrade retirement rejects an entire destination changed after preparation',t=>{
 const root=isolated(t),source=join(root,'source'),destination=join(root,'destination');
 write(source,leaf,read(leaf));write(destination,leaf,read(leaf));
 const cleanup=retire(destination,{sourceRoot:source});renameSync(destination,join(root,'saved'));
 if(!link(t,source,destination,process.platform==='win32'?'junction':'dir'))return;
 assert.throws(cleanup,/retirement destination changed/);
 assert(existsSync(join(source,leaf))&&existsSync(join(root,'saved',leaf)));
});
