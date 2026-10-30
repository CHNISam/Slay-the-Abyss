local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local UI,Run=require('abyss_battle_ui'),require('abyss_run')
local function fixture(ids)
 local canvas=F.control({children=F.Layout});local root=F.Viewport.apply(canvas,1280,720):GetChild('battlePanel')
 local ui=UI.new(root,F.Data,F.Presentation,'click',F.withMonsterActors({imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end}),{embedded=true})
 local run=Run.new(F.Data,42);run.phase='combat'
 run.combat=assert(F.Combat.new(F.Data,{seed=42,enemies=ids,deck={}}));ui.run=run
 return ui,root,run.combat
end
local function allPages(ui,root)
 local panel=root:GetChild('statusInfo');assert(panel.visible)
 local text={}
 for _=1,ui.info.pages do
  for i=1,F.Theme.layout.statusInfo.rows do
   local name=panel:GetChild('name'..i)
   if name.visible then text[#text+1]=name.text..' '..panel:GetChild('text'..i).text..' '..panel:GetChild('note'..i).text end
  end
  panel:GetChild('page').click()
 end
 return table.concat(text,' | ')
end
do
 local ui,root,s=fixture({'corrupt_heart'});ui:render()
 monsterControl(root,'enemy1'):GetChild('intentHit').click()
 assert(ui.info and ui.info.kind=='intent'and ui.info.pages>1)
 local text=allPages(ui,root)
 for _,id in ipairs({'dazed','slimed','wound','burn','void'})do assert(text:find(s.catalog.cards[id].name,1,true))end
 assert(text:find('抽牌堆',1,true))
end
do
 local ui,root,s=fixture({'spire_shield','spire_spear'})
 for i,intent in ipairs(s.enemies[1].intents)do if intent.id=='smash'then s.enemies[1].intentIndex=i end end
 F.Combat.addStatus(s.enemies[1],'weak',1);F.Combat.addStatus(s.enemies[1],'strength',1);F.Combat.addStatus(s.player,'vulnerable',1)
 ui:render();dofile('tests/lua/support/intent_face_assertion.lua')(monsterControl(root,'enemy1'),require('abyss_battle_intent_view').intentView(s,1))
 assert(monsterControl(root,'enemy1'):GetChild('intent').text=='59','detached UI preview must preserve source back-attack identity')
 monsterControl(root,'enemy1'):GetChild('intentHit').click()
 local text=allPages(ui,root);assert(text:find('格挡',1,true)and text:find('58',1,true))
end
do
 local ui,root,s=fixture({'corrupt_heart'});local e=s.enemies[1]
 assert(require('abyss_actor').applyPower(s,e,'painful_stabs',-1,e))
 local entries=F.Combat.statusView(e);local owned
 for _,entry in ipairs(entries)do if entry.id=='painful_stabs'then owned=entry end end
 assert(owned and owned.amount==-1 and owned.stack=='none')
 ui:render();assert(ui:openHelp({index=1,statusId='painful_stabs'}))
 local panel=root:GetChild('statusInfo');local name=panel:GetChild('name1')
 assert(name.text==s.catalog.statuses.painful_stabs.name,'no-number status must not show -1 stacks')
 assert(name.fontColor.r==F.Theme.color.buff.r and name.fontColor.g==F.Theme.color.buff.g,'actual PainfulStabs must use buff colour')
 local text=panel:GetChild('text1').text;assert(#text>0 and not text:find('-1',1,true))
 local Status=require('abyss_battle_status_view')
 assert(Status.statusKind({id='strength',amount=-1,kind='buff'})=='debuff')
 assert(Status.statusKind({id='dexterity',amount=-1,kind='buff'})=='debuff')
end
print('ENDING_INTENT_UI_PASS 3 strict generated-tree cases; offline controlled, no platform acceptance')
