import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preCompendiumSource} from './helpers/compendium-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
// Normalize checkout endings before constructing the explicit CRLF variant.
const read=p=>readFileSync(p,'utf8').replaceAll('\r\n','\n');
test('compendium inverse restores exact pre-change bytes and leaves unrelated edits visible',()=>{
 for(const [path,expected]of [
  ['config/architecture.json','8c6e10716cb4ba38d49f9164d6349e8eb2a80ca13b6c364f69181a056b7bfdbf'],
  ['src/lua/abyss_game_ui.lua','7beb2208633cef99b31bdae7d0729b31d9776724df2a6cbd532683eaf4b60c46'],
  ['src/lua/abyss_node_ui_faces.lua','285281e48bcd5dfeb20bc03c8c2be526eda57e169689ba2e09b10d5babd3986a'],
 ]){
  const source=read(path);
  assert.equal(hash(preCompendiumSource(path,source)),expected);
  assert.equal(hash(preCompendiumSource(path,source.replaceAll('\n','\r\n'))),expected);
  const foreign=source+'\n-- unknown change\n';assert.equal(preCompendiumSource(path,foreign),foreign);
 }
 assert.equal(preCompendiumSource('unknown.lua','text'),'text');
 assert.equal(preCompendiumSource('config/architecture.json',null),null);
});
test('compendium architecture inverse rejects incomplete, duplicate, reordered or wrong-layer registrations',()=>{
 const path='config/architecture.json',source=read(path),policy=JSON.parse(source);
 for(const key of ['abyss_compendium_catalog','abyss_relic_text']){
  const missing=structuredClone(policy);delete missing.layers[key];
  const wrong=structuredClone(policy);wrong.layers[key]=wrong.layers[key]==='ui'?'core':'ui';
  for(const variant of [JSON.stringify(missing),JSON.stringify(wrong),source.replace('"'+key+'":','"'+key+'": "core", "'+key+'":')])
   assert.equal(preCompendiumSource(path,variant),variant);
 }
 const reordered=structuredClone(policy);reordered.deferredImports.reverse();
 const variant=JSON.stringify(reordered);assert.equal(preCompendiumSource(path,variant),variant);
 for(const variant of [JSON.stringify(policy),JSON.stringify(policy,null,'\t'),source+'\n\t '])
  assert.equal(hash(preCompendiumSource(path,variant)),'8c6e10716cb4ba38d49f9164d6349e8eb2a80ca13b6c364f69181a056b7bfdbf');
});
test('compendium projections bind every new owner and never accept drift in detached providers',()=>{
 for(const path of ['config/architecture.json','src/lua/abyss_node_ui_faces.lua','src/lua/abyss_game_ui.lua']){
  for(const owner of ['src/lua/abyss_compendium_catalog.lua','src/lua/abyss_relic_text.lua','src/lua/abyss_node_ui_faces.lua','src/lua/abyss_game_ui.lua'])
   assert.throws(()=>preCompendiumSource(path,read(path),{[owner]:read(owner)+'-- changed\n'}),/reviewed compendium owner/);
 }
});

test('M9 projection accepts only the exact two core registrations and preserves unrelated drift',()=>{
 const path='config/architecture.json',source=read(path),policy=JSON.parse(source);
 const first='abyss_combat_native_play',second='abyss_combat_queued_play';
 for(const key of [first,second]){
  const missing=structuredClone(policy);delete missing.layers[key];
  const wrong=structuredClone(policy);wrong.layers[key]='ui';
  for(const variant of [JSON.stringify(missing),JSON.stringify(wrong),
   source.replace('"'+key+'":','"'+key+'": "core", "'+key+'":')])
   assert.equal(preCompendiumSource(path,variant),variant);
 }
 const reversed=source.replace('"'+first+'": "core",\n    "'+second+'": "core"',
  '"'+second+'": "core",\n    "'+first+'": "core"');
 assert.notEqual(reversed,source);
 assert.equal(preCompendiumSource(path,reversed),reversed);
 const foreign=structuredClone(policy);foreign.layers.abyss_actor='ui';
 const variant=JSON.stringify(foreign);assert.equal(preCompendiumSource(path,variant),variant);
});
