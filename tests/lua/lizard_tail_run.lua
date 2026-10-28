-- Controlled damage/navigation verifies real Run ownership, not natural play.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A=require('abyss_run'),require('abyss_combat'),require('abyss_actor')
local Data=(...)or require('abyss_data')
local Tail=require('abyss_lizard_tail')
local n=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();n=n+1;print('PASS Tail Run '..n..' '..name)end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function fresh(hp)
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Lizard Tail'),'TAIL_PRODUCTION_OBTAIN_MISSING')
 eq(r.relicCounters.lizard_tail,-1);r.hp=hp or 1;return r
end
local function battle(relics,hp)
 local r=fresh(hp)
 for _,id in ipairs(relics or {})do assert(Run.obtainRelic(r,id))end
 assert(Run.startCombat(r,'cultist_solo'));return r
end
local function fatal(r,amount)local s=r.combat;return C.damage(s,s.enemies[1],s.player,amount or 999,true)end

test('actual acquire, odd integer half, once per run and binding never rearms spent',function()
 local r=battle();local s=r.combat;s.player.maxHp=81
 eq(fatal(r),1);eq(s.player.hp,40);eq(s.relicCounters.lizard_tail,-2);eq(Tail.state(s),'spent')
 fatal(r);eq(s.player.hp,0);eq(s.relicCounters.lizard_tail,-2)
 local Hooks=require('abyss_relic_hooks');local other={}
 Hooks.bindBattle(other,s.relics,s.relicCounters);eq(other.relicCounters.lizard_tail,-2)
 local old=r.relicCounters;eq(Run.obtainRelic(r,'lizard_tail'),false);eq(r.relicCounters,old)
end)
test('leftmost Fairy wins twice before Tail and Mark blocks every reserve',function()
 local r=battle();local s=r.combat
 s.potionInventory[1]='fairy_in_a_bottle';s.potionInventory[2]='fairy_in_a_bottle'
 fatal(r);eq(s.player.hp,24);eq(s.relicCounters.lizard_tail,-1);eq(s.potionInventory[1],nil)
 fatal(r);eq(s.player.hp,24);eq(s.relicCounters.lizard_tail,-1);eq(s.potionInventory[2],nil)
 fatal(r);eq(s.player.hp,40);eq(s.relicCounters.lizard_tail,-2)
 r=battle({'Mark of the Bloom'});s=r.combat;s.potionInventory[1]='fairy_in_a_bottle'
 fatal(r);eq(s.player.hp,0);eq(s.relicCounters.lizard_tail,-1);eq(s.potionInventory[1],'fairy_in_a_bottle')
end)
test('ordinary combat healing modifiers, no Bark doubling, no potion-use hook',function()
 local r=battle({'Toy Ornithopter'});local s=r.combat
 -- Magic Flower/Bark are existing health-contract identities; only Tail is newly obtained.
 s.relics[#s.relics+1]='magic_flower';s.relics[#s.relics+1]='sacred_bark';s.player.maxHp=83
 fatal(r);eq(s.player.hp,62);eq(s.relicCounters.lizard_tail,-2)
 for _,e in ipairs(s.events)do assert(e.kind~='potion_revive')end
end)
test('Red Skull observes fatal bloodied before revival healing and retains source Artifact interaction',function()
 local r=battle({'Red Skull'},80);local s=r.combat
 s.relics[#s.relics+1]='magic_flower';s.player.statuses.artifact=1
 fatal(r);eq(s.player.hp,60);eq(s.relicCounters.lizard_tail,-2)
 eq(s.player.statuses.artifact,0);eq(s.player.statuses.strength,3);eq(s.relicCombat.redSkullActive,false)
end)
test('card HP loss and direct status damage revive; arbitrary zeroing is not fatal damage',function()
 local r=battle();local s=r.combat
 A.loseHp(s,s.player,99999);eq(s.player.hp,40);eq(s.relicCounters.lizard_tail,-2)
 r=battle();s=r.combat;s.player.hp=0;A.hpLostFromDamage(s,s.player,0)
 eq(s.player.hp,0);eq(s.relicCounters.lizard_tail,-1)
end)
test('outside damage uses Run owner, survives retained combat, preserves spent across next battle',function()
 local r=fresh();r.phase='node'
 r.combat={player={hp=0,maxHp=999,statuses={}},relics={'mark_of_bloom'},relicCounters={lizard_tail=-1}}
 local old=C.copy(r.combat);assert(Run.eventNormalDamage(r,5));eq(r.hp,40);eq(r.relicCounters.lizard_tail,-2);same(r.combat,old)
 r.combat=nil;r.phase='map';assert(Run.startCombat(r,'cultist_solo'))
 eq(r.combat.relicCounters.lizard_tail,-2);fatal(r);eq(r.combat.player.hp,0)
end)
test('outside Fairy first, no combat Flower, and failure rolls back all live owners',function()
 local r=fresh();r.phase='node';assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 r.relics[#r.relics+1]='magic_flower'
 assert(Run.eventDamage(r,5));eq(r.hp,24);eq(r.relicCounters.lizard_tail,-1);eq(r.potions[1],nil)
 r.hp=1;local before=C.copy(r,{[r.data]=r.data});local counters,potions=r.relicCounters,r.potions
 local heal=Run.heal;Run.heal=function(staged,value)heal(staged,value);error('TAIL_LATE_HEAL')end
 local ok,why=Run.eventDamage(r,5);Run.heal=heal
 eq(ok,false);eq(why,'transaction_failed');same(r,before);eq(r.relicCounters,counters);eq(r.potions,potions)
 assert(Run.eventDamage(r,5));eq(r.hp,40);eq(r.relicCounters.lizard_tail,-2)
end)
test('obtained during combat initializes that live counter and a failed command cannot consume it',function()
 local r=Run.new(Data,42);assert(Run.startCombat(r,'cultist_solo'));assert(Run.obtainRelic(r,'lizard_tail'))
 eq(r.combat.relicCounters.lizard_tail,-1);assert(Tail.has(r.combat))
 local s=r.combat;local before=C.copy(r,{[r.data]=r.data});eq(Run.play(r,-1,1),false);eq(r.combat,s);same(r,before)
 s.player.hp=1;fatal(r);eq(s.player.hp,40);eq(s.relicCounters.lizard_tail,-2)
end)
print('LIZARD_TAIL_RUN_PASS '..n..' groups; controlled/offline only')
