import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { compareFixtures } from '../scripts/sts1-map-evidence.mjs';
import { mapGeometry } from '../scripts/map-ui-layout.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('production Map matches every unchanged complete A0 golden including full signed64 input', () => {
  const report=compareFixtures();
  assert.equal(report.matches,12,JSON.stringify(report.records.map(({seed,status})=>({seed,status}))));
  assert.equal(report.status,'PASS');
});
test('production Map preserves raw seed, strict v3 restoration and separate legacy encounter state',()=>{
  const directory=mkdtempSync(join(tmpdir(),'abyss-production-map-'));
  try {
    const file=join(directory,'case.lua');
    writeFileSync(file,`local Map=require('abyss_map');local Data=require('abyss_data')
local m=Map.generate(Data,'2780424839485660359')
assert(m.version==3 and m.runSeed=='2780424839485660359' and m.mapSeed=='2780424839485660360')
assert(m.topologyState.words[1] and m.randomState.words[2])
assert(m.encounterRandomSeed>=0 and m.encounterRandomSeed<65536)
for _=1,17 do assert(Map.choose(m,Map.available(m)[1].id))end
local r=assert(Map.restore(Data,Map.snapshot(m)));assert(r.floor==17)
local before=Map.snapshot(m);assert(not Map.choose(m,'f1_l1'));assert(#m.path==#before.path)
for _,field in ipairs({'runSeed','mapSeed','sourceSignature'})do
 local bad=Map.snapshot(m);bad[field]='tamper';assert(Map.restore(Data,bad)==nil)
end
local bad=Map.snapshot(m);bad.randomState.words[1]='0000000000000000';assert(Map.restore(Data,bad)==nil)
bad=Map.snapshot(m);bad.version=2;assert(Map.restore(Data,bad)==nil)
bad=Map.snapshot(m);bad.path[1]='f16_l4';assert(Map.restore(Data,bad)==nil)
assert(m.nodes[#m.nodes-1].id=='f16_l4' and m.nodes[#m.nodes].id=='f17_l4')
assert(Map.generate(Data,42).runSeed=='42')
for _,badSeed in ipairs({'01','-0','9223372036854775808',9007199254740992,0.5})do assert(not pcall(Map.generate,Data,badSeed))end
print('MAP_PRODUCTION_RAW_PASS')`);
    const result=runLua(file);assert.equal(result.status,0,result.stderr||result.stdout);
  } finally {rmSync(directory,{recursive:true,force:true});}
});
test('production map UI allocates seven columns and all ninety-two source path slots',()=>{
  assert.equal(mapGeometry().lanes,7);assert.equal(mapGeometry().maxNodes,92);
});
