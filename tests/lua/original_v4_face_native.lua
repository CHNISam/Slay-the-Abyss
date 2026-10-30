local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Display=require('abyss_card_display')
local Presentation=require('abyss_character_presentation')
local Run=require('abyss_run')
local Card=require('abyss_original_v4_data')
local function located(spec)
 local function position(control,source)
  control.x,control.y=(source.position or {0,0})[1],(source.position or {0,0})[2]
  for _,child in ipairs(source.children or {})do position(control:GetChild(child.name),child)end
 end
 local control=F.control(spec);position(control,spec);return control
end
local canvas=located({children=F.Layout})
local root=F.Viewport.apply(canvas,1280,720)
local library=located(require('abyss_ui_templates').AbyssDeckCard):GetChild('face')
local faces={root:GetChild('battlePanel'):GetChild('card1'),library,root:GetChild('nodePanel'):GetChild('shopView'):GetChild('card1')}
local function geometry(face,body,id)
 local kind=face:GetChild('type')
 local typeBottom=kind.y-(kind.fontSize or F.Theme.font.small)/2
 assert(body.y+body.sizeDeltaY/2<=typeBottom-1,id..': body overlaps actual type glyph')
 assert(body.y-body.sizeDeltaY/2>=-F.Theme.layout.card.size[2]/2+F.Theme.space.border,id..': body leaves inner frame')
end
local compact,total=0,0
for _,raw in ipairs(Card.cards)do if raw.role=='RD' then for _,up in ipairs({false,true})do
 local text=Display.permanentText({},{originalV4=raw},{upgraded=up})
 for i,face in ipairs(faces)do
  local body=face:GetChild(i==3 and 'description' or 'label')
  assert(Display.writeBody(body,text,face),raw.id)
  assert(body.fontSize>=14 and body.text==text)
  assert(body.sizeDeltaX==132 and (body.sizeDeltaY==92 or body.sizeDeltaY==116))
  geometry(face,body,raw.id..' context '..i)
  if body.sizeDeltaY==116 then
   assert(body.y+body.sizeDeltaY/2<face:GetChild('type').y-7,raw.id..': rules overlap type')
   assert(body.y-body.sizeDeltaY/2>-F.Theme.layout.card.size[2]/2+2,raw.id..': rules leave card')
   if i==1 then compact=compact+1 end
  end
 end
 total=total+1
end end end
assert(total==150)
-- Recycled long faces restore their full art geometry on a short card.
local longCard;for _,raw in ipairs(Card.cards)do if raw.id=='RD2-060'then longCard=raw end end
local long=Display.combatText({},{originalV4=longCard},{},{{op='damage',actual=99},{op='block',low=99}})
local text=Display.permanentText({},{originalV4=Card.cards[226]}, {})
for i,face in ipairs(faces)do
 local original=face.GetChild
 local deadLookups=0
 local dead={alive=false,SetAnchoredPosition=function()error('setter called on a dead optional image')end,
  SetSizeDelta=function()error('resize called on a dead optional image')end,
  SetLocalScale=function()error('scale called on a dead optional image')end}
 face.GetChild=function(control,name)
  local part=original(control,name)
  if not part and (name=='art' or name:match('^art_'))then deadLookups=deadLookups+1;return dead end
  return part
 end
 local body=face:GetChild(i==3 and 'description' or 'label')
 assert(Display.writeBody(body,long,face))
 assert(body.sizeDeltaY==116)
 geometry(face,body,'long context '..i)
 assert(Display.writeBody(body,text,face))
 assert(body.sizeDeltaY==92)
 geometry(face,body,'recycled short context '..i)
 assert(face:GetChild('skin'):GetChild('attack').localScaleY==1)
 if i~=3 then assert(deadLookups>0,'dead-handle optional lookup was not exercised')end
 face.GetChild=original
end
do
 local body={SetSizeDelta=function()end,SetAnchoredPosition=function()end}
 local missing={GetChild=function(_,name)if name=='skin'then error('missing required skin')end end}
 local ok,why=pcall(Display.writeBody,body,long,missing)
 assert(not ok and tostring(why):find('missing required skin',1,true),'missing required controls were silently swallowed')
end

local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorDrag='drag',CursorEndDrag='endDrag'}
local ui,liveRoot=F.fixture(nil,nil,nil,cursor)
assert(F.start(ui,'raiden'))
local run=ui.run
local presentation=Presentation.prepare(F.Presentation,run.data)
assert(Run.startCombat(run,'cultist_solo'))
ui:refresh()
for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
assert(Run.finishCombat(run))
run.rewards.cards={'RD2-003'};run.rewards.cardUpgrades={true}
ui:refresh()
local battle=ui.battleUI;battle.rewardScreen='cards';battle:render()
local old=battle:cardHelpSpec(1)
assert(old.kind=='rewardCard' and old.cardId=='RD2-003' and old.upgraded)
assert(battle:openHelp(old,nil,true))
assert(battle.info and liveRoot:GetChild('battlePanel'):GetChild('statusInfo').visible)
local pages=battle.info.pages
assert(pages and pages>0,'gold keyword definitions must be reachable in reward mode')
assert(not run.rewards.cardResolved and #run.deck==10)
assert(battle:controllerBack())
local hit=liveRoot:GetChild('battlePanel'):GetChild('card1'):GetChild('hit')
hit.listeners.enter();battle:update(F.Theme.layout.statusInfo.delay)
assert(battle.info and battle.info.kind=='rewardCard','real reward hover did not open keyword definitions')
assert(liveRoot:GetChild('battlePanel'):GetChild('statusInfo'):GetChild('title').text==presentation['RD2-003'].name)
hit.listeners.exit()
assert(not battle.info)
hit.listeners.down({touchId=47});battle:update(F.Theme.layout.statusInfo.delay)
assert(battle.info and battle.info.kind=='rewardCard','real reward hold did not open keyword definitions')
hit.listeners.up({touchId=47});hit.click({touchId=47})
assert(not run.rewards.cardResolved and #run.deck==10,'holding keyword definitions accidentally claimed a card')
if battle.info then assert(battle:controllerBack())end
assert(battle:controllerBack())
assert(not battle.info and not battle:openHelp(old,nil,true),'old hover survived leaving selection')
F.click(liveRoot,'battlePanel','cardReward')
assert(not battle:openHelp(old,nil,true),'old hover survived reward epoch')
-- Real source snapshot, not damage-result inference, drives conditional colour.
local definition
for _,d in ipairs(run.data.cards.cards)do if d.id=='RD2-005'then definition=d end end
local instance={cardId='RD2-005'}
local off=Display.combatText(presentation['RD2-005'],definition,instance,{},run.combat,1)
run.combat.originalV4.musou={uses=1,ends=1}
local on=Display.combatText(presentation['RD2-005'],definition,instance,{},run.combat,1)
assert(off~=on and off:find('梦想一心',1,true) and on:find('获得2格挡',1,true))
do
 local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
 local host,view,panel,emit=H.setup()
 local live=Run.new(F.Data,1,{character='raiden'})
 live.deck={{uid=1,cardId='RD2-001'}}
 assert(Run.startCombat(live,'cultist_solo'))
 host.run=live;view.run=live;view:setData(live.data,Presentation.prepare(F.Presentation,live.data));host:refresh()
 local enemy=monsterControl(panel,'enemy1')
 emit('card1','down',81);emit('card1','drag',81,enemy.x,enemy.y)
 assert(view.gesture and view.gesture.moving)
 local instance=live.combat.hand[1]
 local function actual()
  local sum=0;for _,e in ipairs(F.Combat.cardPreview(live.combat,instance,1))do sum=sum+(e.actual or 0)end;return sum
 end
 F.Combat.addStatus(live.combat.player,'strength',3);view:render()
 local text=panel:GetChild('card1'):GetChild('label').text
 assert(text:find(tostring(actual())..'↑',1,true) and text:find('<color=',1,true))
 F.Combat.addStatus(live.combat.player,'weak',1);view:render()
 text=panel:GetChild('card1'):GetChild('label').text:gsub('<[^>]+>','')
 assert(text:find('扣血'..actual(),1,true))
 F.Combat.addStatus(live.combat.enemies[1],'vulnerable',1);view:render()
 text=panel:GetChild('card1'):GetChild('label').text:gsub('<[^>]+>','')
 assert(text:find('扣血'..actual(),1,true))
 assert(live.combat.energy==3 and live.combat.enemies[1].hp==live.combat.enemies[1].maxHp,'read-only aiming changed combat')
end
print('ORIGINAL_V4_FACE_NATIVE_PASS 150 '..compact..' compact; reward help stale ownership; real conditional snapshot and Strength Weak Vulnerable aiming')
