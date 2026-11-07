import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,copyFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {preCompendiumSource} from './helpers/compendium-source-inverse.mjs';
import {gameUiExtractionProof,gameUiExtractionAddedPaths} from './helpers/game-ui-extraction-source-inverse.mjs';
import {preRelicQuerySource} from './helpers/relic-query-source-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
// Normalize checkout endings before constructing the explicit CRLF variant.
const read=p=>preRelicQuerySource(p,readFileSync(p,'utf8').replaceAll('\r\n','\n'));
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

test('Runtime host projection recognizes complete before/after bytes but rejects partial, duplicate and foreign edits',()=>{
 const path='src/lua/abyss_game_ui.lua';
 // Reconstruct the archived deferred variant from the restored eager host.
 const source=gameUiExtractionProof.files[path].beforeSource.replace('suspendBattle(run,deckOpen,potionOpen))','suspendBattle(run,deckOpen,potionOpen),self.mode == \"battle\")')
  .replace('    local function renderBattlePage(run)\n','    local function renderBattlePage(run)\n        -- Paint after every page visibility setter, which may re-enter state.\n');
 assert.equal(hash(source),'4ab3ec613f79b1507c7c529c57547d42f93fa7eafc89aeb9afb1b8c64ab34c25');
 const call='            suspendBattle(run,deckOpen,potionOpen),self.mode == "battle")';
 const comment='        -- Paint after every page visibility setter, which may re-enter state.\n';
 const oldCall='            suspendBattle(run,deckOpen,potionOpen))';
 const before=source.replace(call,oldCall).replace(comment,'');
 assert.equal(hash(before),'165e2ad1180cab9daf5321b46d1f87fe9c34ed6ebbcd3c3a8b495d23974e0933');
 assert.equal(preCompendiumSource(path,before),preCompendiumSource(path,source));
 for(const variant of [source.replace(call,oldCall),source.replace(comment,''),
  source.replace(call,call+call),source.replace(comment,comment+comment),source.slice(1),source+'\n-- foreign\n']){
  assert.notEqual(variant,source);assert.equal(preCompendiumSource(path,variant),variant);
  for(const input of ['config/architecture.json','src/lua/abyss_node_ui_faces.lua',path])
   assert.throws(()=>preCompendiumSource(input,read(input),{[path]:variant}),/reviewed compendium owner/);
 }
 for(const owner of [source,source.replaceAll('\n','\r\n'),before])
  assert.equal(preCompendiumSource(path,source,{[path]:owner}),preCompendiumSource(path,source));
});

test('warm Runtime projections still reread actual linked host files and reject disk drift or deletion',async t=>{
 const root=mkdtempSync(join(tmpdir(),'compendium-runtime-'));
 t.after(()=>rmSync(root,{recursive:true,force:true}));
 const owners=['src/lua/abyss_game_ui.lua','src/lua/abyss_compendium_catalog.lua','src/lua/abyss_relic_text.lua','src/lua/abyss_node_ui_faces.lua'];
 for(const path of [...owners,...gameUiExtractionAddedPaths,'src/lua/abyss_actor.lua','src/lua/abyss_combat.lua','src/lua/abyss_actor_power_rules.lua','config/architecture.json','tests/helpers/core-lifecycle-source-inverse.mjs','tests/helpers/actor-lifecycle-before.lua','tests/helpers/combat-lifecycle-before.json','tests/helpers/relic-query-source-inverse.mjs','tests/helpers/relic-query-baseline-391306af.json.gz','tests/helpers/query-living-wall-before.lua','tests/helpers/relic-lifecycle-baseline-391306af.json.gz','tests/helpers/relic-lifecycle-architecture-source-inverse.json','tests/helpers/m7-core-final-source-inverse.mjs','tests/helpers/m7-core-final-before.json.gz','tests/helpers/power-shop-source-inverse.mjs','tests/helpers/power-shop-before-2c85.json.gz','tests/helpers/compendium-source-inverse.mjs','tests/helpers/architecture-source-format.mjs','tests/helpers/game-ui-extraction-source-inverse.mjs','tests/helpers/game-ui-extraction-source-layer.json']){
  const target=join(root,path);mkdirSync(dirname(target),{recursive:true});if(path==='config/architecture.json'||path==='src/lua/abyss_actor.lua'||path==='src/lua/abyss_combat.lua')writeFileSync(target,read(path));else copyFileSync(path,target);
 }
 const {preCompendiumSource:project}=await import(pathToFileURL(join(root,'tests/helpers/compendium-source-inverse.mjs')).href);
 const host=owners[0],source=read(host),file=join(root,host);
 for(const path of ['config/architecture.json','src/lua/abyss_node_ui_faces.lua',host]){
  const input=read(path),expected=project(path,input);
  writeFileSync(file,source+'\n-- actual linked drift\n');
  assert.throws(()=>project(path,input),/reviewed compendium owner|reviewed GameUI extraction linked owner/);
  writeFileSync(file,source);assert.equal(project(path,input),expected);
  rmSync(file);assert.throws(()=>project(path,input),/ENOENT/);
  writeFileSync(file,source);assert.equal(project(path,input),expected);
 }
});
