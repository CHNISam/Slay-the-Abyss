import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const hash=source=>createHash('sha256').update(source).digest('hex');
export const nodesDepletedFixtureRepair=Object.freeze({
 path:'tests/lua/nodes.lua',
 beforeSha256:'6a0b43e75b4a8c83293d6f4e422a58dcba93ae97d759ed6e9088851b0b0fb379',
 afterSha256:'3726b1b4dec7563e359923453adff5b915b326ebb4ea861618425347dd41217e',
 before:'    run.relics = {}; for _, relic in ipairs(data.relics.relics) do run.relics[#run.relics + 1] = relic.id end\n',
 after:"    -- Queue exhaustion is the checkpoint below; retain only valid acquired owners.\n    assert(Run.obtainRelic(run, 'circlet'))\n",
});
// Only the historical whole-body proof receives the old fixture input. Runtime
// cases exercise valid acquired owners and the real complete source queues.
export function preNodesDepletedFixtureSource(path,source){
 if(path!==nodesDepletedFixtureRepair.path)return source;
 const binding=nodesDepletedFixtureRepair,current=source.replaceAll('\r\n','\n');
 if(hash(current)===binding.beforeSha256)return current;
 assert.equal(hash(current),binding.afterSha256,'unreviewed nodes depleted-fixture source drift');
 assert.equal(current.split(binding.after).length,2,'one exact nodes owner fixture repair');
 const previous=current.replace(binding.after,binding.before);
 assert.equal(hash(previous),binding.beforeSha256,'complete original nodes fixture recovered');
 assert.equal(previous.split(binding.before).length,2,'one exact original nodes owner fixture');
 assert.equal(previous.replace(binding.before,binding.after),current,'exact nodes fixture forward roundtrip');
 return previous;
}
