import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-combat-shuffle-vectors.json','utf8'));
test('shuffle vectors retain independent fixed-source interpretation and generator identity',()=>{
 const generator=readFileSync('tools/oracles/sts1_combat_shuffle.py','utf8').replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(generator).digest('hex'),vectors.generatorSha256);
 assert.equal(vectors.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(vectors.initial.length,35);assert.equal(vectors.redraw.length,63);
});

function runVectors(kind){
 const dir=mkdtempSync(join(tmpdir(),'abyss-shuffle-'));
 try{
  const path=join(dir,'vectors.lua');
  writeFileSync(path,`local C,R,Run=require('abyss_combat'),require('abyss_sts_random'),require('abyss_run')
local Data=require('abyss_data')
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path..' type')
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function ids(pile)local out={};for i,c in ipairs(pile)do out[i]=c.uid end;return out end
local function cards(numbers)local out={};for i,n in ipairs(numbers)do out[i]={uid=n,cardId='strike',upgraded=false}end;return out end
for _,v in ipairs(${toLua(vectors[kind])})do
 local run=Run.new(Data,v.seed);local streams=Run.roomStreams(run,v.floor)
 assert(streams.seed==v.roomSeed)
 local oldStreams=C.copy(streams);local trace={};local original,raw=R.shuffle,R.randomLongHex
 local lastRaw
 R.randomLongHex=function(s)local hex=raw(s);lastRaw=hex;return hex end
 R.shuffle=function(s,list)
  original(s,list);trace[#trace+1]={size=#list,cards=ids(list),rawHex=lastRaw,after=R.snapshot(s)}
 end
 local options={seed=101,deck={},enemies={'cultist'},roomSeed=streams.seed,roomStreams=streams}
 if v.size then
  for i=1,v.size do options.deck[i]='strike'end
  options.beforeOpeningDraw=function(s)same(ids(s.draw),v.beforeDraw,'initializeDeck copy/append order');return true end
 end
 local ok,battle=pcall(C.new,Data,options)
 if ok and v.input then
  battle.hand,battle.draw,battle.discard=cards(v.input.hand),cards(v.input.draw),cards(v.input.discard)
  battle.player.noDraw=v.input.noDraw
  ok,battle.error=pcall(C.draw,battle,v.input.amount)
 end
 R.shuffle,R.randomLongHex=original,raw
 assert(ok,battle.error or battle)
 same(ids(battle.hand),v.hand,'hand '..v.seed..' '..(v.name or tostring(v.size)))
 same(ids(battle.draw),v.draw,'draw order');same(ids(battle.discard),v.discard,'discard')
 same(R.snapshot(battle.shuffleRng),v.after,'shuffle state')
 same(trace,v.trace,'each shuffle call')
 same(streams,oldStreams,'caller-owned source streams are cloned')
 assert(battle.cardRandomRng.counter==0,'shuffle must not use cardRandomRng')
 assert(battle.seed==101,'formal shuffles must not spend legacy seed')
end
print('SOURCE_SHUFFLE_VECTORS_PASS ${kind} ${vectors[kind].length}')`);
  const result=runLua(path,{timeout:60000});assert.equal(result.status,0,result.stderr||result.stdout);
 }finally{rmSync(dir,{recursive:true,force:true});}
}
test('formal initial deck order, tail-first draw and room shuffle states match source vectors',()=>runVectors('initial'));
test('formal redraw splitting, empty shuffle calls and hand/no-draw guards match source vectors',()=>runVectors('redraw'));
test('formal shuffle ownership, continuation, initialization order and rollback',()=>{
 const result=runLua('tests/fixtures/js-owned/tests/lua/room_shuffle.lua');assert.equal(result.status,0,result.stderr||result.stdout);
});
