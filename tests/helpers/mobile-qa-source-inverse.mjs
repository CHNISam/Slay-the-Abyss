import {preOriginalPr323Source} from './pr323-accepted-source-inverse.mjs';
// Historical replay only. Current behavior is exercised by the mobile, relic
// and admission tests against the working source, without this projection.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,rmSync,mkdirSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('docs/reviews/mobile-qa-source-migration-20261028.json.gz');
assert.equal(hash(bytes),'a8fd441e705c5c2d9f03ec8a6ef8d4a36b89bcc8192699ff79b2f66dc10610a2');
export const mobileQaMigration=JSON.parse(gunzipSync(bytes));
export function requireMobileQaSource(path,source){
 source=preOriginalPr323Source(path,source);
 const binding=mobileQaMigration.files[path];
 assert(binding,'registered mobile QA source: '+path);
 assert.equal(typeof source,'string','mobile QA source must exist: '+path);
 assert.equal(hash(source.replaceAll('\r\n','\n')),binding.afterSha256,'unreviewed mobile QA replay source: '+path);
 return binding;
}
export function preMobileQaSource(path,source){
 source=preOriginalPr323Source(path,source);
 if(source===null)return null;
 const normalized=source.replaceAll('\r\n','\n'),binding=mobileQaMigration.files[path];
 if(!binding || hash(normalized)!==binding.afterSha256)return normalized;
 assert.equal(binding.beforeSource===null?null:hash(binding.beforeSource),binding.beforeSha256,'complete mobile QA baseline identity: '+path);
 return binding.beforeSource;
}
export function materializeBeforeMobileQa(directory){
 const sources=Object.keys(mobileQaMigration.files).map(path=>{
  const source=preOriginalPr323Source(path,readFileSync(path,'utf8'));
  requireMobileQaSource(path,source);
  return [path,preMobileQaSource(path,source)];
 });
 for(const [path,before]of sources){
  const target=join(directory,path);
  if(before===null)rmSync(target,{force:true});else{
   mkdirSync(dirname(target),{recursive:true});writeFileSync(target,before);
  }
 }
}
// Live disk inputs must match the whole-source archive before older inverses
// consume their exact develop responsibility witnesses.
export function readBeforeMobileQaSource(path){
 const source=preOriginalPr323Source(path,readFileSync(path,'utf8'));
 if(Object.hasOwn(mobileQaMigration.files,path))requireMobileQaSource(path,source);
 return preMobileQaSource(path,source);
}
