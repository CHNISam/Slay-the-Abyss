-- Explicit one-card native ABI/boss boundary; not a natural acquisition route.
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local r=Run.new(D,42);local uids={}
for _,c in ipairs(r.deck)do uids[#uids+1]=c.uid end
for _,uid in ipairs(uids)do assert(Run.removeCard(r,uid))end
assert(Run.obtainCard(r,'searing_blow',{upgrades=2}))
assert(Run.obtainRelic(r,'centennial_puzzle'));assert(Run.obtainRelic(r,'tungsten_rod'))
r.floor=D.rules.map.bossFloor;assert(Run.startCombat(r,'boss_guardian'));local s=r.combat
local function uid()eq(#s.hand,1);return s.hand[1].uid end
local played=uid();local definition=C.cardDefinition(s,s.hand[1]);eq(definition.runNativeABI,true);eq(definition.target,'ENEMY')
assert(Run.play(r,uid(),1));eq(s.enemies[1].hp,219)
assert(Run.endTurn(r));eq(s.enemies[1].block,9)
assert(Run.play(r,uid(),1));assert(Run.endTurn(r));eq(s.enemies[1].statuses.sharp_hide,3)
eq(#s.draw,0);eq(#s.discard,0);eq(s.relicCombat.centennialUsed,nil)
local shuffle=s.shuffleRng.counter;local hp=s.player.hp;assert(Run.play(r,uid(),1))
eq(s.player.hp,hp-2);eq(s.relicCombat.centennialUsed,true)
eq(#s.hand,0);eq(#s.draw,0);eq(#s.discard,1);eq(s.discard[1].uid,played)
eq(s.cardInUse,nil);eq(s.shuffleRng.counter,shuffle)
print('NATIVE_SHARP_HIDE_TOP_DRAW_PASS public source acquisition/boss setup; native ABI true; TOP draw before disposal')
