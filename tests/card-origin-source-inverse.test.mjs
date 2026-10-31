import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preCardOriginSource} from './helpers/card-origin-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
test('card-origin projection recovers complete prior bytes and does not hide partial or unrelated edits',()=>{
 for(const [path,expected]of [
  ['config/architecture.json','640bb51f60c831ad2162de7907b5b7e6a241dfa6f50b15b8527234eb2da47b64'],
  ['src/lua/abyss_nodes.lua','7d9732ed7b574db7dc874c378cad49f11cd47839f8b8c6763a29dfa186b20637'],
 ]){
  const source=readFileSync(path,'utf8');
  assert.equal(hash(preCardOriginSource(path,source)),expected);
  assert.equal(hash(preCardOriginSource(path,source.replaceAll('\n','\r\n'))),expected);
  for(const changed of [source+'-- unrelated\n',source.replace('abyss_card_origin','abyss_card_origin_typo')])
   assert.equal(preCardOriginSource(path,changed),changed,'foreign bytes must remain exposed');
 }
 assert.equal(preCardOriginSource('unregistered.lua','source'),'source');
 assert.equal(preCardOriginSource('src/lua/abyss_nodes.lua',null),null);
});
test('architecture projection rejects removed registration, wrong owner, duplicate keys and order changes',()=>{
 const path='config/architecture.json',source=readFileSync(path,'utf8'),policy=JSON.parse(source);
 for(const key of ['abyss_card_origin','abyss_card_origin_view']){
  const missing=structuredClone(policy);delete missing.layers[key];
  const wrong=structuredClone(policy);wrong.layers[key]=wrong.layers[key]==='core'?'ui':'core';
  for(const variant of [JSON.stringify(missing),JSON.stringify(wrong),source.replace('"'+key+'":', '"'+key+'": "core", "'+key+'":')])
   assert.equal(preCardOriginSource(path,variant),variant);
 }
 const reordered=structuredClone(policy);reordered.deferredImports.reverse();
 const variant=JSON.stringify(reordered);assert.equal(preCardOriginSource(path,variant),variant);
 for(const variant of [JSON.stringify(policy),JSON.stringify(policy,null,'\t'),source+'\n\t '])
  assert.equal(hash(preCardOriginSource(path,variant)),'640bb51f60c831ad2162de7907b5b7e6a241dfa6f50b15b8527234eb2da47b64');
});
