-- Current production integration only; every native image call is strict.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,C,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local UI,Theme,Layout=require('abyss_battle_ui'),require('abyss_theme'),require('abyss_ui_layout')
local calls=0
-- Record the same strict image boundary on the real static tree and every
-- complete actor/power template clone, without inventing static monster slots.
local function record(c)
 for _,child in pairs(c.children)do record(child)end
 local setImage=c.SetImage
 function c:SetImage(...)
  assert(select('#',...)==2,'native SetImage requires source and numeric ID')
  local source,id=...;assert(source=='static'and type(id)=='number','native SetImage cannot accept metadata tables')
  setImage(self,...);calls=calls+1
 end
 return c
end
local function control(d)return record(F.control(d))end
local function same(a,b,seen)
 if a==b then return end;assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 seen=seen or {};if seen[a]then assert(seen[a]==b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local r=Run.new(Data,'42');assert(Run.obtainRelic(r,'FossilizedHelix'));assert(Run.obtainRelic(r,'Self Forming Clay'))
assert(Run.startCombat(r,'cultist_solo'))
local root=control({name='root',size={1280,720},children=Layout})
local panel=root:GetChild('stage'):GetChild('battlePanel')
local platform=F.withMonsterActors({imageSource='static',color=function(a,b,c,d)return {r=a,g=b,b=c,a=d}end})
local instantiate=platform.monsterActors.instantiate
platform.monsterActors.instantiate=function(index,parent)return record(instantiate(index,parent))end
local ui=UI.new(panel,r.data,require('abyss_presentation'),'click',platform,{embedded=true})
ui.run=r;ui:resize(1280,720)
local function renderReadonly()
 local before=C.copy(r);local battle,player,statuses=r.combat,r.combat.player,r.combat.player.statuses
 local edges,seen={},{}
 local function capture(value)
  if seen[value]then return end;seen[value]=true
  for key,child in pairs(value)do if type(child)=='table'then edges[#edges+1]={value,key,child};capture(child)end end
 end
 capture(r)
 ui:render();same(r,before);assert(r.combat==battle and battle.player==player and player.statuses==statuses)
 for _,edge in ipairs(edges)do assert(edge[1][edge[2]]==edge[3],'render replaced a Run graph owner')end
end
local function status(id,n,icon)
 local entries=C.statusView(r.combat.player);local slot
 for i,entry in ipairs(entries)do if entry.id==id then slot=i;assert(entry.value==nil or entry.value==n);break end end
 assert(slot,'missing actual status '..id)
 local row=panel:GetChild('hero'):GetChild('statusRow')
 assert(row:GetChild('icon'..slot).visible and row:GetChild('icon'..slot).imageId==icon)
 assert(row:GetChild('count'..slot).text:find(tostring(n),1,true),'status chip hides its live number')
 local hit=row:GetChild('hit'..slot);assert(hit.listeners and hit.listeners.click);hit.listeners.click({touchId=7})
 local info=panel:GetChild('statusInfo');assert(info.visible)
 local found=false
 for i=1,Theme.layout.statusInfo.rows do
  local name,text=info:GetChild('name'..i),info:GetChild('text'..i)
  if name.visible and (name.text..text.text):find(tostring(n),1,true)then found=true end
 end
 assert(found,'tooltip hides the status count '..id)
 info:GetChild('hit').listeners.click({touchId=8});assert(not info.visible)
end
assert(r.combat.player.statuses.buffer==1);renderReadonly();status('buffer',1,102036)
renderReadonly();assert(r.combat.player.statuses.buffer==1)
local s=r.combat;local hp=s.player.hp
assert(C.damage(s,s.enemies[1],s.player,5,true)==0);assert(s.player.hp==hp and not s.player.statuses.buffer)
renderReadonly();renderReadonly();assert(not s.player.statuses.buffer,'render must not regrant a consumed Helix')
assert(C.damage(s,s.enemies[1],s.player,5,true)==5);assert(s.player.hp==hp-5)
require('abyss_card_actions').drain(C,s)
assert(s.player.statuses.next_turn_block==3,'Self Forming Clay must actually generate next-turn Block')
renderReadonly()
local nextIcon=Theme.icon.status.next_turn_block
assert((type(nextIcon)=='table'and nextIcon.id or nextIcon)==103066,'approved next-turn Block metadata is missing')
status('next_turn_block',3,103066)
assert(C.endTurn(s));assert(not s.player.statuses.next_turn_block and s.player.block>=3)
renderReadonly()
for _,enemy in ipairs(s.enemies)do enemy.hp=0 end
assert(Run.finishCombat(r));assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
assert(Run.startCombat(r,'cultist_solo'));assert(r.combat~=s and r.combat.player.statuses.buffer==1)
renderReadonly();status('buffer',1,102036);renderReadonly();assert(r.combat.player.statuses.buffer==1)
assert(calls>0)
print('RELIC_NATIVE_STATUS_ICONS_PASS strict images, real Helix/Clay lifecycle, numbered chips/tooltips, readonly render')

-- The same approved status token must also cross the actual event-playback API.
for _,definition in ipairs(Data.statuses.statuses)do
 assert(type(Theme.icon.status[definition.id])=='number','generated native status image must be numeric: '..definition.id)
end
local feedback=require('abyss_feedback').new(panel,{imageSource='static',color=function(a,b,c,d)return {r=a,g=b,b=c,a=d}end},function()ui:render()end,function()end)
local before=C.copy(r.combat)
local first=#r.combat.events+1
require('abyss_actor').applyPower(r.combat,r.combat.player,'buffer',1,r.combat.player)
assert(r.combat.player.statuses.buffer==2)
local unchanged=C.copy(r)
feedback:start(before,r.combat,first,require('abyss_presentation'))
assert(panel:GetChild('hero'):GetChild('impact').imageId==102036,'real Buffer gain playback uses the approved native image')
for _=1,1000 do if not feedback.busy then break end;feedback:update(0.1)end
assert(not feedback.busy)
same(r,unchanged);renderReadonly()
print('RELIC_NATIVE_STATUS_FEEDBACK_PASS real ApplyPower event and native playback, generated numeric status IDs')
