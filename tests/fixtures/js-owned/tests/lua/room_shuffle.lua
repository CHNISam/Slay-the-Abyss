local C,R,Run,AI=require('abyss_combat'),require('abyss_sts_random'),require('abyss_run'),require('abyss_enemy_ai')
local Data=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b),path)
 if type(a)~='table'then eq(a,b,path);return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok room shuffle '..count..' - '..name)end
local function battle(deck,seed,floor)
 local run=Run.new(Data,seed or '42');local streams=Run.roomStreams(run,floor or 1)
 return C.new(Data,{seed=101,deck=deck or {},enemies={'cultist'},roomSeed=streams.seed,roomStreams=streams}),streams
end
local function card(uid,id)return {uid=uid,cardId=id or 'strike',upgraded=false}end

test('empty and singleton initialization spend a single shuffle before zero requested opening draw',function()
 local data=C.copy(Data);data.rules.player.drawPerTurn=0
 for _,deck in ipairs({{}, {'strike'}})do
  local run=Run.new(data,'42');local streams=Run.roomStreams(run,1)
  local s=C.new(data,{seed=101,deck=deck,enemies={'cultist'},roomSeed=streams.seed,roomStreams=streams})
  eq(s.shuffleRng.counter,1);eq(s.seed,101);eq(#s.draw,#deck)
 end
end)

test('source shuffle sits between all opening AI initialization and enemy preBattle and before opening relic draw',function()
 local run=Run.new(Data,'42');local streams=Run.roomStreams(run,1);local order={}
 local initialize,preBattle,shuffle=AI.initialize,AI.preBattle,R.shuffle
 AI.initialize=function(...)order[#order+1]='init';return initialize(...)end
 AI.preBattle=function(...)order[#order+1]='preBattle';return preBattle(...)end
 R.shuffle=function(...)order[#order+1]='shuffle';return shuffle(...)end
 local ok,result=pcall(C.new,Data,{seed=101,deck=Data.cards.starter_deck.cards,enemies={'red_louse','green_louse'},
  roomSeed=streams.seed,roomStreams=streams,beforeOpeningDraw=function(s)
   order[#order+1]='opening';eq(#s.hand,0);eq(#s.draw,10);eq(s.shuffleRng.counter,1);return true
  end})
 AI.initialize,AI.preBattle,R.shuffle=initialize,preBattle,shuffle
 assert(ok,result);same(order,{'init','init','shuffle','preBattle','preBattle','opening'})
end)

test('consecutive redraws continue the same shuffle state and preserve other source streams',function()
 local s=battle({});local before={hp=R.snapshot(s.monsterHpRng),ai=R.snapshot(s.aiRng),card=R.snapshot(s.cardRandomRng),seed=s.seed}
 local expected=R.cloneState(s.shuffleRng)
 local a={card(1),card(2),card(3)};R.shuffle(expected,a)
 s.discard={card(1),card(2),card(3)};C.draw(s,3)
 for i=1,3 do eq(s.hand[i].uid,a[4-i].uid)end
 s.discard,s.hand=s.hand,{}
 local b=C.copy(s.discard);R.shuffle(expected,b);C.draw(s,3)
 for i=1,3 do eq(s.hand[i].uid,b[4-i].uid)end
 same(R.snapshot(s.shuffleRng),R.snapshot(expected))
 same(R.snapshot(s.monsterHpRng),before.hp);same(R.snapshot(s.aiRng),before.ai);same(R.snapshot(s.cardRandomRng),before.card);eq(s.seed,before.seed)
end)

test('draw failure after real shuffle restores original RNG tables, piles and card resolution',function()
 local s=battle({});s.hand={card(99,'shrug_it_off')};s.draw={};s.discard={card(1),card(2),card(3)}
 local old=C.copy(s);local rng,primitive=s.shuffleRng,s.shuffleRng.primitive
 local wordA,wordB=primitive.a,primitive.b
 local hand,draw,discard=s.hand,s.draw,s.discard
 local apply=C.applyEffects;local sentinel={failure='after-real-shuffle'}
 C.applyEffects=function(...)
  apply(...);error(sentinel)
 end
 local ok,reason=pcall(C.play,s,99)
 C.applyEffects=apply
 eq(ok,false);eq(reason,sentinel);same(s,old)
 eq(s.shuffleRng,rng);eq(s.shuffleRng.primitive,primitive);eq(s.shuffleRng.primitive.a,wordA);eq(s.shuffleRng.primitive.b,wordB)
 eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard)
 assert(C.play(s,99));eq(s.shuffleRng.counter,old.shuffleRng.counter+1)
end)

test('failed room creation after shuffle leaves original run and its caller stream untouched',function()
 local run=Run.new(Data,'42');local old=C.copy(run)
 local turn=C.startPlayerTurn
 C.startPlayerTurn=function()error('after-initial-shuffle')end
 local ok,reason=Run.startRoomCombat(run,'normal')
 C.startPlayerTurn=turn
 eq(ok,false);eq(reason,'combat_unavailable');same(run,old)
end)

test('explicit legacy fixture retains its LCG deck and has no source shuffle claim',function()
 local a=C.new(Data,{seed=42});local b=C.new(Data,{seed=42})
 eq(a.shuffleRng,nil);eq(a.roomSeed,nil);same(a,b)
 -- Captured by executing the unchanged 52a691c Combat with the same Data.
 eq(a.seed,13745);same((function()local ids={};for i,c in ipairs(a.hand)do ids[i]=c.uid end;return ids end)(),{2,9,8,7,4})
end)

print('ROOM_SHUFFLE_PASS '..count)
