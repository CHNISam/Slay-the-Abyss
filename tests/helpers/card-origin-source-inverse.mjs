// Test-only outer projection of the reviewed card-origin integration. Historical
// archives and their complete-byte guards remain unchanged.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {architectureSourceFormat} from './architecture-source-format.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
const read=path=>readFileSync(new URL('../../'+path,import.meta.url),'utf8').replaceAll('\r\n','\n');
export function preCardOriginSource(path,source){
 if(typeof source!=='string')return source;
 const normalized=source.replaceAll('\r\n','\n');
 let current=normalized,previous;
 if(path==='config/architecture.json'){
  try{
   const {formatted,tokensEqual}=architectureSourceFormat(path,normalized);
   if(!tokensEqual||hash(formatted)!=='7f0385acac614f8235eeb0775f3926d19e8c48df0003fe69211fb14c2d334ebb')return source;
  }catch{return source;}
  current=read(path);
  if(hash(current)!=='8c6e10716cb4ba38d49f9164d6349e8eb2a80ca13b6c364f69181a056b7bfdbf')return source;
  assert.equal(hash(read('src/lua/abyss_card_origin_view.lua')),'10ffbb328bf0660568f0e79bf439c93a61a44f739c5f1078ffc82a89ee96a285','reviewed card origin view');
  previous=current.replace('    "abyss_card_origin": "core",\n    "abyss_card_origin_view": "ui",\n','');
  assert.equal(hash(previous),'640bb51f60c831ad2162de7907b5b7e6a241dfa6f50b15b8527234eb2da47b64','complete pre-card-origin architecture');
 }else if(path==='src/lua/abyss_nodes.lua'){
  if(hash(current)!=='f685e7a59b57f66721e3c2f8143b99aa37efd05be77371bbda61fd6e4a4a4d9f')return source;
  previous=current.replace("    local before=require('abyss_card_origin').state(instance)\n",'')
   .replace("    require('abyss_card_origin').record(run,instance,before,'permanent_upgrade',{kind='camp'})\n",'');
  assert.equal(hash(previous),'7d9732ed7b574db7dc874c378cad49f11cd47839f8b8c6763a29dfa186b20637','complete pre-card-origin Nodes');
 }else return source;
 assert.equal(hash(read('src/lua/abyss_card_origin.lua')),'44f4891881c0f9c982930298620dd789d49f5d87347ca6782e088af916099d06','reviewed card origin owner');
 return previous;
}
