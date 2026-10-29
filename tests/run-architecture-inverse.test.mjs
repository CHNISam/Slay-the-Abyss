import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preCoreArchitectureSource} from './helpers/core-architecture-inverse.mjs';
import {preIntegratedNodeUiSource,postNodeUi} from './helpers/approved-node-ui-refactor.mjs';
const path='config/architecture.json';
const read=()=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const rows=['abyss_run_initialization','abyss_run_transition','abyss_run_rooms','abyss_run_settlement','abyss_run_potions'];
const tail=',\n'+rows.map(name=>`    "${name}": "core"`).join(',\n');

test('Run registration projects through the exact retained Nodes identity to the original complete UI source',()=>{
  const source=read(),nodes=source.replace(tail,'');
  assert.equal(hash(source),'bc1a6dca0701091f73a8464de978a4b202597c70500c84c73f33a855a510240e');
  assert.equal(hash(nodes),'bab439c579d813dc91a631e29aac4bff41237030efdd33a90a5b84158df7367d');
  const prior=preCoreArchitectureSource(path,source);
  assert.equal(hash(prior),'0c15a29fa24a4284eb0760b750356b658eb02e28b71d23b46839520777222cdb');
  assert.equal(preCoreArchitectureSource(path,nodes),prior);
  assert.equal(preCoreArchitectureSource(path,source.replaceAll('\n','\r\n')),prior);
  assert.equal(hash(preIntegratedNodeUiSource(path,source)),postNodeUi.files[path].beforeSha256);
});

test('Run projection cannot conceal damaged Nodes, changed UI, reordered groups or unknown registration',()=>{
  const source=read(),line='    "abyss_run_initialization": "core",\n';
  const variants=[
    source.replace(line,''),
    source.replace(line,line+line),
    source.replace('"abyss_run_initialization": "core"','"abyss_run_initialization": "ui"'),
    source.replace('"abyss_run_initialization": "core"','"abyss_run_unknown": "core"'),
    source.replace(tail,tail+',\n    "unknown_core": "core"'),
    source.replace('"abyss_nodes_common": "core"','"abyss_nodes_common": "ui"'),
    source.replace('"abyss_battle_potion_popup": "ui"','"abyss_battle_potion_popup": "core"'),
    source.replace('    "abyss_battle_potion_popup": "ui",\n',''),
    source.replace('    "abyss_run_initialization": "core",\n    "abyss_run_transition": "core"','    "abyss_run_transition": "core",\n    "abyss_run_initialization": "core"'),
    source.replace(tail,'').replace('  "layers": {\n','  "layers": {\n'+tail.slice(2)+',\n'),
  ];
  for(const changed of variants){
    assert.notEqual(changed,source);
    assert.throws(()=>preIntegratedNodeUiSource(path,changed),/unreviewed integrated/);
  }
});
