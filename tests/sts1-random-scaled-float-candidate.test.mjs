import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';

const fixture=JSON.parse(readFileSync(new URL('./fixtures/sts-random-scaled-float-vectors.json',import.meta.url),'utf8'));
const luaNumber=n=>Object.is(n,-0)?'-0.0':toLua(n);
function check(body){
 const dir=mkdtempSync(join(tmpdir(),'sts-scaled-float-'));
 try{
  const file=join(dir,'case.lua');
  writeFileSync(file,`local R=dofile('tools/candidates/sts_random.lua')
assert(type(R.randomFloatRange)=='function' and type(R.randomFloatBetween)=='function','scaled float ABI is missing')
local function same(s,expected)
 local actual=R.snapshot(s);assert(actual.counter==expected.counter,'counter differs')
 assert(actual.words[1]==expected.words[1] and actual.words[2]==expected.words[2],'raw state differs')
end
local function bad(fn) assert(not pcall(fn),'must reject before mutation') end
${body}
print('scaled float passed')`);
  const result=runLua(file);
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/scaled float passed/);
 }finally{rmSync(dir,{recursive:true,force:true});}
}

for(const kind of ['range','between']){
 test(`${kind} matches independent Java strict float vectors including signed zero and underflow`,()=>{
  const rows=fixture.rows.filter(row=>row.kind===kind);
  const cases=fixture.rawCases.map(v=>{
   const sample=Number(BigInt(`0x${v.raw}`)>>40n);
   return `{initial=${toLua(v.initial)},after={words=${toLua(v.afterWords)},counter=1},rows={${rows.filter(row=>row.sample===sample).map(row=>`{left=${luaNumber(row.left)},right=${luaNumber(row.right)},value=${luaNumber(row.value)},negativeZero=${row.negativeZero}}`).join(',')}}}`;
  }).join(',');
  const call=kind==='range'?'R.randomFloatRange(s,row.left)':'R.randomFloatBetween(s,row.left,row.right)';
  check(`for _,v in ipairs({${cases}}) do for _,row in ipairs(v.rows) do
 local s=R.restore(v.initial);local got=${call}
 assert(got==row.value,'numeric float result differs: '..tostring(got)..' / '..tostring(row.value))
 if got==0 then assert((1/got==-math.huge)==row.negativeZero,'zero sign differs') end
 same(s,v.after)
end end`);
 });
}

test('finite exact-binary32 ABI rejects unsupported arguments atomically',()=>check(`
local s=R.fromSeed('1');local before=R.snapshot(s)
for _,n in ipairs({0.9,1.1,-0.9,2.0^-150,2.0^-126+2.0^-150,2.0^128,1/0,-1/0,0/0,'1',true,{}}) do
 bad(function()R.randomFloatRange(s,n)end);same(s,before)
 bad(function()R.randomFloatBetween(s,n,1)end);same(s,before)
 bad(function()R.randomFloatBetween(s,1,n)end);same(s,before)
end
for _,f in ipairs({function()R.randomFloatRange(s,nil)end,function()R.randomFloatBetween(s,1,nil)end,
 function()R.randomFloatRange(s,1,nil)end,function()R.randomFloatBetween(s,0,1,nil)end}) do bad(f);same(s,before) end
local maximum=(2-2.0^-23)*2.0^127
bad(function()R.randomFloatBetween(s,-maximum,maximum)end);same(s,before)
bad(function()R.randomFloatBetween(s,maximum,-maximum)end);same(s,before)
`));

test('each scaled draw advances counter exactly once including zero equal and reversed bounds and wrap',()=>check(`
local methods={function(s)return R.randomFloatRange(s,0)end,function(s)return R.randomFloatRange(s,-1)end,
 function(s)return R.randomFloatBetween(s,1,1)end,function(s)return R.randomFloatBetween(s,1,-1)end}
for _,draw in ipairs(methods) do
 local s=R.fromSeed('2780424839485660359');local p=R.cloneState(s);R.randomFloat(p);draw(s);same(s,R.snapshot(p))
 local wrap=R.restore({words={'0000000000000000','0000000000000000'},counter=2147483647})
 draw(wrap);assert(wrap.counter==-2147483648);draw(wrap);assert(wrap.counter==-2147483647)
end
`));

test('bad nested states and metatables reject before counting without invoking input metamethods',()=>check(`
local invoked=false;local mt={__index=function()invoked=true;error('metamethod')end,__pairs=function()invoked=true;error('metamethod')end}
for _,draw in ipairs({function(s)R.randomFloatRange(s,1)end,function(s)R.randomFloatBetween(s,0,1)end}) do
 local s=R.fromSeed('1');s.primitive.a[1]=65536;bad(function()draw(s)end);assert(s.counter==0 and s.primitive.a[1]==65536)
 bad(function()draw(setmetatable({},mt))end)
end
assert(not invoked)
`));

test('rounded ranges can reach the supplied endpoint even when raw float excludes one',()=>check(`
local v=${toLua(fixture.rawCases.find(v=>v.raw==='ffffffffffffffff'))}
local s=R.restore(v.initial)
assert(R.randomFloatBetween(s,1,1+2.0^-23)==1+2.0^-23,'rounding can include upper endpoint')
same(s,{words=v.afterWords,counter=1})
`));

test('fixed vectors preserve independent generator, source pins and discriminating float cases',()=>{
 assert.equal(createHash('sha256').update(fixture.generatorJava).digest('hex'),fixture.generatorSha256);
 assert.equal(fixture.stsCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(fixture.libgdxCommit,'3b1fda1fc2e1f6b3c74851471870062d871ed16f');
 assert.equal(fixture.rows.length,132);
 assert.ok(fixture.rows.some(row=>row.negativeZero));
 assert.ok(fixture.rows.some(row=>row.resultBits==='00000002'));
 assert.ok(fixture.rows.some(row=>row.kind==='between'&&row.left>row.right));
});
