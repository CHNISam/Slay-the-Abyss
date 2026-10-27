package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,R,Actions=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random'),require('abyss_card_actions')
local Data=C.copy(require('abyss_data'));local Text=require('abyss_potion_text')
Data.relics.relics[#Data.relics.relics+1]={id='SacredBark',name='Sacred Bark',rarity='boss',trigger='passive',effects={}}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(id,bark)
 local r=Run.new(Data,42,{character='watcher',experimental=true})
 if bark then r.relics[#r.relics+1]='SacredBark'end
 local ok,why=Run.obtainPotion(r,id);assert(ok,why)
 assert(Run.startCombat(r,'cultist_solo'));return r
end
for _,bark in ipairs({false,true})do
 for _,mr in ipairs({false,true})do
  local r=fresh('bottled_miracle',bark);local s=r.combat;local amount=bark and 4 or 2
  if mr then A.applyPower(s,s.player,'master_reality',1,s.player)end
  -- Leave exactly one space: the remaining real temporary cards overflow.
  while #s.hand<9 do Actions.toHand(s,Actions.fresh(C,s,s.hand[1].cardId))end
  local uid,master=s.nextUid,#r.deck;local energy=s.energy
  assert(Run.usePotion(r,1,nil,function(candidate)eq(candidate.nextUid,uid)end));eq(r.combat,s)
  local cards={};for _,pile in ipairs({s.hand,s.discard})do for _,c in ipairs(pile)do if c.uid>=uid then cards[#cards+1]=c end end end
  eq(#cards,amount);eq(#s.hand,10);eq(#s.discard,amount-1);eq(s.nextUid,uid+amount);eq(#r.deck,master)
  for i,c in ipairs(cards)do
   eq(c.cardId,'miracle');eq(c.deckUid,nil);eq(c.upgraded,mr);eq(c.uuid,c.uid)
   for j=1,i-1 do assert(cards[j].uid~=c.uid and cards[j].uuid~=c.uuid)end
   local d=C.cardDefinition(s,c);eq(d.cost,0);eq(d.selfRetain,true);eq(d.exhaust,true);eq(d.effects[1].value,mr and 2 or 1)
  end
  assert(Run.play(r,cards[1].uid));eq(s.energy,energy+(mr and 2 or 1));eq(s.exhaust[#s.exhaust].uid,cards[1].uid);eq(#r.deck,master)
  assert(Text.describe(r,'bottled_miracle'):find(tostring(amount)..'张',1,true))
  assert(Text.describe(r,'bottled_miracle'):find('现实改写为+2',1,true))
  print('ok Miracle '..amount..', MR='..tostring(mr)..', overflow, fresh temporary UIDs and actual play')
 end
 local r=fresh('ambrosia',bark);local s=r.combat;local before=s.energy
 assert(Run.usePotion(r,1,nil,function(candidate)eq(candidate.player.stance,'Neutral');eq(candidate.energy,before)end))
 eq(r.combat,s);eq(s.player.stance,'Divinity');eq(s.energy,before+3)
 assert(Text.describe(r,'ambrosia'):find('入场+3能量',1,true));assert(Text.describe(r,'ambrosia'):find('树皮不加次数',1,true))
 for _,d in ipairs(r.data.potions.potions)do if d.id=='ambrosia'then
  local text=Text.special(d,r,true);assert(text:find('下个自己回合开始退出',1,true));assert(text:find('已在神格不重复入场',1,true))
 end end
 eq(A.attackAmount(s,s.player,s.enemies[1],6),18)
 assert(Run.obtainPotion(r,'ambrosia'));assert(Run.usePotion(r,1));eq(s.energy,before+3)
 assert(Run.endTurn(r));eq(s.player.stance,'Neutral')
 print('ok Ambrosia one entry with/without Bark, existing Divinity no extra energy, next own turn exits')
end
local r=fresh('ambrosia');local s=r.combat
assert(Run.obtainPotion(r,'energy_potion'));assert(Run.usePotion(r,2))
for _,id in ipairs({'vigilance','mental_fortress','rushdown'})do
 local c=Actions.fresh(C,s,id);Actions.toHand(s,c);assert(Run.play(r,c.uid))
end
eq(s.player.stance,'Calm');local energy=s.energy;local draw=#s.draw;local block=s.player.block
local flurry=Actions.fresh(C,s,'flurry_of_blows');s.discard[#s.discard+1]=flurry
assert(Run.usePotion(r,1));eq(s.energy,energy+5);eq(s.player.block,block+4);eq(#s.draw,draw)
local found=false;for _,c in ipairs(s.hand)do if c.uid==flurry.uid then found=true end end;eq(found,true)
for _,id in ipairs({'bottled_miracle','ambrosia'})do
 local p=fresh(id);local battle=p.combat;local potions=p.potions;local hp,energy,events,nextUid=battle.player.hp,battle.energy,#battle.events,battle.nextUid
 if id=='bottled_miracle'then battle.catalog.cards.miracle=nil else battle.player.stance='invalid'end
 local rng=R.snapshot(battle.potionRng);eq(Run.usePotion(p,1),false)
 eq(p.combat,battle);eq(p.potions,potions);eq(p.potions[1],id);eq(battle.player.hp,hp);eq(battle.energy,energy);eq(#battle.events,events);eq(battle.nextUid,nextUid)
 eq(R.snapshot(battle.potionRng).counter,rng.counter)
 print('ok '..id..' failed actual use rolls back bottle, UIDs, resources and RNG')
end
print('CLASS_POTION_MIRACLE_AMBROSIA_PASS')
