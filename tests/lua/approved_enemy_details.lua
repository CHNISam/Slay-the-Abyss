local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Combat,Theme=H.F.Combat,H.F.Theme
local count=0
local function same(a,b)
 assert(type(a)==type(b),'inspection changed rule-state type')
 if type(a)~='table'then assert(a==b,'inspection changed rule-state value');return end
 for key,value in pairs(a)do same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil,'inspection added a rule-state field')end
end
local function test(name,fn)fn();count=count+1;print('ok approved details '..count..' - '..name)end
local function contents(ui,panel)
 local info,parts=panel:GetChild('statusInfo'),{}
 assert(info.visible,'portrait click must open the existing independent detail card')
 local pages=assert(ui.info.pages)
 for page=1,pages do
  assert(ui.info.page==page)
  for i=1,Theme.layout.statusInfo.rows do
   for _,field in ipairs({'name','text','tag','note'})do
    local part=info:GetChild(field..i)
    if part.visible then parts[#parts+1]=part.text end
   end
  end
  if page<pages then info:GetChild('page').click()end
 end
 return table.concat(parts,'\n')
end
test('one ordinary portrait click lists all intent effects and all statuses without a notice',function()
 local host,ui,p,event,tap=H.setup({'strike','defend'},{'guardian'})
 local battle=host.run.combat;local enemy=battle.enemies[1]
 enemy.ai=nil;enemy.intentIndex=1;enemy.intents={{kind='defend',effects={
  {op='gainStatus',status='dexterity',value=3},{op='block',value=10},{op='damage',value=6,times=2}}}}
 for _,id in ipairs({'strength','dexterity','ritual','artifact','thorns','weak','vulnerable','frail','poison','regen','barricade'})do Combat.addStatus(enemy,id,2)end
 ui:render()
 local before=Combat.copy(battle);local notice=p:GetChild('notice').text
 tap('enemy1',91)
 local text=contents(ui,p)
 assert(text:find('自身获得 3 层敏捷',1,true) and text:find('获得 11 点格挡',1,true),'full mixed intent effects')
 assert(text:find('攻击 2 次',1,true),'mixed intent attack remains explained')
 for _,entry in ipairs(Combat.statusView(enemy))do assert(text:find(entry.name,1,true),'missing status '..entry.id)end
 assert(p:GetChild('notice').text==notice,'ordinary inspection must not write a global intent notice')
 same(battle,before)
 p:GetChild('statusInfo'):GetChild('hit').click()
 assert(not ui.info and not p:GetChild('statusInfo').visible,'blank click closes detail card')
 same(battle,before)
end)

test('target card and potion clicks retain priority over inspection',function()
 local host,ui,p,event,tap,drain=H.setup({'strike','defend'},{'cultist','jaw_worm'})
 local battle=host.run.combat;local hp=battle.enemies[2].hp
 local slot;for i,c in ipairs(battle.hand)do if c.cardId=='strike'then slot=i end end
 tap('card'..slot,92);tap('enemy2',92);drain()
 assert(battle.enemies[2].hp<hp and not ui.info,'target card click must play, not inspect')
 host.run.potions={'fire_potion'};ui:render();hp=battle.enemies[2].hp
 tap('potion1',93);dofile('tests/lua/support/confirm_potion_popup.lua')(ui,p,93);assert(ui.potionAim)
 tap('enemy2',93);drain()
 assert(battle.enemies[2].hp==hp-20 and not ui.info and #host.run.potions==0,'potion must commit once')
end)

print('APPROVED_ENEMY_DETAILS_PASS '..count)
