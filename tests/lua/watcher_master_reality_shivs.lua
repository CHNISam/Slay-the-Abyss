package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,Silent,Shivs=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_silent'),require('abyss_shivs')
local d=P.prepare(D,'watcher');local silent=P.prepare(D,'silent');local cards,statuses={},{}
for _,c in ipairs(d.cards.cards)do cards[c.id]=true end;for _,s in ipairs(d.statuses.statuses)do statuses[s.id]=true end
for _,c in ipairs(silent.cards.cards)do if not cards[c.id]then d.cards.cards[#d.cards.cards+1]=C.copy(c)end end
for _,s in ipairs(silent.statuses.statuses)do if not statuses[s.id]then d.statuses.statuses[#d.statuses.statuses+1]=C.copy(s)end end
local function battle()
 local s=C.new(d,{seed=1,enableStances=true,deck={'master_reality'},enemies={'cultist'}});assert(C.play(s,s.hand[1].uid));Shivs.applyAccuracy(s,4);return s
end
for _,up in ipairs({false,true})do
 local s=battle();local ids=Silent.generateShivs(s,11,up);assert(#ids==11 and #s.hand==10 and #s.discard==1)
 local seen={};for _,pile in ipairs({s.hand,s.discard})do for _,c in ipairs(pile)do
  assert(c.upgraded and (c.upgrades or 1)==1 and not seen[c.uid]);seen[c.uid]=true
  assert(c.shivAccuracyBonus==4 and C.cardDefinition(s,c).effects[1].value==10)
 end end
end
local s=battle();Shivs.applyInfiniteBlades(s,1)
assert(Shivs.startTurn(s,Silent.generateShivs));assert(s.hand[1].upgraded and s.hand[1].shivAccuracyBonus==4)
print('WATCHER_MASTER_REALITY_SHIVS both input versions, Accuracy, overflow, identity and Infinite Blades passed')
