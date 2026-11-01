local F=dofile('tests/lua/support/game_ui_fixture.lua')
local S=dofile('tests/lua/support/ui_readability_snapshot.lua')
local Run=require('abyss_run')
local Theme=require('abyss_theme')
local function nativeRows(text,font,width)
 local lines,used=0,0
 for _,code in utf8.codes(text:gsub('<[^>]+>',''))do
  if code==10 then lines=lines+math.max(1,math.ceil(used*font/width));used=0
  else used=used+(code<256 and .6 or 1)end
 end
 return lines+math.max(1,math.ceil(used*font/width))
end
local focus,usingController
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
 modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(v)focus=v end,isController=function()return usingController==true end}
local host,root=F.fixture(nil,nil,nil,nil,nil,nil,nil,api)
assert(F.start(host,'traveler'))
assert(Run.obtainRelic(host.run,'Potion Belt'))
assert(Run.obtainRelic(host.run,'sacred_bark'))
assert(Run.obtainRelic(host.run,'lizard_tail'))
for _,id in ipairs({'fire_potion','block_potion','regen_potion','energy_potion','strength_potion'})do assert(Run.obtainPotion(host.run,id))end
host.run.hp,host.run.maxHp,host.run.gold=999,999,99999
host:refresh()
S.capture('mobile-map',root,F.Layout)
local entry=root:GetChild('potionEntry'):GetChild('open'):GetChild('hit')
for _,state in ipairs({'normal','hover','pressed','disabled'})do
 local face=entry:GetChild(state)
 assert(face:GetChild('label').text=='药水 5/5')
 for i=1,5 do assert(not face:GetChild('slot'..i).visible)end
end
assert(entry.click())
local potionPanel=root:GetChild('potionPanel')
for i=1,5 do
 local slot=potionPanel:GetChild('slot'..i)
 assert(slot.visible and slot:GetChild('hit').click(),'all five physical inventory slots remain reachable')
end
for _,item in ipairs(F.Data.potions.potions)do
 host.run.potions[1]=item.id;host.potionUI:render()
 assert(potionPanel:GetChild('slot1'):GetChild('hit').click())
 local detail=potionPanel:GetChild('detail').text
 assert(nativeRows(detail,Theme.font.body,Theme.layout.potionDiscard.detail[3])*40<=Theme.layout.potionDiscard.detail[4],item.id..' complete management copy must fit')
end
host.run.potions[1]='fire_potion'
assert(potionPanel:GetChild('cancel'):GetChild('hit').click())
assert(host:openRelics())
for slot,e in ipairs(host.relicUI.rows)do
 assert(nativeRows(e.description,Theme.font.small,Theme.layout.relicView.description[3])*40<=Theme.layout.relicView.description[4],e.id..' complete owned-relic text must fit')
end
assert(host:closeDeck())
assert(Run.potionCount(host.run)==5,'reading inventory must not consume')
assert(Run.startCombat(host.run,'cultist_solo'))
host.run.combat.player.hp,host.run.combat.player.gold=999,99999
host:refresh()
S.capture('mobile-battle',root,F.Layout)
local Enemy=require('abyss_battle_enemy_view')
local function overlap(a,b)return math.abs(a[1]-b[1])<(a[3]+b[3])/2 and math.abs(a[2]-b[2])<(a[4]+b[4])/2 end
local panel=root:GetChild('battlePanel')
for _,id in ipairs({'guardian','hexaghost','slime_boss','collector','automaton','champ','gremlin_leader'})do
 local enemies=id=='gremlin_leader' and {'mad_gremlin','sneaky_gremlin',id} or {id}
 local battle=F.Combat.new(F.Data,{enemies=enemies,deck={'strike'},seed=42})
 host.run.combat=battle;host:refresh();host:update(.8)
 local actor=battle.enemies[#battle.enemies];local g=Enemy.geometry(actor)
 local box=require('abyss_monster_surfaces').get(panel):find(actor.id)
 local glyph=box:GetChild('intentIcon')
 local intent={g.x+glyph.x,g.y+glyph.y,glyph.sizeDeltaX,glyph.sizeDeltaY}
 local body={g.x,g.y,g.portrait,g.portrait}
 for i=1,5 do
  local p=Theme.layout.battlePotions
  local bottle={p.origin[1]+(i-1)*p.step[1],p.origin[2],p.size[1],p.size[2]}
  assert(not overlap(bottle,intent),id..' intent must clear potion '..i)
  assert(not overlap(bottle,body),id..' portrait must clear potion '..i)
 end
end
-- The existing complete reading entry pages text at the enlarged body size.
local raw=string.rep('完整卡牌说明不丢失。',100)
assert(host.deckUI:inspectText(host.run,'完整阅读',raw))
local pages=host.deckUI.detailPages
assert(#pages>1,'long copy needs reachable pages')
assert(table.concat(pages,''):gsub('\n','')==raw,'pagination must preserve every glyph')
host:refresh()
S.capture('mobile-detail',root,F.Layout)
local deck=root:GetChild('deckPanel');local detailHit=deck:GetChild('detailHit')
for i,page in ipairs(pages)do
 assert(host.deckUI.detailPage==i and deck:GetChild('details').text:find(page,1,true)==1,'every full reading page must be visible')
 assert(detailHit.click(),'tap must reach the next page')
end
assert(host.deckUI.detailPage==1,'last page cycles back to the first')
usingController=true;host:syncController();focus=detailHit
assert(detailHit.navigationListeners.confirm(),'controller confirmation reaches the existing reading surface')
assert(host.deckUI.detailPage==2)
usingController=false;host:update(.01)
assert(host.deckUI:close())
assert(root:GetChild('exitEntry'):GetChild('open'):GetChild('hit').click())
S.capture('mobile-pause',root,F.Layout)
assert(root:GetChild('runMenu'):GetChild('abandon'):GetChild('hit').click())
S.capture('mobile-exit',root,F.Layout)
host:disable()
print('MOBILE_TYPOGRAPHY_RUNTIME_PASS')
