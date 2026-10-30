import {preReadyArtSource} from './helpers/ready-art-source-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,existsSync,rmSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {preBackgroundSource, backgroundSourceLayer, prepareBackgroundRetirement} from './helpers/official-background-source-inverse.mjs';
const hash=s=>s===null?null:createHash('sha256').update(s).digest('hex');
test('exact background inverse preserves old whole-file identities and exposes any unknown drift',()=>{
 for(const [path,binding] of Object.entries(backgroundSourceLayer.files)){
  const source=preReadyArtSource(path,readFileSync(path,'utf8')).replaceAll('\r\n','\n');
  assert.equal(hash(source),binding.afterSha256,path);
  const before=preBackgroundSource(path,source);assert.equal(hash(before),binding.beforeSha256,path);
  assert.equal(preBackgroundSource(path,source.replaceAll('\n','\r\n')),before);
  assert.equal(preBackgroundSource(path,source+'\n-- future'),source+'\n-- future');
  assert.equal(preBackgroundSource(path,before),before);
 }
});
test('background historical retirement checks every owned destination and never mutates live sources',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-background-inverse-'));
 try{
  const path='src/lua/abyss_menu_background.lua',target=join(directory,path),source=readFileSync(path,'utf8');
  mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source+'\n-- future');
  assert.throws(()=>prepareBackgroundRetirement(directory),/unreviewed background/);assert(existsSync(target));
  writeFileSync(target,source);const retire=prepareBackgroundRetirement(directory);assert(existsSync(target));
  retire();assert(!existsSync(target));assert(existsSync(path));
  assert.throws(()=>prepareBackgroundRetirement(process.cwd()),/separate historical/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
