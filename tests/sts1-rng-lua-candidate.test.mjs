import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, mkdtempSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
const fixture=JSON.parse(readFileSync(new URL('./fixtures/libgdx-rng-source-vectors.json',import.meta.url),'utf8'));
function check(body){assert.ok(existsSync('tools/candidates/libgdx_randomxs128.lua'),'RNG candidate must exist');const dir=mkdtempSync(join(tmpdir(),'rng-candidate-'));try{const f=join(dir,'case.lua');writeFileSync(f,`local R=dofile('tools/candidates/libgdx_randomxs128.lua')\nlocal function same(s,e) local got=R.snapshot(s); assert(got[1]==e[1] and got[2]==e[2], 'state differs') end\n${body}\nprint('rng passed')`);const r=runLua(f);assert.equal(r.status,0,r.stderr||r.stdout);assert.match(r.stdout,/rng passed/);}finally{rmSync(dir,{recursive:true,force:true});}}
test('full signed seed strings and raw transitions match fixed independent arithmetic vectors',()=>check(`for _,v in ipairs(${toLua(fixture.seeded)}) do local s=R.fromSeed(v.seed);same(s,v.case.state);for i,h in ipairs(v.case.raw) do assert(R.next64Hex(s)==h, 'raw '..i) end;same(s,v.case.after) end`));
test('raw state carry and high bit cases match fixed arithmetic vectors',()=>check(`for _,v in ipairs(${toLua(fixture.rawCases)}) do local s=R.restore(v.state);for i,h in ipairs(v.raw) do assert(R.next64Hex(s)==h,'raw case '..i) end;same(s,v.after) end`));
test('snapshot and restore do not alias, replay resumes exactly',()=>check(`local s=R.fromSeed('2780424839485660359'); for i=1,10 do R.next64Hex(s) end;local snap=R.snapshot(s);local copy=R.restore(snap);snap[1]='0000000000000000';for i=1,100 do assert(R.next64Hex(s)==R.next64Hex(copy)) end;local other=R.snapshot(copy);other[2]='0000000000000000';assert(R.next64Hex(s)==R.next64Hex(copy))`));

test('uint24 and float consume one raw draw with exact upper-bit mapping',()=>{
 const cases=fixture.seeded.map(v=>({seed:v.seed,values:v.case.raw.map(h=>Number(BigInt('0x'+h)>>40n)),after:v.case.after}));
 check(`for _,v in ipairs(${toLua(cases)}) do local s=R.fromSeed(v.seed);local f=R.fromSeed(v.seed);for _,n in ipairs(v.values) do assert(R.nextUint24(s)==n);assert(R.nextFloat(f)==n/16777216.0) end;same(s,v.after);same(f,v.after) end`);
});
test('bounded integer rejection advances actual state and matches fixed Java interpretation',()=>check(`for _,v in ipairs(${toLua(fixture.bounded)}) do local s=R.restore(v.state);for _,n in ipairs(v.values) do assert(R.nextInt(s,v.bound)==n,'bounded '..v.bound) end;same(s,v.after);local r=R.restore(v.state);for i=1,v.calls do R.next64Hex(r) end;same(r,v.after) end`));
test('invalid seeds, states and bounds reject without mutation',()=>check(`
 local function bad(f) assert(not pcall(f), 'must reject') end
 for _,v in ipairs({'','-0','00','01','+1',' 1','1 ','1.0','1e3','--1','-','9223372036854775808','-9223372036854775809',1,true,{}}) do bad(function() R.fromSeed(v) end) end
 bad(function() R.fromSeed(nil) end)
 for _,v in ipairs({{}, {'0','0000000000000000'}, {'0000000000000000','FFFFFFFFFFFFFFFF'}, {'0000000000000000','0000000000000000',3}, setmetatable({'0000000000000000','0000000000000000'},{})}) do bad(function() R.restore(v) end) end
 local s=R.fromSeed('1');local snap=R.snapshot(s)
 for _,n in ipairs({0,-1,1.5,2147483648,1/0,0/0,'1',true,{}}) do bad(function() R.nextInt(s,n) end);same(s,snap) end
 bad(function() R.nextInt(s,nil) end);same(s,snap)
 local malformed={a={0,0,0,65536},b={0,0,0,0}};bad(function() R.next64Hex(malformed) end);assert(malformed.a[4]==65536 and malformed.b[1]==0)
 local alias=R.restore(snap);alias.a[1]=alias.a[1]+1;same(s,snap)
`));
test('fixture includes full-width seeds and forced rejection rather than only small samples',()=>{
 assert.equal(fixture.seeded.length,10);assert.equal(fixture.rawCases.length,6);assert.equal(fixture.bounded.length,8);
 assert.ok(fixture.seeded.some(v=>v.seed==='2780424839485660359'));
 for(const v of fixture.seeded) assert.equal(v.case.raw.length,128);
 assert.ok(fixture.bounded.some(v=>v.calls>v.values.length));
});
test('uint24 high and low endpoints are reachable and each consumes exactly one draw',()=>check(`
 local zero=R.restore({'0000000000000000','0000000000000000'});assert(R.nextUint24(zero)==0)
 local start=${toLua(fixture.bounded[0].state)}
 local raw=R.restore(start);assert(R.next64Hex(raw)=='ffffffffffffffff')
 local s=R.restore(start);assert(R.nextUint24(s)==16777215);same(s,R.snapshot(raw))
 local f=R.restore(start);assert(R.nextFloat(f)==1-2.0^-24);same(f,R.snapshot(raw))
`));
