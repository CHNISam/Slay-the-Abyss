package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,R=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random')
local Data=C.copy(require('abyss_data'));local Text=require('abyss_potion_text')
Data.relics.relics[#Data.relics.relics+1]={id='SacredBark',name='Sacred Bark',rarity='boss',trigger='passive',effects={}}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(id,bark,character)
 local r=Run.new(Data,42,character and {character=character,experimental=true}or nil)
 if bark then r.relics[#r.relics+1]='SacredBark'end
 local ok,why=Run.obtainPotion(r,id);assert(ok,why)
 assert(Run.startCombat(r,'cultist_solo'));return r
end
for _,bark in ipairs({false,true})do
 local amount=bark and 4 or 2
 local r=fresh('focus_potion',bark,'defect');local s=r.combat
 A.applyPower(s,s.player,'artifact',1,s.player)
 assert(Run.usePotion(r,1,nil,function(candidate)eq(candidate.player.statuses.focus or 0,0)end))
 eq(r.combat,s);eq(s.player.statuses.focus,amount);eq(s.orbs.focus,amount);eq(s.player.statuses.artifact,1);eq(r.potions[1],nil)
 assert(Text.describe(r,'focus_potion'):find('集中+'..amount,1,true));print('ok Focus real Run '..amount..', BOT, Artifact and same battle owner')
 local n=fresh('focus_potion',bark,'defect');A.applyPower(n.combat,n.combat.player,'focus',-5,n.combat.player);A.applyPower(n.combat,n.combat.player,'artifact',1,n.combat.player)
 assert(Run.usePotion(n,1));eq(n.combat.player.statuses.focus,-5+amount);eq(n.combat.orbs.focus,-5+amount);eq(n.combat.player.statuses.artifact,1)
 for _,slots in ipairs({0,8,10})do
  local p=fresh('potion_of_capacity',bark,'defect');local battle=p.combat;battle.orbs.slots=slots;battle.orbs.balls={}
  assert(Run.usePotion(p,1,nil,function(candidate)eq(candidate.orbs.slots,slots)end));eq(p.combat,battle)
  eq(battle.orbs.slots,math.min(10,slots+amount));eq(#battle.orbs.balls,0)
 end
 local w=fresh('potion_of_capacity',bark,'watcher');eq(w.combat.orbs.slots,0);assert(Run.usePotion(w,1));eq(w.combat.orbs.slots,amount)
 local other=fresh('potion_of_capacity',bark);eq(other.combat.orbs.slots,0);eq(other.combat.orbs.focus,0);eq(#other.combat.orbs.balls,0)
 A.applyPower(other.combat,other.combat.player,'focus',2,other.combat.player)
 assert(Run.usePotion(other,1));eq(other.combat.orbs.slots,amount);eq(other.combat.orbs.focus,2)
 assert(Text.describe(w,'potion_of_capacity'):find('球槽+'..amount,1,true));assert(Text.describe(w,'potion_of_capacity'):find('10',1,true))
 print('ok Capacity '..amount..', 0/8/10 slots, empty slots and other-class zero-slot host')
end
for _,id in ipairs({'focus_potion','potion_of_capacity'})do
 local r=fresh(id,false,'defect');local s=r.combat;local potions=r.potions;local hp,energy,events=s.player.hp,s.energy,#s.events
 if id=='focus_potion'then s.catalog.statuses.focus.stack='none'else s.orbs.slots=-1 end
 local rng=R.snapshot(s.potionRng);local ok=Run.usePotion(r,1);eq(ok,false)
 eq(r.combat,s);eq(r.potions,potions);eq(r.potions[1],id);eq(s.player.hp,hp);eq(s.energy,energy);eq(#s.events,events);eq(R.snapshot(s.potionRng).counter,rng.counter)
 print('ok '..id..' failed real transaction preserves bottle, resources, RNG and original battle')
end
print('CLASS_POTION_FOCUS_CAPACITY_PASS')
