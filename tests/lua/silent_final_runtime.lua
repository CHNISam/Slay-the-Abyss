package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local A=require('abyss_actor');local R=require('abyss_sts_random')
local data=require('abyss_character_profiles').prepare(require('abyss_data'),'silent')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(id,up)
 local s=C.new(data,{deck={id,'defend_green','strike_green'},enemies={'jaw_worm','jaw_worm'},seed=42,experimental=true,enableStances=true})
 local all={};for _,n in ipairs({'hand','draw','discard','exhaust'})do for _,c in ipairs(s[n])do all[#all+1]=c end;s[n]={}end
 s.hand=all;s.energy=20;s.potionRng=R.fromSeed('42');s.potionCharacter='silent';s.potionInventory={};s.potionCapacity=3
 for _,e in ipairs(s.enemies)do e.hp,e.maxHp=300,300 end
 local chosen;for _,c in ipairs(all)do if c.cardId==id then chosen=c;c.upgraded=up end end
 return s,chosen
end
local n=0
for _,up in ipairs({false,true})do
 for _,id in ipairs({'distraction','endless_agony','masterful_stab','setup','well_laid_plans','bullet_time','burst','corpse_explosion','doppelganger','nightmare','phantasmal_killer','tools_of_the_trade','alchemize','wraith_form'})do
  local s,c=fresh(id,up);local hp=s.enemies[1].hp
  assert(C.play(s,c.uid,(id=='corpse_explosion'or id=='endless_agony'or id=='masterful_stab')and 1 or nil),id)
  if id=='endless_agony'then eq(hp-s.enemies[1].hp,up and 6 or 4)
  elseif id=='masterful_stab'then eq(hp-s.enemies[1].hp,up and 16 or 12)
  elseif id=='setup'or id=='nightmare'then assert(s.pendingChoice,id);assert(C.chooseCard(s,s.pendingChoice.token,s.hand[1].uid));if id=='setup'then eq(#s.draw,1)else eq(s.player.statuses.nightmare,3)end
  elseif id=='well_laid_plans'then eq(s.player.statuses.well_laid_plans,up and 2 or 1)
  elseif id=='bullet_time'then assert(s.player.noDraw);for _,h in ipairs(s.hand)do eq(C.cardDefinition(s,h).cost,0)end
  elseif id=='burst'then eq(s.player.statuses.burst,up and 2 or 1)
  elseif id=='corpse_explosion'then eq(s.enemies[1].statuses.poison,up and 9 or 6);eq(s.enemies[1].statuses.corpse_explosion,1)
  elseif id=='doppelganger'then eq(s.player.statuses.energized,20+(up and 1 or 0))
  elseif id=='phantasmal_killer'then eq(s.player.statuses.phantasmal,1)
  elseif id=='tools_of_the_trade'then eq(s.player.statuses.tools_of_the_trade,1)
  elseif id=='alchemize'then assert(s.potionInventory[1]);assert(s.potionRng.counter>0)
  elseif id=='wraith_form'then eq(s.player.statuses.intangible,up and 3 or 2);eq(s.player.statuses.wraith_form,-1)
  elseif id=='distraction'then eq(#s.hand,3);eq(s.hand[3].costForTurn,0);assert(not s.hand[3].deckUid)
  end
  n=n+1;print('ok Silent final actual use '..id..(up and '+'or ''))
 end
end
print('SILENT_FINAL_REAL_PLAYS '..n)
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('not held '..id)end
local function play(s,id,target)local ok,why=C.play(s,held(s,id).uid,target);assert(ok,why)end
do
 local s=fresh('well_laid_plans',true);play(s,'well_laid_plans');s.rules.player.drawPerTurn=0
 local uid=s.hand[1].uid;assert(C.endTurn(s));assert(s.pendingChoice);assert(C.chooseCard(s,s.pendingChoice.token,uid));assert(C.chooseCard(s,s.pendingChoice.token,0))
 eq(s.turn,2);eq(#s.hand,1);eq(s.hand[1].uid,uid);eq(s.pendingChoice,nil)
 print('ok real end-turn retain continuation')
end
do
 local s=fresh('nightmare');play(s,'nightmare');local template=s.hand[1]
 assert(C.chooseCard(s,s.pendingChoice.token,template.uid));s.rules.player.drawPerTurn=0;assert(C.endTurn(s))
 eq(#s.hand,3);eq(s.player.statuses.nightmare,nil)
 for _,c in ipairs(s.hand)do eq(c.cardId,template.cardId);assert(c.uid~=template.uid);eq(c.deckUid,nil)end
 print('ok Nightmare next start copies and temporary ownership')
end
do
 local s=fresh('phantasmal_killer');play(s,'phantasmal_killer');s.rules.player.drawPerTurn=0;assert(C.endTurn(s))
 eq(s.player.statuses.double_damage,1);s.player.statuses.strength=2;s.player.statuses.vigor=3
 eq(C.attackAmount(s,s.player,s.enemies[1],6),22);eq(s.player.statuses.phantasmal,nil)
 print('ok Phantasmal next start normal multiplier after strength/vigor')
end
do
 local s=fresh('wraith_form');s.player.statuses.artifact=1;play(s,'wraith_form');eq(s.player.statuses.wraith_form,nil);eq(s.player.statuses.intangible,2)
 local t=fresh('wraith_form');play(t,'wraith_form');t.rules.player.drawPerTurn=0;assert(C.endTurn(t));eq(t.player.statuses.dexterity,-1);eq(t.player.statuses.intangible,1)
 print('ok Wraith Artifact and owner-end Dexterity, round-end Intangible')
end
do
 local s=fresh('burst');play(s,'burst');local uid=held(s,'defend_green').uid;play(s,'defend_green');eq(s.player.block,10);eq(s.player.statuses.burst,nil)
 local copies=0;for _,c in ipairs(s.discard)do if c.uid==uid then copies=copies+1 end end;eq(copies,1)
 print('ok Burst real old skill replay once, no duplicate physical UID')
end
do
 local s=fresh('corpse_explosion');play(s,'corpse_explosion',1);s.enemies[1].hp=1;C.damage(s,s.player,s.enemies[1],1,true)
 require('abyss_card_actions').drain(C,s);eq(s.enemies[2].hp,0)
 print('ok Corpse Explosion death damage uses maximum HP')
end
do
 local s=fresh('masterful_stab');local c=held(s,'masterful_stab');C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player)
 eq(C.cardDefinition(s,c).cost,1);C.applyEffects(s,{{op='loseHp',value=0}},s.player,s.player);eq(C.cardDefinition(s,c).cost,1)
 print('ok Masterful positive HP loss cost hook')
end
do
 local s=fresh('tools_of_the_trade');play(s,'tools_of_the_trade');s.rules.player.drawPerTurn=1;assert(C.endTurn(s));assert(s.pendingDiscard)
 local uid=s.hand[1].uid;assert(C.chooseDiscard(s,{uid},s.pendingDiscard.token));eq(s.pendingDiscard,nil);eq(s.pendingTurnStart,nil);eq(s.actionQueue,nil)
 print('ok Tools post-draw manual discard pauses and resumes real start queue')
end
