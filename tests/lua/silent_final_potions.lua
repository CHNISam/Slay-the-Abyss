package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run');local C=require('abyss_combat');local A=require('abyss_actor');local R=require('abyss_sts_random')
local Data=C.copy(require('abyss_data'))
-- Bark's natural acquisition is outside this slice; passive fixture ownership
-- still passes through real Run relic snapshot and potion transactions.
Data.relics.relics[#Data.relics.relics+1]={id='SacredBark',name='Sacred Bark',rarity='boss',trigger='passive',effects={}}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(id,bark)
 local r=Run.new(Data,42,{character='silent',experimental=true})
 if bark then r.relics[#r.relics+1]='SacredBark'end
 assert(Run.obtainPotion(r,id));assert(Run.startCombat(r,'cultist_solo'));r.combat.enemies[1].hp=300;r.combat.enemies[1].maxHp=300
 return r
end
for _,bark in ipairs({false,true})do
 local r=fresh('cunning_potion',bark);local s=r.combat;local before=s.nextUid;s.player.statuses.master_reality=1
 assert(Run.usePotion(r,1));local found=0;local seen={}
 for _,name in ipairs({'hand','discard'})do for _,c in ipairs(s[name])do
  assert(not seen[c.uid]);seen[c.uid]=true
  if c.cardId=='shiv'then found=found+1;assert(c.upgraded);eq(c.deckUid,nil);eq(C.cardDefinition(s,c).effects[1].value,6)end
 end end
 eq(found,bark and 6 or 3);eq(s.nextUid-before,found);eq(#s.hand,math.min(s.rules.player.maxHand,7+found));eq(r.potions[1],nil)
 print('ok real Cunning '..(bark and 'Bark overflow' or 'normal')..' upgraded temporary Shivs')
 local ghost=fresh('ghost_in_a_jar',bark);assert(Run.usePotion(ghost,1));eq(ghost.combat.player.statuses.intangible,bark and 2 or 1)
 local hp=ghost.combat.player.hp;C.damage(ghost.combat,ghost.combat.enemies[1],ghost.combat.player,50,true);eq(hp-ghost.combat.player.hp,1)
 A.endRound(ghost.combat,ghost.combat.player);eq(ghost.combat.player.statuses.intangible,bark and 1 or 0)
 print('ok real Ghost '..(bark and 'Bark' or 'normal')..' damage ceiling and round decay')
end
do
 local r=fresh('cunning_potion');local s=r.combat;local hp=s.player.hp;local nextUid=s.nextUid;s.catalog.cards.shiv=nil
 local ok=Run.usePotion(r,1);eq(ok,false);eq(r.combat,s);eq(s.nextUid,nextUid);eq(s.player.hp,hp);eq(r.potions[1],'cunning_potion')
 print('ok failed generation keeps real potion, UID and battle unchanged')
end
do
 local r=fresh('ghost_in_a_jar');local s=r.combat;s.potionInventory={};s.potionCapacity=3
 local card={cardId='alchemize',uid=s.nextUid,upgraded=false,deckUid=999};s.nextUid=s.nextUid+1;s.hand[#s.hand+1]=card
 local P=require('abyss_potion_random');local owner={potionRng=R.cloneState(s.potionRng)};local expected=P.sample(owner,{limited=true,character='silent'})
 assert(Run.play(r,card.uid));eq(s.potionInventory[1],expected.id);eq(r.shopRng.potion.counter,owner.potionRng.counter)
 eq(r.potions[1],expected.id);eq(s.potionRngChanged,nil)
 print('ok Alchemize samples and publishes persistent Silent potion stream')
end
