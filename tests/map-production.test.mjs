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
test('production Map preserves raw seed and strict v3 restoration without preselecting encounters',()=>{
  const directory=mkdtempSync(join(tmpdir(),'abyss-production-map-'));
  try {
    const file=join(directory,'case.lua');
    writeFileSync(file,`local Map=require('abyss_map');local Data=require('abyss_data')
local m=Map.generate(Data,'2780424839485660359')
assert(m.version==3 and m.runSeed=='2780424839485660359' and m.mapSeed=='2780424839485660360')
assert(m.topologyState.words[1] and m.randomState.words[2])
assert(m.encounterRandomSeed==nil and m.encounterSeed==nil)
for _,node in ipairs(m.nodes)do assert(node.encounterId==nil)end
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
test('source floor-fourteen elite nodes can enter the real Run through a legal map frontier',()=>{
  const directory=mkdtempSync(join(tmpdir(),'abyss-map-elite-'));
  try {
    const file=join(directory,'case.lua');
    writeFileSync(file,`local Map,Run,Nodes=require('abyss_map'),require('abyss_run'),require('abyss_nodes')
local Data=require('abyss_data')
for _,seed in ipairs({1,42,600})do
 local m=Map.generate(Data,seed);local index={};local target
 for _,n in ipairs(m.nodes)do index[n.id]=n;if n.floor==14 and n.type=='elite'then target=n.id end end
 assert(target)
 local function route(n)
  if n.id==target then return {n.id}end
  if n.floor>=14 then return nil end
  for _,id in ipairs(n.nextIds)do local path=route(index[id]);if path then table.insert(path,1,n.id);return path end end
 end
 local path;for _,n in ipairs(Map.available(m))do path=route(n);if path then break end end
 assert(path and #path==14)
 -- Position a legal frontier; this isolates map eligibility, not a full playthrough.
 for i=1,13 do assert(Map.choose(m,path[i]))end
 local run=Run.new(Data,seed);assert(Nodes.enter(run,m,target))
 assert(run.floor==14 and run.encounterTier=='elite' and run.phase=='combat')
end`);
    const result=runLua(file);assert.equal(result.status,0,result.stderr||result.stdout);
  }finally{rmSync(directory,{recursive:true,force:true});}
});
