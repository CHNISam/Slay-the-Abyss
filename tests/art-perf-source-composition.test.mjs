import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preRound3CatalogSource} from './helpers/round3-catalog-source-inverse.mjs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {artPerfSourceComposition as proof,projectArtPerfSource as project} from './helpers/art-perf-source-composition.mjs';
import {readyArtSourceLayer} from './helpers/ready-art-source-inverse.mjs';
import {round2UiSourceLayer,round2UiAddedPaths,preRound2UiSource} from './helpers/round2-ui-source-inverse.mjs';
import {preBattleLifeOuterSource,prepareBattleLifeModuleRetirement} from './helpers/battle-life-source-inverse.mjs';
const read=path=>preRound3CatalogSource(path,readFileSync(path,'utf8').replaceAll('\r\n','\n'));
const hash=source=>source===null?null:createHash('sha256').update(source).digest('hex');

test('two-way art/performance composition retains both original complete source identities',()=>{
  assert.deepEqual(proof.sourceHeads,{art:'06e66cd2b8ccc02f82cf47f39f0a699c6a4d7e56',perf:'158ec342d09c0d5219cd5f0827900651658e9ee6'});
  for(const [path,binding]of Object.entries(proof.files)){
    const current=read(path);
    assert.equal(hash(current),binding.currentSha256,path);
    for(const target of ['art','perf']){
      const previous=project(path,current,target);
      assert.equal(hash(previous),binding.targets[target].sha256,path+' '+target);
      assert.equal(project(path,current.replaceAll('\n','\r\n'),target),previous);
      assert.equal(project(path,previous,target),previous);
      for(const mutant of [current+'\n-- future\n',current.slice(1),current+current])
        assert.equal(project(path,mutant,target),mutant,'unknown source stays exposed: '+path);
      for(const hunk of binding.targets[target].hunks){
        const lines=current.split('\n');
        lines.splice(hunk.at,hunk.current.length,...hunk.target);
        const partial=lines.join('\n');
        if(hash(partial)!==binding.targets[target].sha256)
          assert.equal(project(path,partial,target),partial,'partial composition stays exposed: '+path);
      }
    }
    assert.equal(hash(project(path,current,'perf')),round2UiSourceLayer.files[path].afterSha256,'original perf witness is immutable');
    if(readyArtSourceLayer.files[path])assert.equal(hash(project(path,current,'art')),readyArtSourceLayer.files[path].afterSha256,'original art witness is immutable');
  }
  assert.equal(project('unknown.lua','return {}','art'),'return {}');
});

test('combined hosts still bind the actual moved painter and menu responsibilities',()=>{
  for(const path of Object.keys(proof.files)){
    const current=read(path);
    for(const changed of round2UiAddedPaths){
      assert.throws(()=>preRound2UiSource(path,current,{readSource:key=>key===changed?read(key)+'\n-- drift\n':project(key,read(key),'perf')}),/linked module drift/);
      assert.throws(()=>preRound2UiSource(path,current,{readSource:key=>{if(key===changed)throw Error('missing');return project(key,read(key),'perf');}}),/linked module missing/);
    }
    assert.notEqual(preBattleLifeOuterSource(path,current),current,'canonical historical entry recognizes union: '+path);
    assert.equal(preBattleLifeOuterSource(path,current+'\n-- future\n'),current+'\n-- future\n');
  }
});

test('combined art and extracted UI module cleanup validates every owner before any removal',()=>{
  const directory=mkdtempSync(join(tmpdir(),'abyss-art-perf-retirement-'));
  const art='src/lua/abyss_card_art_runtime.lua',paths=[art,...round2UiAddedPaths];
  const put=(path,source)=>{const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source);};
  try{
    for(const path of paths)put(path,read(path));
    for(const changed of [art,round2UiAddedPaths[0]]){
      put(changed,read(changed)+'\n-- future\n');
      assert.throws(()=>prepareBattleLifeModuleRetirement(directory),/unreviewed .* added module destination/);
      for(const path of paths)assert(existsSync(join(directory,path)),'no partial cleanup: '+path);
      put(changed,read(changed));
    }
    const retire=prepareBattleLifeModuleRetirement(directory);
    for(const path of paths)assert(existsSync(join(directory,path)),'preparation must not delete');
    retire();
    for(const path of paths){assert(!existsSync(join(directory,path)));assert(existsSync(path),'live module remains');}
  }finally{rmSync(directory,{recursive:true,force:true});}
});
