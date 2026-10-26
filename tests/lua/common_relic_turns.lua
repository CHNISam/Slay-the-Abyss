package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H,C,I,S=require('abyss_relic_hooks'),require('abyss_combat'),require('abyss_inventory'),require('abyss_sts_random')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function battle(ids,counters)
 local opening=assert(I.opening(data.relics.relics,ids,counters))
 local s=assert(C.new(data,{seed=42,deck={'strike','defend','defend','defend','defend','defend','defend'},enemies={'cultist'},
  beforeOpeningDraw=function(s)return I.applyOpening(s,opening.beforeDraw)end}))
 assert(I.applyOpening(s,opening.afterDraw));return s
end
test('HappyFlower grants one energy on every third player turn and persists its counter',function()
 local s=battle({'happy_flower'},{happy_flower=0});assert(s.energy==3 and s.relicCounters.happy_flower==1)
 assert(C.endTurn(s));assert(s.energy==3 and s.relicCounters.happy_flower==2)
 assert(C.endTurn(s));assert(s.energy==4 and s.relicCounters.happy_flower==0)
 local nextBattle=battle({'happy_flower'},{happy_flower=2});assert(nextBattle.energy==4 and nextBattle.relicCounters.happy_flower==0)
end)
test('HappyFlower original legacy minus-one counter advances to one',function()
 local s=battle({'happy_flower'},{happy_flower=-1});assert(s.energy==3 and s.relicCounters.happy_flower==1)
end)
test('AncientTeaSet arms entering camp regardless selected action then grants two on next battle first turn only',function()
 local r={relics={'ancient_tea_set'},relicCounters={ancient_tea_set=-1},gold=0,hp=40,maxHp=80}
 H.onEnterRoom(r,'camp');assert(r.relicCounters.ancient_tea_set==-2)
 local s=battle(r.relics,r.relicCounters);assert(s.energy==5 and s.relicCounters.ancient_tea_set==-1)
 assert(r.relicCounters.ancient_tea_set==-2,'uncommitted battle escaped into run counter')
 assert(C.endTurn(s));assert(s.energy==3)
 local nextBattle=battle(r.relics,s.relicCounters);assert(nextBattle.energy==3)
end)
test('ArtOfWar skips first-turn bonus and tracks attacks even after they leave hand',function()
 local s=battle({'art_of_war'});assert(s.energy==3)
 assert(C.endTurn(s));assert(s.energy==4)
 local uid
 for _,card in ipairs(s.hand)do if card.cardId=='strike' then uid=card.uid end end
 if not uid then C.draw(s,10);for _,card in ipairs(s.hand)do if card.cardId=='strike'then uid=card.uid end end end
 assert(uid);assert(C.play(s,uid,1));assert(C.endTurn(s));assert(s.energy==3)
 assert(C.endTurn(s));assert(s.energy==4)
end)
test('a failed attack restores ArtOfWar eligibility and retained counter objects',function()
 local s=battle({'art_of_war'});local uid
 for _,card in ipairs(s.hand)do if card.cardId=='strike'then uid=card.uid end end
 if not uid then C.draw(s,10);for _,card in ipairs(s.hand)do if card.cardId=='strike'then uid=card.uid end end end
 local original=s.relicCombat;local damage=C.damage
 C.damage=function()error('POST_ATTACK_HOOK_FAILURE')end
 local ok=pcall(C.play,s,uid,1);C.damage=damage
 assert(not ok);assert(s.relicCombat==original and not original.attackPlayed)
end)
print('LUA_COMMON_RELIC_TURNS_PASS '..n)
