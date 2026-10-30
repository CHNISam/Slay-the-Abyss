import {projectArtPerfSource} from './helpers/art-perf-source-composition.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {preReadyArtSource, readyArtSourceLayer, prepareReadyArtRetirement} from './helpers/ready-art-source-inverse.mjs';
const hash=s=>s===null?null:createHash('sha256').update(s).digest('hex');
test('exact ready-art inverse preserves old whole-file identities and exposes any unknown drift',()=>{
 for(const [path,binding] of Object.entries(readyArtSourceLayer.files)){
  const source=projectArtPerfSource(path,readFileSync(path,'utf8'),'art').replaceAll('\r\n','\n');
  assert.equal(hash(source),binding.afterSha256,path);
  const before=preReadyArtSource(path,source);assert.equal(hash(before),binding.beforeSha256,path);
  assert.equal(preReadyArtSource(path,source.replaceAll('\n','\r\n')),before);
  assert.equal(preReadyArtSource(path,source+'\n-- future'),source+'\n-- future');
  assert.equal(preReadyArtSource(path,before),before);
 }
});
test('ready-art historical retirement checks every owned destination and never mutates live sources',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-ready-art-inverse-'));
 try{
  const path='src/lua/abyss_card_art_runtime.lua',target=join(directory,path),source=readFileSync(path,'utf8');
  mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source+'\n-- future');
  assert.throws(()=>prepareReadyArtRetirement(directory),/unreviewed ready-art/);assert(existsSync(target));
  writeFileSync(target,source);const retire=prepareReadyArtRetirement(directory);assert(existsSync(target));
  retire();assert(!existsSync(target));assert(existsSync(path));
  assert.throws(()=>prepareReadyArtRetirement(process.cwd()),/separate historical/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
