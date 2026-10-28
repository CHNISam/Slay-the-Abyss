-- Public execution boundaries stay distinct after dispatch extraction.
local C=require('abyss_combat')
local Effects=require('abyss_effects')
local Data=require('abyss_data')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('ok core '..count..' - '..name)end
local function battle(enemies)return C.new(Data,{enemies=enemies or {'cultist'},deck={'strike'},seed=42})end
test('synchronous continuation rejection keeps its exact owner',function()
 local s=battle()
 for _,effect in ipairs({{op='scry',value=1},{op='handChoice',mode='exhaust',value=1},{op='calculatedGamble'}})do
  local ok,why=pcall(C.applyEffects,s,{effect},s.player,s.enemies[1])
  eq(ok,false);assert(tostring(why):find('requires the continuation queue',1,true))
  eq(s.actionQueue,nil);eq(s.resolvingEffects,nil)
 end
end)
test('queue extension false preserves its failure reason',function()
 local s=battle();local old=C.staticRetaliation
 C.staticRetaliation=function()return false,'core queue refusal'end
 local ok,why=pcall(C.resolvePotionActions,s,{{op='staticRetaliation'}})
 C.staticRetaliation=old
 eq(ok,false);assert(tostring(why):find('core queue refusal',1,true))
end)
test('queue extension nil is a handled completion',function()
 local s=battle();local old=C.staticRetaliation;local calls=0
 C.staticRetaliation=function()calls=calls+1 end
 local ok,why=pcall(C.resolvePotionActions,s,{{op='staticRetaliation'}})
 C.staticRetaliation=old
 assert(ok,why);eq(calls,1);eq(s.actionQueue,nil)
end)
test('target-first paired debuffs preserve Artifact consumption and event order',function()
 local s=battle({'cultist','cultist'});local a,b=s.enemies[1],s.enemies[2]
 C.addStatus(a,'artifact',1);C.addStatus(b,'artifact',2);s.events={}
 C.applyEffects(s,{{op='applyStatusAll',status='weak',value=1,targetGroup='weak_then_vulnerable'},
  {op='applyStatusAll',status='vulnerable',value=1,targetGroup='weak_then_vulnerable'}},s.player)
 eq(a.statuses.weak,nil);eq(a.statuses.vulnerable,1);eq(a.statuses.artifact,0)
 eq(b.statuses.weak,nil);eq(b.statuses.vulnerable,nil);eq(b.statuses.artifact,0)
 local targets={}
 for _,event in ipairs(s.events)do if event.kind=='status' or event.kind=='status_blocked'then targets[#targets+1]=event.detail.target end end
 eq(table.concat(targets,','),a.id..','..a.id..','..b.id..','..b.id)
end)
test('random ally Block consumes one draw even for one candidate',function()
 local s=battle({'centurion','mystic'});s.seed=42;s.aiRng=nil
 C.applyEffects(s,{{op='block',target='random_ally',value=15}},s.enemies[1],s.player)
 eq(s.seed,22539);eq(s.enemies[1].block,0);eq(s.enemies[2].block,15)
end)
test('later synchronous failure rolls back damage and live card ownership',function()
 local s=battle();local card=s.hand[1];local hand,draw,discard=s.hand,s.draw,s.discard
 local hp,energy,seed,events,nextUid=s.enemies[1].hp,s.energy,s.seed,#s.events,s.nextUid
 s.catalog.cards.strike.effects={{op='damage',value=6},{op='makeTempCardInDiscard',card='wound',value=6}}
 local ok,why=pcall(C.play,s,card.uid,1)
 eq(ok,false);assert(tostring(why):find('invalid temporary card count',1,true))
 eq(s.enemies[1].hp,hp);eq(s.energy,energy);eq(s.seed,seed);eq(#s.events,events);eq(s.nextUid,nextUid)
 eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard);eq(s.hand[1],card);eq(s.cardInUse,nil);eq(s.pendingPlay,nil)
end)
test('damage accumulation retains per-hit binary64 rounding across operations',function()
 local player,target={hp=100},{hp=100}
 local state={player=player,enemies={target}}
 local combat={outcome=function()end,damage=function(_,_,_,value)return value end}
 local dealt=Effects.apply(combat,state,{{op='damage',value=9007199254740992.0},
  {op='damage',value=1.0,times=2}},player,target)
 eq(dealt,9007199254740992.0)
end)
print('CORE_RESPONSIBILITIES_PASS '..count)
