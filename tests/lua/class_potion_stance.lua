package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,R=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random')
local D=C.copy(require('abyss_data'))
D.relics.relics[#D.relics.relics+1]={id='SacredBark',name='Sacred Bark',rarity='boss',trigger='passive',effects={}}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(bark)
 local r=Run.new(D,42,{character='watcher',experimental=true});r.relics[#r.relics+1]='toy_ornithopter'
 if bark then r.relics[#r.relics+1]='SacredBark'end
 local ok,why=Run.obtainPotion(r,'stance_potion');assert(ok,why)
 assert(Run.obtainPotion(r,'block_potion'));assert(Run.startCombat(r,'cultist_solo'))
 r.hp=r.hp-20;r.combat.player.hp=r.hp;return r
end
for _,bark in ipairs({false,true})do for _,stance in ipairs({'Wrath','Calm'})do
 local r=fresh(bark);local s=r.combat;local hp,energy,uid,master=s.player.hp,s.energy,s.nextUid,#r.deck
 A.applyPower(s,s.player,'artifact',1,s.player);A.applyPower(s,s.player,'master_reality',1,s.player)
 assert(Run.usePotion(r,1));eq(r.combat,s);eq(r.potions[1],nil);eq(s.player.hp,hp);eq(s.energy,energy);eq(s.nextUid,uid)
 local p=s.pendingPotionChoice;assert(p);eq(p.options[1].id,'Wrath');eq(p.options[2].id,'Calm');eq(p.mode,'stance');eq(p.count,1)
 eq(s.pendingPlay,nil);eq(s.cardInUse,nil);eq(s.actionQueue.paused,true)
 eq(Run.play(r,s.hand[1].uid,1),false);eq(Run.endTurn(r),false);eq(Run.usePotion(r,2),false);eq(Run.discardPotion(r,2),false)
 eq(Run.choosePotionStance(r,{},p.token,r.combatGeneration,s),false)
 eq(Run.choosePotionStance(r,{'Neutral'},p.token,r.combatGeneration,s),false)
 eq(Run.choosePotionStance(r,{stance},p.token+1,r.combatGeneration,s),false)
 eq(Run.choosePotionStance(r,{stance},p.token,r.combatGeneration+1,s),false)
 eq(Run.choosePotionStance(r,{stance},p.token,r.combatGeneration,C.copy(s)),false)
 eq(s.pendingPotionChoice,p);eq(s.player.hp,hp)
 assert(Run.choosePotionStance(r,{stance},p.token,r.combatGeneration,s))
 eq(s.pendingPotionChoice,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil);eq(s.player.stance,stance);eq(s.player.hp,hp+5);eq(r.hp,hp+5)
 eq(s.energy,energy);eq(s.nextUid,uid);eq(#r.deck,master);eq(s.player.statuses.artifact,1)
 eq(Run.choosePotionStance(r,{stance},p.token,r.combatGeneration,s),false)
 print('ok typed '..stance..', Bark='..tostring(bark)..', consumed before choice, forced pause, no card entities, stale/repeat rejection')
end end
local r=fresh();local s=r.combat
for _,stance in ipairs({'Calm','Calm','Wrath'})do
 if not r.potions[1]then assert(Run.obtainPotion(r,'stance_potion'))end
 assert(Run.usePotion(r,1));local p=s.pendingPotionChoice;local energy=s.energy
 assert(Run.choosePotionStance(r,{stance},p.token,r.combatGeneration,s))
 eq(s.energy,energy+(stance=='Wrath'and 2 or 0))
end
eq(s.player.stance,'Wrath');eq(A.attackAmount(s,s.player,s.enemies[1],6),12);eq(A.attackAmount(s,s.enemies[1],s.player,6),12)
local p=fresh();local b=p.combat;local bottle=p.potions;local events=#b.events
b.potionChoiceSerial=2147483647
eq(Run.usePotion(p,1),false);eq(p.potions,bottle);eq(p.potions[1],'stance_potion');eq(b.pendingPotionChoice,nil);eq(b.actionQueue,nil);eq(#b.events,events)
print('CLASS_POTION_STANCE_PASS same stance successful, real Calm exit, use-phase overflow fully rolls back')
