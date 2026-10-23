import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';

test('production event RNG retains candidate mixed-call vectors and Java48 shuffle',()=>{
  const traces=JSON.parse(readFileSync('tests/fixtures/sts-random-wrapper-source-vectors.json','utf8')).traces;
  const seeded=JSON.parse(readFileSync('tests/fixtures/libgdx-rng-source-vectors.json','utf8')).seeded;
  const shuffles=[];
  // Independent BigInt reference for java.util.Random.nextInt/Collections.shuffle.
  for(const {seed,case:v} of seeded) for(const size of [1,2,3,10,37]){
    const multiplier=0x5deece66dn,mask=(1n<<48n)-1n;
    let state=(BigInt(`0x${v.raw[0]}`)^multiplier)&mask;
    function bits(){state=(state*multiplier+11n)&mask;return state>>17n;}
    function next(bound){
      const b=BigInt(bound);
      if((b&(b-1n))===0n) return Number((b*bits())>>31n);
      for(;;){const r=bits(),n=r%b;if(r-n+b-1n<1n<<31n)return Number(n);}
    }
    const result=Array.from({length:size},(_,i)=>i+1);
    for(let i=size;i>1;i--){const j=next(i);[result[i-1],result[j]]=[result[j],result[i-1]];}
    shuffles.push({seed,size,result});
  }
  mkdirSync('build/lua',{recursive:true});
  const path='build/lua/event-random-test.lua';
  writeFileSync(path,`local R=require('abyss_sts_random')
local methods={int=R.randomInt,between=R.randomIntBetween,boolean=R.randomBoolean,chance=R.randomBooleanChance,float=R.randomFloat}
for _,v in ipairs(${toLua(traces)}) do
 local s=R.fromSeed(v.seed)
 for _,row in ipairs(v.rows) do
  assert(methods[row.kind](s,table.unpack(row.args))==row.value,row.kind)
  local after=R.snapshot(s)
  assert(after.counter==row.after.counter and after.words[1]==row.after.words[1] and after.words[2]==row.after.words[2])
 end
end
for _,v in ipairs(${toLua(shuffles)}) do
 local s=R.fromSeed(v.seed);local list={};for i=1,v.size do list[i]=i end
 R.shuffle(s,list);assert(s.counter==1,'one miscRng.randomLong per shuffle')
 for i,n in ipairs(v.result) do assert(list[i]==n,'Java48 shuffle '..v.seed..' size '..v.size..' index '..i) end
 local restored=R.restore(R.snapshot(s));assert(R.randomFloat(s)==R.randomFloat(restored))
end
print('EVENT_RNG_PASS')`);
  const result=runLua(path);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/EVENT_RNG_PASS/);
});
