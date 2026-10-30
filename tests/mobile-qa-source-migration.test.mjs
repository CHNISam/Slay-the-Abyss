import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,existsSync,rmSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {mobileQaMigration,requireMobileQaSource,preMobileQaSource,materializeBeforeMobileQa} from './helpers/mobile-qa-source-inverse.mjs';
const hash=value=>createHash('sha256').update(value).digest('hex');
test('mobile QA historical projection preserves every baseline byte and rejects drift in the current complete sources',()=>{
 assert.equal(mobileQaMigration.baseline,'58f72c2cc43a2833e9e1cdefe7c332ff0fd49243');
 for(const [path,binding]of Object.entries(mobileQaMigration.files)){
  const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
  requireMobileQaSource(path,source);
  assert.equal(binding.beforeSource===null?null:hash(binding.beforeSource),binding.beforeSha256,path);
  assert.equal(preMobileQaSource(path,source),binding.beforeSource,path);
  assert.equal(preMobileQaSource(path,source.replaceAll('\n','\r\n')),binding.beforeSource,path);
  assert.throws(()=>requireMobileQaSource(path,source+'\n-- drift\n'),/unreviewed mobile QA replay source/);
  assert.throws(()=>requireMobileQaSource(path,source.slice(1)),/unreviewed mobile QA replay source/);
 }
});

test('historical materialization restores exact original files and removes current-only additions',()=>{
 const build=resolve('build');mkdirSync(build,{recursive:true});
 const directory=mkdtempSync(join(build,'mobile-qa-history-'));
 try{
  for(const path of Object.keys(mobileQaMigration.files)){
   const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,readFileSync(path));
  }
  materializeBeforeMobileQa(directory);
  for(const [path,binding]of Object.entries(mobileQaMigration.files)){
   const target=join(directory,path);
   if(binding.beforeSource===null)assert.equal(existsSync(target),false,path);
   else assert.equal(readFileSync(target,'utf8'),binding.beforeSource,path);
  }
 }finally{
  assert.equal(dirname(resolve(directory)),build);
  assert(resolve(directory).startsWith(join(build,'mobile-qa-history-')));
  rmSync(directory,{recursive:true,force:true});
 }
});
