-- Offline generated controls only. Staged actors/statuses are not a natural run.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,D,T,V=H.F.Combat,H.F.Data,H.F.Theme,require('abyss_battle_intent_view')
local host,ui,panel,_,tap,_,_,root=H.setup({'strike','defend'},{'cultist'})
-- This existing host mock tracks runtime moves, but leaves initial native
-- positions unset. Resolve those from the actual generated tree, never zero
-- out a position already written by the production controller.
local function initialPositions(parent,definitions)
 for _,spec in ipairs(definitions)do
  local box=assert(parent:GetChild(spec.name))
  if box.x==nil then box.x,box.y=(spec.position or {0,0})[1],(spec.position or {0,0})[2]end
  if spec.text then box.declaredFont=spec.text.fontSize;box.minimumFont=spec.text.minFontSize end
  initialPositions(box,spec.children or {})
 end
end
for _,spec in ipairs(H.F.Layout)do if spec.name=='stage'then initialPositions(root,spec.children)end end
local notice=panel:GetChild('notice')
local function overlaps(a,ax,ay,b,bx,by,sx,sy)
 return math.abs(ax-bx)<(a.sizeDeltaX+b.sizeDeltaX*(sx or 1))/2 and math.abs(ay-by)<(a.sizeDeltaY+b.sizeDeltaY*(sy or 1))/2
end
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b);return end
 for key,value in pairs(a)do same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil)end
end
-- Same full-width glyph/1.35 leading bound as the existing offline renderer.
-- Both controls are centre-aligned; transparent native textbox padding is not ink.
local function inkFrame(box)
 local function rows(font)
  local count=0;local columns=math.max(1,math.floor(box.sizeDeltaX/font))
  for line in (box.text..'\n'):gmatch('(.-)\n')do count=count+math.max(1,math.ceil(utf8.len(line)/columns))end
  return count
 end
 local font=assert(box.declaredFont)
 while font>box.minimumFont and rows(font)*font*1.35>box.sizeDeltaY do font=font-1 end
 return {sizeDeltaX=box.sizeDeltaX,sizeDeltaY=rows(font)*font*1.35}
end
local function leaves(box,x,y,check,sx,sy)
 if not box.visible then return end
 sx,sy=sx or 1,sy or 1
 x,y=x+(box.x or 0)*sx,y+(box.y or 0)*sy
 sx,sy=sx*(box.localScaleX or 1),sy*(box.localScaleY or 1)
 if box.kind~='container' and box.sizeDeltaX and box.sizeDeltaY then check(box,x,y,sx,sy)end
 for _,child in pairs(box.children)do leaves(child,x,y,check,sx,sy)end
end
local cases={{'cultist'},{'cultist','cultist'},{'cultist','cultist','cultist'},
 {'cultist','cultist','cultist','cultist'},{'cultist','cultist','cultist','cultist','cultist'},
 {'guardian'},{'guardian','cultist','sentry','red_louse','jaw_worm'}}
local old={sizeDeltaX=1080,sizeDeltaY=32}
local oldCollisions=0
for case,ids in ipairs(cases)do
 local s=C.new(D,{deck={'strike','defend'},enemies=ids,seed=42})
 host.run.combat=s;host.run.potions={'fire_potion','fire_potion','fire_potion'}
 C.addStatus(s.player,'strength',2);C.addStatus(s.player,'weak',1)
 for _,enemy in ipairs(s.enemies)do C.addStatus(enemy,'strength',2);C.addStatus(enemy,'weak',1)end
 host:refresh();local before=C.copy(s)
 local function inspect()
  for _,name in ipairs({'hero','enemy1','enemy2','enemy3','enemy4','enemy5','card1','card2','potion1','potion2','potion3'})do
   leaves(assert(panel:GetChild(name)),0,0,function(box,x,y,sx,sy)
    assert(not overlaps(notice,notice.x,notice.y,box,x,y,sx,sy),'notice overlaps '..name..'/'..box.name)
    if name:match('^enemy') and box.name=='intentIcon' and overlaps(old,0,228,box,x,y)then oldCollisions=oldCollisions+1 end
   end)
  end
 end
 tap('enemy1',case*10);assert(notice.visible and notice.text~='');inspect()
 tap('card1',case*10+1)
 assert(ui.selected==s.hand[1].uid)
 for _=1,80 do host:update(1/60)end
 inspect();tap('card1',case*10+2);assert(ui.selected==nil)
 local hit=panel:GetChild('enemy1'):GetChild('intentHit')
 hit.click({touchId=case*10+3});assert(panel:GetChild('statusInfo').visible and ui.info.kind=='intent')
 panel:GetChild('statusInfo'):GetChild('hit').click({touchId=case*10+4})
 assert(not panel:GetChild('statusInfo').visible)
 assert(ui:showStatus(0));assert(panel:GetChild('statusInfo'):GetChild('name1').text=='力量 2')
 panel:GetChild('statusInfo'):GetChild('hit').click({touchId=case*10+5})
 same(s,before)
end
assert(oldCollisions>0,'the old full-width notice must reproduce the real overlap')
-- A floating number has an intentionally padded 80-high native text box.
-- Check its visible numeric ink at the existing preview's conservative leading,
-- not that transparent padding; HP/status/intent controls above remain strict.
local heal=C.new(D,{deck={'strike'},enemies={'cultist'},seed=42})
heal.player.hp=40;host.run.combat=heal;host.run.hp=40;host.run.potions={'blood_potion'};host:refresh()
tap('potion1',2001)
assert(ui.busy and notice.visible and notice.text=='药水已生效。')
local healedFrames=0
for _=1,120 do
 leaves(panel:GetChild('hero'),0,0,function(box,x,y,sx,sy)
  if box.name=='floating' then
   assert(box.declaredFont==T.font.number,'generated floating font drift')
   assert(not overlaps(inkFrame(notice),notice.x,notice.y,inkFrame(box),x,y,sx,sy),'notice overlaps healing-number ink')
   healedFrames=healedFrames+1
  end
 end)
 host:update(1/60)
 if not ui.busy then break end
end
assert(healedFrames>0 and not ui.busy and heal.player.hp==56 and #host.run.potions==0)
-- Source Fat Gremlin + Artifact produces a real two-line blocked-status float
-- while feedback replaces the prior intent with its real acting-enemy notice.
local artifact=C.new(D,{deck={'strike'},enemies={'fat_gremlin'},seed=42})
C.addStatus(artifact.player,'artifact',1)
host.run.combat=artifact;host.run.hp=artifact.player.hp;host.run.potions={};host:refresh()
tap('enemy1',2101);local priorNotice=notice.text;assert(priorNotice~='')
tap('endTurn',2102);local blockedFrames=0
for _=1,1200 do
 leaves(panel:GetChild('hero'),0,0,function(box,x,y,sx,sy)
  if box.name=='floating' and box.text:find('人工制品抵挡\n',1,true)then
   assert(notice.visible and notice.text==artifact.enemies[1].name..' · 正在行动')
   assert(not overlaps(inkFrame(notice),notice.x,notice.y,inkFrame(box),x,y,sx,sy),'notice overlaps two-line Artifact ink')
   blockedFrames=blockedFrames+1
  end
 end)
 host:update(1/60)
 if not ui.busy then break end
end
assert(blockedFrames>0 and not ui.busy and artifact.player.statuses.artifact==0)
assert((artifact.player.statuses.weak or 0)==0)
-- Survey every declared source intent through the production read-only projection.
-- The longest uses the real potion-target prefix, then is emitted by the real UI.
local function sourceBattle(id)
 local members=id=='gremlin_leader' and {'mad_gremlin','sneaky_gremlin',id}
  or id=='bronze_orb' and {'automaton',id} or {id}
 return C.new(D,{enemies=members,seed=42}),#members
end
local longest={length=0};local samples=0
local registered=C.new(D,{enemies={'cultist'},seed=42}).catalog.enemies
local ids={};for id in pairs(registered)do ids[#ids+1]=id end;table.sort(ids)
for _,id in ipairs(ids)do
 local definition=registered[id]
 local s,target=sourceBattle(definition.id)
 local enemy=s.enemies[target]
 for index,intent in ipairs(enemy.intents)do
  enemy.intentIndex=index
  local text='药水目标：'..enemy.name..'；意图：'..V.intentView(s,target).text
  print('BATTLE_NOTICE_TEXT\t'..text:gsub('\n','\\n'));samples=samples+1
  if utf8.len(text)>longest.length then longest={length=utf8.len(text),id=definition.id,index=index,text=text}end
 end
end
local s,target=sourceBattle(longest.id);s.enemies[target].intentIndex=longest.index
host.run.combat=s;host.run.potions={'fire_potion'};host:refresh();tap('enemy'..target,1001)
assert(notice.text==longest.text,'the measured longest notice must come from the real controller')
print('BATTLE_NOTICE_LAYOUT_PASS '..#cases..' '..samples..' '..longest.length..' '..longest.id)
