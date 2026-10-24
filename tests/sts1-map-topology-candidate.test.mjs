import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';
import { requestedSeeds } from '../scripts/sts1-map-evidence.mjs';

const fixtureRoot = 'tests/fixtures/sts1/maps';
const manifest = JSON.parse(readFileSync(`${fixtureRoot}/manifest.json`));
function check(body) {
  const dir = mkdtempSync(join(tmpdir(), 'abyss-map-topology-'));
  try {
    const file = join(dir, 'check.lua');
    writeFileSync(file, `local T=dofile('tools/candidates/sts1_map_topology.lua')\n${body}\nprint('TOPOLOGY_CANDIDATE_PASS')`);
    const result = runLua(file);
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /TOPOLOGY_CANDIDATE_PASS/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

test('Act1 raw signed64 run seed adds one exactly, including zero mapping and signed wrap', () => check(`
for _,v in ipairs(${toLua([
  ['0','1'],['1','2'],['-1','0'],['-17','-16'],['65535','65536'],
  ['2780424839485660359','2780424839485660360'],
  ['9223372036854775807','-9223372036854775808'],['-9223372036854775808','-9223372036854775807'],
])}) do assert(T.seedForActOne(v[1])==v[2], 'seed mapping '..v[1]) end
for _,v in ipairs({'','-0','00','+1',' 1','1.0','1e3','9223372036854775808','-9223372036854775809',1,true,{}}) do
 assert(not pcall(T.seedForActOne,v), 'unsupported seed accepted')
end
`));

for (const seed of requestedSeeds()) {
  test(`independent captured golden ${seed}: topology-only coordinates and every edge`, () => {
    assert.equal(manifest.revision, 'ea5200f21fa566de77ec14b6155b3bf3756dccbf');
    assert.equal(manifest.executableSha256, 'add3b40d49dd5e2e371818bdc9ebfa991344b494732b0698ecaf392ecb0f3660');
    assert.deepEqual(manifest.scope, { act: 1, ascension: 0, height: 15, width: 7, pathDensity: 6 });
    const record = manifest.records.find(r => r.seed === seed), bytes = readFileSync(`${fixtureRoot}/${seed}.json`);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), record.fixtureSha256);
    assert.equal(record.exitCode, 0); assert.equal(record.status, 'CAPTURED');
    assert.equal(record.error, undefined); assert.deepEqual(record.invariantErrors, []);
    assert.deepEqual(record.arguments, [`--seed=${seed}`, '--a0']);
    const expected = JSON.parse(bytes);
    assert.equal(expected.seed, seed); assert.equal(expected.revision, manifest.revision);
    assert.equal(expected.rawSha256, record.rawSha256);
    const nodes = expected.nodes.map(({ x, y }) => ({ x, y }));
    check(`local map=T.generate(${toLua(seed)})
local nodes=${toLua(nodes)};local edges=${toLua(expected.edges)}
assert(map.runSeed==${toLua(seed)} and map.mapSeed==${toLua(BigInt.asIntN(64,BigInt(seed)+1n).toString())})
assert(#map.nodes==#nodes, 'connected coordinate count')
for i,n in ipairs(nodes) do assert(map.nodes[i].x==n.x and map.nodes[i].y==n.y, 'coordinate '..i) end
assert(#map.edges==#edges, 'edge count')
for i,e in ipairs(edges) do for k,v in pairs(e) do assert(map.edges[i][k]==v, 'edge '..i..'/'..k) end end
assert(map.randomState.counter>=90, 'path call counter missing')`);
  });
}

test('independent draw vectors cover second-start reroll, both crossing clamps and retained parents', () => check(`
local function scripted(height,width,density,values,ranges)
 local at=0
 local map=T.generateDungeon(height,width,density,function(lo,hi)
  at=at+1;assert(ranges[at] and lo==ranges[at][1] and hi==ranges[at][2], 'draw range '..at)
  return values[at]
 end)
 assert(at==#values, 'unexpected draw count');return map
end
local m=scripted(2,3,2,{0,1,0,2,-1},{{0,2},{0,1},{0,2},{0,2},{-1,0}})
assert(#m.nodes==2 and #m.edges==1 and m.edges[1].src_x==0 and m.edges[1].dst_x==1)
assert(#m.grid[2][2].parents==2 and #m.grid[1][3].edges==0, 'first-row deletion must retain parent references')
local left=scripted(2,3,2,{0,1,1,-1},{{0,2},{0,1},{0,2},{-1,1}})
assert(#left.edges==1 and left.edges[1].src_x==0 and left.edges[1].dst_x==1)
assert(left.grid[2][2].parents[2]==left.grid[1][2], 'left clamp target')
local right=scripted(2,3,2,{2,-1,1,1},{{0,2},{-1,0},{0,2},{-1,1}})
assert(#right.edges==1 and right.edges[1].src_x==1 and right.edges[1].dst_x==1)
assert(right.grid[2][2].parents[2]==right.grid[1][2], 'right clamp target')
local duplicate=scripted(2,3,3,{0,0,1,0,0,0},{{0,2},{0,1},{0,2},{-1,1},{0,2},{0,1}})
assert(#duplicate.grid[1][1].edges==1 and #duplicate.grid[2][1].parents==2)
assert(duplicate.grid[2][1].parents[1]==duplicate.grid[2][1].parents[2], 'duplicate parents are source behavior')
`));

test('independent ancestry cases preserve the source axis quirk, inclusive depth and conditional retry', () => check(`
local common={x=0,y=0,parents={}};local left,right=common,common
for y=1,6 do left={x=0,y=y,parents={left}};right={x=1,y=y,parents={right}} end
assert(T.commonAncestor(left,right,5)==common and T.commonAncestor(left,right,4)==nil)
local a={x=2,y=0,parents={}};local b={x=0,y=0,parents={}};local c={x=4,y=0,parents={}}
assert(T.commonAncestor({x=2,y=1,parents={b,a}},{x=3,y=1,parents={a,c}},5)==nil,
 'source x<y quirk must not silently become x<x')
local values={0,0,0,1,0,0,0,1,-1,0};local at=0
local ranges={{0,2},{0,1},{0,1},{0,2},{-1,1},{-1,1},{0,2},{0,1},{-1,1},{0,1}}
local m=T.generateDungeon(3,3,3,function(lo,hi)
 at=at+1;assert(ranges[at] and lo==ranges[at][1] and hi==ranges[at][2], 'ancestor draw '..at);return values[at]
end)
assert(at==10 and #m.grid[2][2].edges==1 and m.grid[2][2].edges[1].dst_x==1)
assert(#m.grid[3][1].parents==1 and #m.grid[3][2].parents==2, 'short-merge retry must redirect before adding parent')
`));
