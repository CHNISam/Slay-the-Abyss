package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Combat,Run=require('abyss_combat'),require('abyss_run')
local Choice=require('abyss_choice_ui')
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720):GetChild('choicePanel')
local platform={imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,
 cursorEvents={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='endDrag'}}
local s=Combat.new(require("abyss_warrior_cards").withFoundationCards(F.Data),{seed=42,enemies={'cultist'},deck={'warcry','defend','defend','defend','defend'}})
local warcry
for _,c in ipairs(s.hand)do if c.cardId=='warcry'then warcry=c.uid end end
for _,c in ipairs(s.hand)do if c.cardId=='defend'then c.upgraded=true;c.costForTurn=0 end end
assert(Combat.play(s,assert(warcry)))
local run={phase='combat',combat=s,combatGeneration=7,deck={}}
local a,b=s.hand[1],s.hand[2]

local ui=Choice.new(root,F.Presentation,'click',platform,function(kind,uids,token,generation)
 assert(kind=='hand');return Run.chooseHand(run,uids,token,generation)
end)
assert(ui:refresh(run,true))
local box=root:GetChild('card1')
local face=assert(box:GetChild('face'),'tactical choice must reuse a standard card face, not plain text')
assert(face:GetChild('name').text:find('＋',1,true),'upgrade marker retained')
assert(face:GetChild('cost').text==tostring(Combat.cardDefinition(s,a).cost),'live cost retained')
assert(face:GetChild('art').imageId,'standard type art populated')
assert(face:GetChild('label').text~='','card rules populated')
local function tap(i,id)
 local hit=root:GetChild('card'..i):GetChild('hit')
 hit.listeners.down({touchId=id});hit.listeners.up({touchId=id});return hit.listeners.click({touchId=id})
end
assert(tap(1,1));assert(ui.selected[1]==a.uid);assert(box:GetChild('order').text=='已选 1')
assert(tap(1,2));assert(#ui.selected==0,'second tap cancels local selection');assert(not box:GetChild('order').visible)
assert(tap(2,3));assert(ui.selected[1]==b.uid,'same-name duplicate preserves exact UID')
assert(ui:confirm());assert(s.draw[#s.draw]==b and s.pendingHandChoice==nil)
assert(not ui:confirm(),'duplicate confirm rejected')
assert(a.upgraded and a.costForTurn==0,'view must not alter instance state')
print('TACTICAL_CHOICE_FACES_PASS exact UID, upgraded/live cost, touch toggle, confirm once')
