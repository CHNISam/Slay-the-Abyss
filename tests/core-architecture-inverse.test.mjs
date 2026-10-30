import {preRosterConfigSource} from './helpers/competition-roster-config-composition.mjs';
import {preNodesBattleMaxHpConfig} from './helpers/nodes-battle-max-hp-config-inverse.mjs';
import {historicalTest as test} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preCoreArchitectureSource} from './helpers/core-architecture-inverse.mjs';
import {preIntegratedNodeUiSource,postNodeUi} from './helpers/approved-node-ui-refactor.mjs';
const path='config/architecture.json';
const read=p=>preRosterConfigSource(p,readFileSync(p,'utf8').replaceAll('\r\n','\n'));
const hash=s=>createHash('sha256').update(s).digest('hex');
// Preserve this original Nodes-only proof; the outer proof checks the actual union.
const current=()=>preNodesBattleMaxHpConfig(path,read(path),'nodes');

test('only reviewed core registration metadata projects to the unchanged complete UI architecture identity',()=>{
  const source=current(),prior=preCoreArchitectureSource(path,source);
  assert.equal(hash(prior),'0c15a29fa24a4284eb0760b750356b658eb02e28b71d23b46839520777222cdb');
  assert.equal(hash(prior),postNodeUi.files[path].afterSha256);
  assert.equal(preCoreArchitectureSource(path,source.replaceAll('\n','\r\n')),prior);
  assert.equal(preCoreArchitectureSource(path,prior),prior);
  assert.equal(preCoreArchitectureSource('other.json',source),source);
  assert.equal(hash(preIntegratedNodeUiSource(path,source)),postNodeUi.files[path].beforeSha256);
  assert.equal(hash(readFileSync('tests/fixtures/approved-ui-post-node-layer.json')),'7d12b5b51d93795162ed4fa9869f5585db30d77fe99650de86ef3938caa737ee');
});

test('partial, altered, duplicated, moved and unrelated architecture changes still fail the original whole-source UI oracle',()=>{
  const source=current(),first='    "abyss_nodes_common": "core",\n';
  const rows=['abyss_nodes_common','abyss_nodes_entry','abyss_nodes_events','abyss_nodes_sources'];
  const tail=',\n'+rows.map(name=>`    "${name}": "core"`).join(',\n');
  const variants=[
    source.replace(first,''),
    source.replace('"abyss_nodes_common": "core"','"abyss_nodes_common": "ui"'),
    source.replace('"abyss_nodes_common": "core"','"abyss_nodes_unknown": "core"'),
    source.replace(first,first+first),
    source.replace(tail,tail+',\n    "unreviewed_core": "core"'),
    source.replace('"abyss_battle_potion_popup": "ui"','"abyss_battle_potion_popup": "core"'),
    source.replace('    "abyss_battle_potion_popup": "ui",\n',''),
    source.replace('"abyss_card_skin": "ui"','"abyss_card_skin": "core"'),
    source+'\n',
    source.replace(tail,'').replace('  "layers": {\n','  "layers": {\n'+tail.slice(2)+',\n'),
    source.replace(tail,'').replace('  "dynamicExceptions": [],','  "wrongObject": {"base": "core"'+tail+'\n  },\n  "dynamicExceptions": [],'),
  ];
  for(const changed of variants){
    assert.notEqual(changed,source);
    assert.throws(()=>preIntegratedNodeUiSource(path,changed),/unreviewed integrated/);
  }
});
