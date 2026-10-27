package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;'..package.path
local X,F,Run=require('support.experimental_ui_fixture'),require('support.game_ui_fixture'),require('abyss_run')
local function setup(id,up)
 local ui,root=X.new();assert(ui:start());assert(F.click(root,'characterPanel','character4'))
 ui.run.deck={{uid=31,cardId=id,upgraded=up},{uid=32,cardId='empty_fist'},{uid=33,cardId='empty_body'}};ui.run.nextDeckUid=34
 assert(Run.startCombat(ui.run,'cultist_solo'));ui.run.combat.energy=10;ui:refresh();return ui,root,ui.run.combat
end
local function play(ui,root,s,id)
 ui:refresh();local slot;for i,c in ipairs(s.hand)do if c.cardId==id then slot=i end end;assert(slot)
 F.click(root,'battlePanel','card'..slot);F.click(root,'battlePanel','playArea')
 ui:refresh()
end
local ui,root,s=setup('wish',true);play(ui,root,s,'wish')
assert(ui.deckUI.visible and s.pendingChoice.kind=='wish')
local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
assert(panel:GetChild('title').text:find('许愿',1,true));assert(not panel:GetChild('close').visible)
grid:flush();ui:update(0);grid:flush();assert(grid.itemCount==3)
local old=grid.items[2]:GetChild('hit').click;old()
for _=1,100 do ui:update(.05);if not ui.battleUI.busy then break end end;ui:refresh()
assert(s.player.statuses.plated_armor==8 and not s.pendingChoice and not ui.deckUI.visible)
local gold=s.player.gold;old();assert(s.player.gold==gold and s.player.statuses.plated_armor==8)
ui,root,s=setup('omniscience',true)
local original;for i,c in ipairs(s.hand)do if c.cardId=='empty_fist' then original=table.remove(s.hand,i);break end end
assert(original);s.draw={original};play(ui,root,s,'omniscience')
assert(ui.choiceUI.visible and s.pendingPileChoice.mode=='omniscience')
assert(root:GetChild('choicePanel'):GetChild('title').text:find('全知',1,true))
assert(F.click(root,'choicePanel','card1'));local confirm=root:GetChild('choicePanel'):GetChild('confirm'):GetChild('hit').click
assert(F.click(root,'choicePanel','confirm'));ui:refresh();assert(not s.pendingPileChoice and not ui.choiceUI.visible)
local hp=s.enemies[1].hp;local accepted=confirm();assert(not accepted and s.enemies[1].hp==hp)
local n=0;for _,c in ipairs(s.exhaust)do if c.uid==original.uid then n=n+1 end end;assert(n==1)
print('WATCHER_FINAL_CHOICE_UI native Wish third option, Omniscience singleton, titles and closed stale callbacks passed')
