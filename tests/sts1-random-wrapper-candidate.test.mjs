import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, mkdtempSync, writeFileSync, rmSync, existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
const fixture=JSON.parse(readFileSync(new URL('./fixtures/sts-random-wrapper-source-vectors.json',import.meta.url),'utf8'));
function check(body){
 assert.ok(existsSync('tools/candidates/sts_random.lua'),'wrapper candidate must exist');
 const dir=mkdtempSync(join(tmpdir(),'sts-wrapper-'));
 try{
  const f=join(dir,'case.lua');
  writeFileSync(f,`local R=dofile('tools/candidates/sts_random.lua')
local P=dofile('tools/candidates/libgdx_randomxs128.lua')
local function same(s,e) local x=R.snapshot(s);assert(x.counter==e.counter,'counter');assert(x.words[1]==e.words[1] and x.words[2]==e.words[2],'words') end
local function bad(f) assert(not pcall(f),'must reject') end
${body}
print('wrapper passed')`);
  const r=runLua(f);assert.equal(r.status,0,r.stderr||r.stdout);assert.match(r.stdout,/wrapper passed/);
 }finally{rmSync(dir,{recursive:true,force:true});}
}
test('mixed public calls match fixed independent vectors and every post-state',()=>check(`
local methods={int=R.randomInt,between=R.randomIntBetween,boolean=R.randomBoolean,chance=R.randomBooleanChance,float=R.randomFloat}
for _,v in ipairs(${toLua(fixture.traces)}) do local s=R.fromSeed(v.seed);same(s,v.initial)
 for _,row in ipairs(v.rows) do assert(methods[row.kind](s,table.unpack(row.args))==row.value,row.kind);same(s,row.after) end
end`));
test('sixteen public integer calls consume seventeen forced rejection raw draws',()=>check(`
local v=${toLua(fixture.forced)};local s=R.restore(v.initial)
for i,n in ipairs(v.values) do assert(R.randomInt(s,2)==n);assert(R.snapshot(s).counter==i) end
same(s,v.after);assert(v.rawDraws==17 and v.after.counter==16)
local p=P.restore(v.initial.words);for i=1,17 do P.next64Hex(p) end;local w=P.snapshot(p)
assert(w[1]==v.after.words[1] and w[2]==v.after.words[2])`));
test('noarg Boolean uses low bit, float uses high bits, chance comparison is strict at equality',()=>check(`
for _,v in ipairs(${toLua(fixture.rawCases)}) do
 local b=R.restore(v.initial);assert(R.randomBoolean(b)==v.boolean);same(b,{words=v.afterWords,counter=1})
 local f=R.restore(v.initial);assert(R.randomFloat(f)==v.float);same(f,{words=v.afterWords,counter=1})
 local c=R.restore(v.initial);assert(R.randomBooleanChance(c,v.float)==false);same(c,{words=v.afterWords,counter=1})
 local z=R.restore(v.initial);assert(R.randomBooleanChance(z,0)==false)
 local o=R.restore(v.initial);assert(R.randomBooleanChance(o,1)==true)
end`));
test('probability ABI accepts exact binary32 only, including subnormal grid and Jaw constants',()=>check(`
for _,p in ipairs({0,1,2.0^-149,2.0^-126,0.5625,0.35699999332427978515625,0.41600000858306884765625,1-2.0^-24}) do local s=R.fromSeed('1');R.randomBooleanChance(s,p);assert(s.counter==1) end
local s=R.fromSeed('1');local before=R.snapshot(s)
for _,p in ipairs({-1,2,0.357,0.416,2.0^-150,2.0^-126+2.0^-150,0/0,1/0,'0.5',true,{}}) do bad(function() R.randomBooleanChance(s,p) end);same(s,before) end
bad(function() R.randomBooleanChance(s,nil) end);same(s,before)`));
test('integer source failures increment counter before throw, unsupported ABI/span never do',()=>check(`
local s=R.fromSeed('1');local before=R.snapshot(s)
for _,n in ipairs({-1,-2,-2147483648}) do bad(function() R.randomInt(s,n) end);before.counter=before.counter+1;same(s,before) end
for _,v in ipairs({{2,1},{2,0},{0,-2147483648}}) do bad(function() R.randomIntBetween(s,v[1],v[2]) end);before.counter=before.counter+1;same(s,before) end
for _,n in ipairs({2147483647,2147483648,-2147483649,0.5,1/0,0/0,'1',true,{}}) do bad(function() R.randomInt(s,n) end);same(s,before) end
bad(function() R.randomInt(s,nil) end);same(s,before)
for _,v in ipairs({{-2147483648,2147483647},{0,2147483647},{2147483647,-2147483648},{1,'2'}}) do bad(function() R.randomIntBetween(s,v[1],v[2]) end);same(s,before) end
local z=R.restore({words={'0000000000000000','0000000000000000'},counter=0})
assert(R.randomInt(z,0)==0);assert(R.randomIntBetween(z,-2147483648,-2147483648)==-2147483648);assert(R.randomIntBetween(z,2147483647,2147483647)==2147483647);assert(z.counter==3)`));
test('signed32 counter wraps in O(1) for successful draws and source bound failures',()=>check(`
for _,draw in ipairs({function(s)R.randomInt(s,0)end,function(s)R.randomIntBetween(s,1,1)end,R.randomBoolean,function(s)R.randomBooleanChance(s,0.5)end,R.randomFloat}) do
 local s=R.restore({words={'0000000000000000','0000000000000000'},counter=2147483647});draw(s);assert(s.counter==-2147483648);draw(s);assert(s.counter==-2147483647)
end
local s=R.restore({words={'0000000000000000','0000000000000000'},counter=2147483647});bad(function()R.randomInt(s,-1)end);assert(s.counter==-2147483648)`));
test('snapshot restore and cloneState isolate all nested state and resume exactly',()=>check(`
local s=R.fromSeed('2780424839485660359');for i=1,9 do R.randomInt(s,99) end
local snap=R.snapshot(s);local c=R.cloneState(s);local r=R.restore(snap);snap.words[1]='0000000000000000';snap.counter=-1
for i=1,30 do assert(R.randomFloat(s)==R.randomFloat(c));assert(R.randomBoolean(s)==R.randomBoolean(c));R.randomFloat(r);R.randomBoolean(r);same(s,R.snapshot(r));same(c,R.snapshot(s)) end
local expected=R.snapshot(s);c.primitive.a[1]=(c.primitive.a[1]+1)%65536;c.counter=0;same(s,expected)
local snap2=R.snapshot(s);snap2.words[2]='0000000000000000';same(s,expected)`));
test('malformed snapshot and live state reject before mutation without invoking metamethods',()=>check(`
local invoked=false;local mt={__index=function() invoked=true;error('metamethod') end,__pairs=function()invoked=true;error('metamethod')end}
for _,x in ipairs({{}, {words={'0','0000000000000000'},counter=0},{words={'0000000000000000','0000000000000000'},counter=2147483648},{words={'0000000000000000','0000000000000000'},counter=0.5},{words={'0000000000000000','0000000000000000'},counter=0,extra=true},setmetatable({},mt),{words=setmetatable({},mt),counter=0}}) do bad(function()R.restore(x)end) end
for _,method in ipairs({function(s)R.randomInt(s,2)end,function(s)R.randomIntBetween(s,0,2)end,R.randomBoolean,function(s)R.randomBooleanChance(s,0.5)end,R.randomFloat,R.snapshot,R.cloneState}) do
 local s=R.fromSeed('1');s.primitive.a[1]=65536;bad(function()method(s)end);assert(s.counter==0 and s.primitive.a[1]==65536)
 local t=setmetatable({},mt);bad(function()method(t)end)
end
assert(not invoked)
for _,x in ipairs({'-0','01','+1','9223372036854775808',1,{}}) do bad(function()R.fromSeed(x)end) end
assert(R.setCounter==nil and R.randomLong==nil and R.copy==nil and R.random==nil)`));
test('fixture preserves generator and source pins, forces rare cases and full-width seeds',()=>{
 assert.equal(createHash('sha256').update(fixture.generatorPython).digest('hex'),fixture.generatorSha256);
 assert.equal(fixture.stsCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(fixture.libgdxCommit,'3b1fda1fc2e1f6b3c74851471870062d871ed16f');
 assert.equal(fixture.traces.length,6);for(const t of fixture.traces)assert.equal(t.rows.length,80);
 assert.equal(fixture.forced.rawDraws,17);assert.equal(fixture.forced.values.length,16);
 assert.ok(fixture.rawCases.some(v=>v.boolean!==(v.float<0.5)));
});
test('extra arguments cannot silently request omitted overloads or replay construction',()=>check(`
local s=R.fromSeed('1');local before=R.snapshot(s)
bad(function()R.fromSeed('1',5)end)
for _,f in ipairs({function()R.randomFloat(s,10)end,function()R.randomBoolean(s,0.5)end,function()R.randomInt(s,0,2)end,function()R.randomIntBetween(s,0,2,3)end,function()R.randomBooleanChance(s,0.5,true)end}) do bad(f);same(s,before) end`));
