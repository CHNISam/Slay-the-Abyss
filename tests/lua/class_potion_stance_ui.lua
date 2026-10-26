local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run');local C=require('abyss_combat')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=42,prologue=false,experimentalCharacters=true,
 imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,
 cursorEvents={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='endDrag'}})
local function drain()
 for _=1,400 do if not host.battleUI.busy then return end;host:update(0.05)end
 error('feedback did not finish')
end
local panel=root:GetChild('choicePanel')
local function hit(name)return panel:GetChild(name):GetChild('hit')end
local function emit(name,kind,touch)return assert(hit(name).listeners[kind])({touchId=touch})end
local function tap(name,touch)emit(name,'down',touch);emit(name,'up',touch);return emit(name,'click',touch)end
local function start(replace)
 if replace then
  -- Adversarial host-owner replacement, using another real Watcher factory.
  local nextRun=Run.new(F.Data,43,{character='watcher',experimental=true})
  host.run,host.battleUI.run,host.nodeUI.run=nextRun,nextRun,nextRun
 else assert(host:start('watcher'))end
 local r=host.run;r.relics[#r.relics+1]='toy_ornithopter'
 assert(Run.obtainPotion(r,'stance_potion'));assert(Run.obtainPotion(r,'stance_potion'))
 assert(Run.startCombat(r,'cultist_solo'));r.hp=r.hp-20;r.combat.player.hp=r.hp
 if replace then
  -- Keep the old controller/touch alive until it attempts the new core owner.
  assert(Run.usePotion(r,1));return r
 end
 host:refresh()
 assert(host.battleUI:usePotion(1));drain();assert(host.choiceUI.visible);return r
end
local r=start();local battle=r.combat;local pending=battle.pendingPotionChoice;local hp=battle.player.hp
eq(panel:GetChild('title').text,'姿态药水：选择姿态')
local wrath=hit('card1'):GetChild('normal'):GetChild('label').text
local calm=hit('card2'):GetChild('normal'):GetChild('label').text
assert(wrath:find('愤怒',1,true)and wrath:find('造成和受到的普通攻击伤害均翻倍',1,true))
assert(calm:find('平静',1,true)and calm:find('离开平静时获得2点能量',1,true))
assert(not wrath:find('费用',1,true));eq(panel:GetChild('card3').visible,false);eq(r.potions[1],nil)
assert(tap('card1',1));emit('confirm','down',2);host:resize(1280,720);emit('confirm','up',2);eq(emit('confirm','click',2),false)
eq(battle.pendingPotionChoice,pending);eq(battle.player.stance,'Neutral');eq(battle.player.hp,hp)
assert(host:openExit());eq(host.choiceUI.visible,false);eq(battle.pendingPotionChoice,pending);eq(r.potions[1],nil)
assert(host:closeExit());assert(host.choiceUI.visible);eq(battle.pendingPotionChoice,pending)
eq(hit('confirm').interactable,false);assert(tap('card2',3));assert(tap('confirm',4));drain()
eq(battle.player.stance,'Calm');eq(battle.pendingPotionChoice,nil);eq(battle.player.hp,hp+5);eq(host.choiceUI.visible,false)
-- Old Run and old pointer owner must not choose an identical token/generation
-- in a replacement real host, even though both combats begin at generation1.
assert(host.battleUI:usePotion(2));drain();assert(tap('card1',5));emit('confirm','down',6)
local oldRun,oldBattle,oldPending=r,battle,battle.pendingPotionChoice
r=start(true);battle=r.combat;pending=battle.pendingPotionChoice
assert(not emit('confirm','up',6));eq(emit('confirm','click',6),false)
eq(battle.pendingPotionChoice,pending);eq(battle.player.stance,'Neutral');eq(oldBattle.pendingPotionChoice,oldPending)
eq(Run.choosePotionStance(r,{'Wrath'},oldPending.token,r.combatGeneration,oldBattle),false)
assert(oldRun~=r);assert(tap('card1',7));emit('confirm','down',8)
-- A changed battle reference invalidates an in-flight touch before refresh.
local replacement=C.copy(battle);r.combat=replacement;host:refresh()
assert(not emit('confirm','up',8));eq(emit('confirm','click',8),false)
eq(replacement.player.stance,'Neutral');assert(replacement.pendingPotionChoice)
assert(tap('card1',9));assert(tap('confirm',10));drain();eq(replacement.player.stance,'Wrath');eq(replacement.pendingPotionChoice,nil)
print('CLASS_POTION_STANCE_UI_PASS real GameUI/ChoiceUI two typed Chinese options, mandatory exit-cancel, stale resize/run/battle/touch rejected')
