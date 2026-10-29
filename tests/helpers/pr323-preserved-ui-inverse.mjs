// Exact whole-source historical replay layer; current runtime tests never use it.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('tests/fixtures/pr323-preserved-ui-layer.json.gz');
assert.equal(hash(bytes),'ff8fcf8c4bc81912b2046fc71eee573fca57f15fd3499a5621e613dcde90ab2c');
export const preservedUiLayer=JSON.parse(gunzipSync(bytes));
export function requirePreservedUiSource(path,source){
 const binding=preservedUiLayer.files[path];assert(binding,'registered preservation layer: '+path);
 assert.equal(hash(source.replaceAll('\r\n','\n')),binding.afterSha256,'unreviewed preservation source drift: '+path);
 assert.equal(hash(binding.beforeSource),binding.beforeSha256,'complete preservation baseline identity: '+path);
 return binding;
}
export function prePreservedUiSource(path,source){
 if(source===null)return source;
 const normalized=source.replaceAll('\r\n','\n'),binding=preservedUiLayer.files[path];
 if(!binding||hash(normalized)!==binding.afterSha256)return normalized;
 assert.equal(hash(binding.beforeSource),binding.beforeSha256,'complete preservation baseline identity: '+path);
 return binding.beforeSource;
}
export function materializeBeforePreservedUi(directory){
 // Validate every live input before writing any historical file.
 const sources=Object.keys(preservedUiLayer.files).map(path=>{
  const current=readFileSync(path,'utf8');requirePreservedUiSource(path,current);
  return [path,prePreservedUiSource(path,current)];
 });
 for(const[path,source]of sources){const target=join(directory,path);mkdirSync(dirname(target),{recursive:true});writeFileSync(target,source);}
}
