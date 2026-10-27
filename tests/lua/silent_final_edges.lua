package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local A=require('abyss_actor');local Actions=require('abyss_card_actions');local R=require('abyss_sts_random')
local data=require('abyss_character_profiles').prepare(require('abyss_data'),'silent')
-- TASK-59 owns the combined production catalog. This fixture combines an
-- unchanged actual native red Strike to exercise the foreign native host now.
for _,d in ipairs(require('abyss_data').cards.cards)do if d.id=='strike'or d.id=='searing_blow'then data.cards.cards[#data.cards.cards+1]=C.copy(d)end end
-- Source Master Reality's passive definition is a constructed cross-catalog
-- context here; the production combined Watcher catalog belongs to TASK-59.
data.statuses.statuses[#data.statuses.statuses+1]={id='master_reality',name='化实为虚',kind='buff',stack='intensity',decay='none',description='生成的非状态诅咒牌升级。'}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(ids)
 local s=C.new(data,{deck=ids,enemies={'jaw_worm','jaw_worm'},seed=42,experimental=true,enableStances=true})
 local all={};for _,name in ipairs({'hand','draw','discard','exhaust'})do for _,c in ipairs(s[name])do all[#all+1]=c end;s[name]={}end
 s.hand=all;s.energy=30;s.potionRng=R.fromSeed('42');s.potionCharacter='silent';s.potionInventory={};s.potionCapacity=3
 for _,e in ipairs(s.enemies)do e.hp,e.maxHp=300,300 end
 return s
end
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error(id)end
local function play(s,id,target)local ok,why=C.play(s,held(s,id).uid,target);assert(ok,why)end
do
 local s=fresh({'nightmare','searing_blow','defend_green'});A.applyPower(s,s.player,'master_reality',1,s.player)
 local original=held(s,'searing_blow');original.deckUid=999;play(s,'nightmare');assert(C.chooseCard(s,s.pendingChoice.token,original.uid))
 s.rules.player.drawPerTurn=0;assert(C.endTurn(s));eq(#s.hand,3);eq(original.upgrades,nil);eq(original.upgraded,false)
 for _,c in ipairs(s.hand)do eq(c.cardId,'searing_blow');eq(c.upgrades,2);eq(c.deckUid,nil);eq(C.cardDefinition(s,c).effects[1].value,21)end
 print('ok foreign Nightmare repeatable Searing Blow receives both source created upgrades without changing original')
end
do
 local s=fresh({'acrobatics','endless_agony','defend_green'});local drawn=held(s,'endless_agony')
 s.hand={held(s,'acrobatics'),held(s,'defend_green')};s.draw={drawn};s.discard={}
 play(s,'acrobatics');assert(s.pendingDiscard);eq(#s.hand,3)
 local copyUid;for _,c in ipairs(s.hand)do if c.cardId=='endless_agony'and c.uid~=drawn.uid then copyUid=c.uid end end;assert(copyUid)
 assert(C.chooseDiscard(s,{copyUid},s.pendingDiscard.token));eq(s.pendingDiscard,nil)
 print('ok Endless TOP copy is eligible for the immediately following Acrobatics discard choice')
end
for _,wraithFirst in ipairs({false,true})do
 local s=fresh({'wraith_form'})
 if not wraithFirst then A.addTemporaryDexterity(s.player,5,s)end
 play(s,'wraith_form')
 if wraithFirst then A.addTemporaryDexterity(s.player,5,s)end
 s.player.statuses.artifact=1;A.endTurn(s,s.player);Actions.drain(C,s)
 eq(s.player.statuses.dexterity,wraithFirst and 0 or 4)
 print('ok Wraith and temporary Dexterity loss spend Artifact in actual acquisition order '..tostring(wraithFirst))
end
do
 local s=fresh({'well_laid_plans','defend_green','strike_green'});s.experimentalCharacter=nil;s.experimentalMechanics=false
 play(s,'well_laid_plans');s.rules.player.drawPerTurn=0;local uid=s.hand[1].uid
 assert(C.endTurn(s));assert(s.pendingChoice);assert(C.chooseCard(s,s.pendingChoice.token,uid));assert(C.chooseCard(s,s.pendingChoice.token,0))
 eq(s.turn,2);eq(#s.hand,1);eq(s.hand[1].uid,uid);eq(s.silentOwnerEndResolved,nil)
 print('ok foreign Well-Laid Plans retained through real native turn host')
end
do
 local s=fresh({'bullet_time','defend_green'});s.player.noDraw=true;s.player.statuses.artifact=1
 play(s,'bullet_time');eq(s.player.statuses.artifact,1);eq(C.cardDefinition(s,s.hand[1]).cost,0)
 print('ok duplicate NoDraw gate precedes Artifact without skipping Bullet Time costs')
end
do
 local s=fresh({'after_image','wraith_form','strike'});s.experimentalCharacter=nil;s.experimentalMechanics=false
 require('abyss_card_triggers').apply(s,'after_image',1);s.player.statuses.rage=3
 play(s,'wraith_form');eq(s.player.block,1)
 play(s,'strike',1);eq(s.player.block,5)
 print('ok foreign native After Image works and existing native Rage dispatches exactly once')
end
do
 local s=fresh({'burst','acrobatics','defend_green','strike_green','defend_green'});play(s,'burst');play(s,'acrobatics')
 for _=1,2 do assert(s.pendingDiscard);assert(C.chooseDiscard(s,{s.hand[1].uid},s.pendingDiscard.token))end
 eq(s.pendingDiscard,nil);eq(s.pendingPlay,nil);eq(s.actionQueue,nil);eq(s.cardActions,nil)
 local plays=0;for _,e in ipairs(s.events)do if e.kind=='play'and e.detail.cardId=='acrobatics'then plays=plays+1 end end;eq(plays,2)
 print('ok Burst two real Acrobatics manual selections and clean continuation')
end
do
 local s=fresh({'after_image','endless_agony'});play(s,'after_image');s.enemies[1].hp=1;s.enemies[2].hp=0;play(s,'endless_agony',1)
 eq(s.phase,'victory');eq(s.player.block,1)
 print('ok After Image block retained after final killing Endless Agony')
end
do
 local s=fresh({'corpse_explosion','defend_green'});s.enemies[1].statuses.artifact=1;play(s,'corpse_explosion',1)
 eq(s.enemies[1].statuses.poison,nil);eq(s.enemies[1].statuses.corpse_explosion,1)
 s.enemies[1].hp=1;s.enemies[1].statuses.poison=1;local hp=s.player.hp
 assert(C.endTurn(s));eq(s.phase,'victory');eq(s.player.hp,hp);eq(s.enemies[2].hp,0)
 print('ok independent Artifact applications and poison death explode before next enemy acts')
end
do
 local s=fresh({'corpse_explosion','distraction','defend_green'});play(s,'corpse_explosion',1);s.enemies[1].statuses.choked=2;s.enemies[1].hp=1;play(s,'distraction')
 eq(s.enemies[1].hp,0);eq(s.enemies[2].hp,0)
 print('ok native skill Choke HP loss invokes Corpse Explosion death chain')
end
do
 local s=fresh({'masterful_stab','setup','defend_green'});local c=held(s,'masterful_stab');c.costForTurn=0
 C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player);eq(C.cardDefinition(s,c).cost,1);eq(C.combatBaseCost(s,c),1)
 play(s,'setup');assert(C.chooseCard(s,s.pendingChoice.token,c.uid));assert(c.freeToPlayOnce);eq(s.draw[#s.draw].uid,c.uid)
 C.draw(s,1);local energy=s.energy;play(s,'masterful_stab',1);eq(s.energy,energy);eq(c.freeToPlayOnce,nil)
 print('ok Masterful cost delta and Setup base-cost free flag preserve actual UID')
end
do
 local s=fresh({'doppelganger'});local c=held(s,'doppelganger');c.freeToPlayOnce=true;local energy=s.energy
 play(s,'doppelganger');eq(s.energy,energy);eq(s.player.statuses.energized,energy);eq(c.freeToPlayOnce,nil)
 print('ok free Doppelganger snapshots X and keeps actual energy')
end
do
 local s=fresh({'endless_agony','defend_green'});local c=held(s,'endless_agony');s.hand={};s.draw={c};s.discard={}
 for _=1,9 do s.hand[#s.hand+1]=Actions.fresh(C,s,'defend_green')end
 C.draw(s,1);Actions.drain(C,s);eq(#s.hand,10);eq(#s.discard,1);eq(s.discard[1].cardId,'endless_agony');assert(s.discard[1].uid~=c.uid);eq(s.discard[1].deckUid,nil)
 print('ok actual drawn Endless Agony makes one nonrecursive overflow copy')
end
do
 local s=fresh({'alchemize','defend_green'});s.potionInventory={'block_potion','block_potion','block_potion'}
 local before=s.potionRng.counter;play(s,'alchemize');assert(s.potionRng.counter>before);eq(s.potionInventory[1],'block_potion');eq(s.potionInventory[3],'block_potion')
 local t=fresh({'alchemize'});t.potionRng=nil;local uid=t.hand[1].uid;local energy=t.energy;local n=t.nextUid
 assert(not pcall(C.play,t,uid));eq(t.energy,energy);eq(t.hand[1].uid,uid);eq(t.nextUid,n);eq(#t.exhaust,0)
 print('ok full slots still consume source RNG; unavailable RNG fully rolls back real use')
end
