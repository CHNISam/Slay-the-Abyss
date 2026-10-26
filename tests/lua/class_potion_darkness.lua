package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,R=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random')
local D=C.copy(require('abyss_data'));local Text=require('abyss_potion_text')
D.relics.relics[#D.relics.relics+1]={id='SacredBark',name='Sacred Bark',rarity='boss',trigger='passive',effects={}}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(bark,character)
 local options;if character~=false then options={character=character or 'defect',experimental=true}end
 local r=Run.new(D,42,options)
 if bark then r.relics[#r.relics+1]='SacredBark'end
 local ok,why=Run.obtainPotion(r,'essence_of_darkness');assert(ok,why)
 assert(Run.startCombat(r,'cultist_solo'));return r
end
for _,bark in ipairs({false,true})do
 local r=fresh(bark);local s=r.combat;local enemy=s.enemies[1];local hp=enemy.hp
 local rng=s.cardRandomRng.counter;local history=s.orbChannelCounts.dark;local amount=bark and 2 or 1
 A.applyPower(s,s.player,'focus',2,s.player)
 assert(Run.usePotion(r,1,nil,function(candidate)eq(#candidate.orbs.balls,1);eq(candidate.orbChannelCounts.dark,history)end))
 eq(r.combat,s);eq(s.orbs.slots,3);eq(#s.orbs.balls,3);eq(s.orbChannelCounts.dark-history,3*amount)
 for _,ball in ipairs(s.orbs.balls)do eq(ball.kind,'dark');eq(ball.stored,6)end
 eq(s.enemies[1].hp,hp-10-(bark and 18 or 0));eq(s.cardRandomRng.counter,rng+1);eq(s.orbs.focus,2)
 assert(Text.describe(r,'essence_of_darkness'):find('每个球槽'..amount..'颗',1,true))
 print('ok real Darkness potency '..amount..', total slots, Focus, channel history, Dark base6 and lightning RNG')
 local empty=fresh(bark);local b=empty.combat;b.orbs.balls={};local before=b.enemies[1].hp;local counter=b.cardRandomRng.counter
 assert(Run.usePotion(empty,1));eq(b.enemies[1].hp,before-(bark and 18 or 0));eq(b.cardRandomRng.counter,counter)
 eq(b.orbChannelCounts.dark,3*amount);eq(#b.orbs.balls,3)
end
for _,character in ipairs({'watcher',false})do
 local r=fresh(false,character);local s=r.combat
 if character then eq(s.orbs.slots,0)else eq(s.orbs,nil)end
 local hp=s.enemies[1].hp;assert(Run.usePotion(r,1));eq(s.orbs.slots,0);eq(#s.orbs.balls,0);eq(s.enemies[1].hp,hp);eq(s.orbChannelCounts.dark,0)
 print('ok actual '..tostring(character)..' zero-slot host, successful empty effect without fake Defect profile')
end
local later=fresh(false);local s=later.combat
assert(Run.usePotion(later,1,nil,function(candidate)
 require('abyss_card_actions').enqueue(candidate,{op='gainOrbSlots',value=1},nil,nil,nil,true)
end))
eq(s.orbs.slots,4);eq(#s.orbs.balls,4);eq(s.orbChannelCounts.dark,4)
print('ok slot count captured at action execution after a real earlier TOP slot gain')
print('CLASS_POTION_DARKNESS_PASS')
