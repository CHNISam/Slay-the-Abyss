import {projectOpenPrSource} from './helpers/open-pr-source-composition.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {relicViewUiProof as proof,preRelicViewUiSource as prior} from './helpers/relic-view-ui-inverse.mjs';
import {requirePr323Source,preAcceptedPr323Source} from './helpers/pr323-accepted-source-inverse.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
const read=path=>projectOpenPrSource(path,readFileSync(path,'utf8'),'relic').replaceAll('\r\n','\n');
test('relic view UI layer recovers every exact accepted develop source',()=>{
 assert.deepEqual(Object.keys(proof.files),['config/architecture.json','data/presentation/ui_theme.json','data/relics.json','scripts/game-ui-layout.mjs','src/lua/abyss_deck_ui.lua','src/lua/abyss_game_ui.lua','src/lua/abyss_node_ui.lua','tests/lua/owned_relic_view.lua']);
 for(const [path,binding]of Object.entries(proof.files)){
  const current=read(path),accepted=prior(path,current);
  assert.equal(hash(current),binding.afterSha256);
  assert.equal(hash(accepted),binding.beforeSha256);
  assert.notEqual(accepted,current);
  assert.equal(prior(path,accepted),accepted);
  assert.equal(prior(path,current.replaceAll('\n','\r\n')),accepted);
  assert.equal(preAcceptedPr323Source(path,current),preAcceptedPr323Source(path,accepted));
  requirePr323Source(path,current);
 }
});
test('partial relic view drift and wrong paths never acquire permission',()=>{
 for(const path of Object.keys(proof.files)){
  const current=read(path);
  for(const changed of [current+'\n-- drift\n',current.slice(1)]){
   assert.equal(prior(path,changed),changed);
   assert.throws(()=>requirePr323Source(path,changed),/unreviewed integrated/);
  }
  assert.equal(prior('unregistered.lua',current),current);
  assert.equal(prior(path,null),null);
 }
});
