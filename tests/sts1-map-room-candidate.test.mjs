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
  const dir = mkdtempSync(join(tmpdir(), 'abyss-map-rooms-'));
  try {
    const file = join(dir, 'check.lua');
    writeFileSync(file, `local loaded,C=pcall(dofile,'tools/candidates/sts1_map_rooms.lua')\nassert(loaded,'complete room candidate is missing: '..tostring(C))\n${body}\nprint('ROOM_CANDIDATE_PASS')`);
    const result = runLua(file);
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /ROOM_CANDIDATE_PASS/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

for (const seed of requestedSeeds()) {
  test(`independent captured golden ${seed}: full coordinates, edges and room types`, () => {
    const record = manifest.records.find(r => r.seed === seed), bytes = readFileSync(`${fixtureRoot}/${seed}.json`);
    assert.equal(manifest.revision, 'ea5200f21fa566de77ec14b6155b3bf3756dccbf');
    assert.equal(manifest.executableSha256, 'add3b40d49dd5e2e371818bdc9ebfa991344b494732b0698ecaf392ecb0f3660');
    assert.equal(createHash('sha256').update(bytes).digest('hex'), record.fixtureSha256);
    assert.equal(record.exitCode, 0); assert.equal(record.status, 'CAPTURED');
    assert.equal(record.error, undefined); assert.deepEqual(record.invariantErrors, []);
    assert.deepEqual(record.arguments, [`--seed=${seed}`, '--a0']);
    const expected = JSON.parse(bytes);
    check(`local map=C.generate(${toLua(seed)})
local nodes=${toLua(expected.nodes)};local edges=${toLua(expected.edges)}
assert(map.runSeed==${toLua(seed)} and map.mapSeed==${toLua(BigInt.asIntN(64, BigInt(seed)+1n).toString())})
assert(#map.nodes==#nodes,'connected coordinate count')
for i,n in ipairs(nodes) do for k,v in pairs(n) do assert(map.nodes[i][k]==v,'room '..i..'/'..k..': '..tostring(map.nodes[i][k])..' expected '..tostring(v)) end end
assert(#map.edges==#edges,'edge count')
for i,e in ipairs(edges) do for k,v in pairs(e) do assert(map.edges[i][k]==v,'edge '..i..'/'..k) end end
local Topology=dofile('tools/candidates/sts1_map_topology.lua')
local path=Topology.generate(${toLua(seed)}).randomState
assert(map.topologyState.words[1]==path.words[1] and map.topologyState.words[2]==path.words[2])
assert(map.randomState.counter==path.counter and map.topologyState.counter==path.counter,'raw shuffle must not advance wrapper counter')
assert(map.randomState.words[1]~=path.words[1] or map.randomState.words[2]~=path.words[2],'raw shuffle must advance primitive')
assert(map.grid[1][1].type=='combat' and map.grid[9][1].type=='treasure' and map.grid[15][1].type=='camp','fixed rows include disconnected cells')`);
  });
}

test('A0 quotas use binary32 products before Java half-up round for every possible grid count', () => {
  const cases = Array.from({ length: 106 }, (_, count) => ({ count,
    shop: Math.floor(Math.fround(count * Math.fround(.05)) + .5),
    camp: Math.floor(Math.fround(count * Math.fround(.12)) + .5),
    elite: Math.floor(Math.fround(count * Math.fround(.08)) + .5),
    event: Math.floor(Math.fround(count * Math.fround(.22)) + .5) }));
  assert.equal(cases[50].shop, 3); assert.equal(cases[25].event, 6);
  check(`for _,v in ipairs(${toLua(cases)}) do local q=C.quotas(v.count)
for _,k in ipairs({'shop','camp','elite','event'}) do assert(q[k]==v[k],'quota '..v.count..'/'..k) end end
for _,v in ipairs({-1,106,1.5,'50',true,{}}) do assert(not pcall(C.quotas,v),'unsupported count') end`);
});

test('raw shuffle uses descending exclusive bounds without a wrapper draw or extra seed', () => check(`
local list={'a','b','c','d'};local at=0
C.shuffle(list,function(bound) at=at+1;assert(bound==5-at);return 0 end)
assert(at==3 and table.concat(list,',')=='b,c,d,a')
for _,list in ipairs({{},{'a'}}) do C.shuffle(list,function() error('unnecessary draw') end) end
local R=dofile('tools/candidates/sts_random.lua')
local P=dofile('tools/candidates/libgdx_randomxs128.lua')
local s=R.restore({words={'0123456789abcdef','fedcba9876543210'},counter=17})
C.shuffle({'a','b'},function(bound) return P.nextInt(s.primitive,bound) end)
local after=R.snapshot(s)
assert(after.counter==17)
assert(after.words[1]=='fedcba9876543210' and after.words[2]=='4c3b73557711e6f7','independent BigInt raw recurrence vector')
`));

test('room selection honors row, parent and sibling restrictions, order and combat fallback', () => check(`
local function node(x,y,kind) return {x=x,y=y,type=kind,edges={},parents={}} end
local function choice(y,parentKind,siblingKind,pool)
 local p=node(0,y-1,parentKind);local n=node(0,y);local sibling=node(1,y,siblingKind)
 n.parents={p};p.edges={{dst_x=0,dst_y=y},{dst_x=1,dst_y=y}}
 local grid={};grid[y+1]={n,sibling}
 return C.selectRoom(grid,n,pool)
end
assert(choice(4,nil,nil,{'camp','elite','event'})==3,'early camp/elite')
assert(choice(5,nil,nil,{'camp','elite','event'})==1,'first permitted row')
assert(choice(13,nil,nil,{'camp','event'})==2,'late camp')
for _,kind in ipairs({'camp','shop','elite','treasure'}) do assert(choice(6,kind,nil,{kind,'event'})==2,'parent '..kind) end
for _,kind in ipairs({'camp','combat','event','elite','shop'}) do assert(choice(6,nil,kind,{kind,'treasure'})==2,'sibling '..kind) end
assert(choice(6,'combat',nil,{'combat'})==1 and choice(6,'event',nil,{'event'})==1,'combat/event parents permitted')
assert(choice(6,nil,'treasure',{'treasure'})==1,'treasure siblings permitted')
assert(choice(0,nil,'event',{'event'})==1,'row zero match override')
assert(choice(13,'shop',nil,{'camp','shop'})==nil,'no candidate rather than violating a restriction')
local root=node(0,0,'combat');local a=node(0,1);local b=node(1,1)
root.edges={{dst_x=0,dst_y=1},{dst_x=1,dst_y=1}};a.parents={root};b.parents={root}
a.edges={{dst_x=0,dst_y=2}};b.edges={{dst_x=1,dst_y=2}}
local grid={{root},{a,b}};local pool={'event','event'}
local fallback=C.assign(grid,pool)
assert(a.type=='event' and b.type=='combat' and fallback==1,'row-major siblings then fallback')
assert(#pool==1 and pool[1]=='event','failed candidates remain in pool')
`));
