local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Map=require('abyss_map')
local Origin=require('abyss_card_origin')
local Names=require('abyss_relic_names')
local function same(a,b)
 if type(a)~='table' or type(b)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function snapshot(run,label)
 local cards={}
 for _,c in ipairs(run.deck)do
  cards[c.uid]=F.Combat.copy(c)
  local s=Origin.state(c)
  print('REST_ORIGIN_STATE '..label..' uid='..c.uid..' card='..c.cardId..' upgraded='..tostring(s.upgraded)..' upgrades='..s.upgrades)
 end
 return cards
end
local function details(h,root)
 assert(h:openDeck());h:update(0)
 local panel=root:GetChild('deckPanel');local grid=panel:GetChild('grid')
 local texts={}
 for i,c in ipairs(h.deckUI.cards)do
  local item=grid:recycle(0,i-1)
  item:GetChild('hit').click()
  texts[c.uid]=panel:GetChild('details').text
  assert(h.deckUI:back())
  h:update(0)
 end
 assert(h:closeDeck())
 return texts
end
for _,mixed in ipairs({false,true})do
 local h,root=F.fixture();assert(F.start(h))
 local run=h.run
 if mixed then
  local initialCount=#run.deck
  snapshot(run,'before-obtain')
  assert(Run.obtainRelic(run,'toxic_egg'))
  local ok,uid=Run.obtainCard(run,'defend');assert(ok)
  local egg=run.deck[#run.deck];local eggOrigin=assert(egg.lastUpgradeOrigin)
  assert(egg.uid==uid and eggOrigin.uid==uid and eggOrigin.source.relicId=='toxic_egg')
  assert(eggOrigin.kind=='obtained_upgraded' and not eggOrigin.before.upgraded and eggOrigin.before.upgrades==0)
  assert(eggOrigin.after.upgraded and eggOrigin.after.upgrades==1 and Origin.matches(egg,eggOrigin))
  local beforeHouse=snapshot(run,'before-tiny-house')
  assert(Run.obtainRelic(run,'tiny_house'))
  local houseCount=0
  for _,c in ipairs(run.deck)do
   local previous=assert(beforeHouse[c.uid])
   if not same(Origin.state(c),Origin.state(previous))then
    houseCount=houseCount+1;local o=assert(c.lastUpgradeOrigin)
    assert(o.uid==c.uid and o.source.relicId=='tiny_house' and not previous.upgraded)
    assert(same(o.before,Origin.state(previous)) and same(o.after,Origin.state(c)) and o.after.upgrades==1)
   end
  end
  assert(houseCount==1)
  snapshot(run,'after-tiny-house')
  assert(require('abyss_boss_relics').claim(run,'done'))
  for _,spec in ipairs({{'war_paint','skill'},{'whetstone','attack'}})do
   local old=snapshot(run,'before-'..spec[1]);assert(Run.obtainRelic(run,spec[1]))
   local count=0
   for _,c in ipairs(run.deck)do
    local previous=assert(old[c.uid])
    if not same(Origin.state(c),Origin.state(previous))then
     count=count+1
     local def;for _,d in ipairs(run.data.cards.cards)do if d.id==c.cardId then def=d end end
     assert(def.type==spec[2] and not previous.upgraded and Origin.state(c).upgrades==1)
     local o=assert(c.lastUpgradeOrigin)
     assert(o.uid==c.uid and o.source.relicId==spec[1] and same(o.before,Origin.state(previous)) and same(o.after,Origin.state(c)))
    end
   end
   assert(count==2,'equipment must upgrade exactly two eligible cards on actual obtain')
   snapshot(run,'after-'..spec[1])
   local saved=F.Combat.copy(run)
   assert(not Run.obtainRelic(run,spec[1]));assert(same(saved,run),'duplicate obtain reapplied upgrade')
  end
  assert(#run.deck==initialCount+1)
 end
 -- Controlled pre-camp snapshot: replay legal map choices to a generated camp,
 -- without simulating intervening rooms. Never rewrite the source graph. This
 -- is neither a natural playthrough nor an official client/device run.
 local camp
 for _=1,15 do
  local available=Map.available(h.map)
  for _,node in ipairs(available)do if node.type=='camp' then camp=node;break end end
  if camp then break end
  assert(Map.choose(h.map,available[1].id))
 end
 assert(camp);run.floor=h.map.floor
 assert(F.Nodes.enter(run,h.map,camp.id))
 h:refresh();h:update(1)
 assert(Run.obtainRelic(run,'regal_pillow')) -- healing effect cannot upgrade cards
 run.hp=10
 local before=snapshot(run,mixed and 'mixed-before-rest' or 'plain-before-rest')
 local original=F.Combat.copy(run);local texts=details(h,root)
 assert(same(original,run))
 assert(h.nodeUI:press('campView/rest'))
 assert(run.phase=='map' and run.nodeFlow.campChoice=='rest' and run.nodeFlow.complete and run.hp>10)
 local after=snapshot(run,mixed and 'mixed-after-rest' or 'plain-after-rest')
 assert(same(before,after),'rest changed permanent UID, upgrade state or existing provenance')
 assert(same(original.lastRelicObtain,run.lastRelicObtain),'rest manufactured an acquisition receipt')
 local postRest=F.Combat.copy(run);local afterTexts=details(h,root)
 assert(same(texts,afterTexts) and same(postRest,run),'details changed source or mutated Run after rest')
 local sources={}
 for _,c in ipairs(run.deck)do
  local o=c.lastUpgradeOrigin
  if o then
   assert(Origin.matches(c,o));assert(o.source.kind=='relic','rest must not invent a camp upgrade source')
   sources[o.source.relicId]=true
   assert(afterTexts[c.uid]:find(Names.get(run.data,o.source.relicId),1,true),'detail lost actual source')
   assert(afterTexts[c.uid]:find(o.kind=='obtained_upgraded' and '获得时已升级' or '永久升级',1,true))
  else
   assert(not c.upgraded and not afterTexts[c.uid]:find('来源：',1,true),'rest invented provenance for unchanged card')
  end
 end
 if mixed then for _,id in ipairs({'toxic_egg','tiny_house','war_paint','whetstone'})do assert(sources[id],'missing distinct source '..id)end end
 assert(not h.nodeUI:press('campView/rest'))
 assert(same(postRest,run),'repeated rest changed completed room')
end
print('CAMP_REST_UPGRADE_ORIGINS_PASS 2')
