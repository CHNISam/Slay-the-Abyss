-- A complete production Host runs in each independent VM. No historical projection.
local events, count={},0
local normalizeError=dofile('tests/lua/support/game_ui_host_errors.lua')
if ABYSS_HOST_FULL_TRACE then assert(type(ABYSS_HOST_GRAPH)=='function','full trace requires native graph observer')end
ABYSS_HOST_FIELDS={}
local nativeControls={}
local hosts={}
local function graph(value,stable)
 return assert(ABYSS_HOST_GRAPH,'full trace requires native graph observer')(value,{},stable)
end
local function record(...)
 if not ABYSS_HOST_FULL_TRACE then return end
 if count+1<(ABYSS_HOST_FROM or 1) or count+1>(ABYSS_HOST_TO or 35) then return end
 events[#events+1]=assert(ABYSS_HOST_GRAPH_EVENT)(...)
end
-- The fixture invokes this after inert construction. Remove ALL raw fields so
-- repeated direct writes pass through __newindex, including existing properties.
ABYSS_HOST_CONTROL=function(control)
 local original=getmetatable(control);local fields,wrappers={},{}
 for k,v in pairs(control)do fields[k]=v end
 ABYSS_HOST_FIELDS[control]=fields
 nativeControls[#nativeControls+1]=control
 if ABYSS_HOST_GRAPH_CONTROL then ABYSS_HOST_GRAPH_CONTROL(control,fields)end
 for k in pairs(fields)do rawset(control,k,nil)end
 local function path()
  local out={fields.name or 'canvas'};local p=fields.parent
  while p do table.insert(out,1,p.name or 'canvas');p=p.parent end
  return table.concat(out,'/')
 end
 setmetatable(control,{
  __pairs=function()return next,fields,nil end,
  __index=function(_,key)
   assert(key~='interactable' or fields.kind~='cursorArea','cursor interactable')
   local value=fields[key]
   if value==nil then value=original.__index(control,key) end
   if type(value)~='function' then return value end
   if key=='GetChild' or key=='GetChildren' then return value end
   if not wrappers[key] then wrappers[key]=function(receiver,...)
    record('native',control,path(),key,select('#',...),...)
    return value(receiver,...)
   end end
   return wrappers[key]
  end,
  __newindex=function(_,key,value)
   assert(key~='alive' and key~='activeInHierarchy','read-only native property')
   assert(key~='interactable' or fields.kind~='cursorArea','cursor interactable')
   record('write',control,path(),key,value);fields[key]=value;wrappers[key]=nil
  end})
end
local F=dofile('tests/lua/support/game_ui_fixture.lua')
do
 local box=F.control({name='savedSetterProbe'});local saved=box.SetVisible;local calls=0
 box.SetVisible=function(...)calls=calls+1;return saved(...)end
 box:SetVisible(false)
 assert(calls==1 and box.visible==false,'replacement must invoke saved setter exactly once')
end
if ABYSS_HOST_FULL_TRACE then
 local sources={data=F.Data,presentation=F.Presentation}
 if ABYSS_HOST_GRAPH_WRITE then ABYSS_HOST_GRAPH_WRITE(sources,'HOST_SOURCES')
 else print('HOST_SOURCES '..graph(sources))end
end
local function checkpoint(label,host,fn)
 if ABYSS_HOST_TO and count>=ABYSS_HOST_TO then
  print('GAME_UI_HOST_TRACE_PASS checkpoints='..ABYSS_HOST_TOTAL)
  print('HOST_WINDOW_DONE executed='..count)
  coroutine.yield('HOST_WINDOW_DONE')
 end
 if ABYSS_HOST_FULL_TRACE then io.stderr:write('HOST_PROGRESS start '..(count+1)..' '..label..'\n')end
 local result=table.pack(pcall(fn or function()end))
 -- Normalize only source coordinates, retaining the error text and return arity.
 if not result[1] then result[2]=normalizeError(result[2])end
 count=count+1
 ABYSS_HOST_EXECUTED=count
 if ABYSS_HOST_FULL_TRACE then io.stderr:write('HOST_PROGRESS done '..count..' '..label..'\n')end
 if count<(ABYSS_HOST_FROM or 1) or count>(ABYSS_HOST_TO or 35) then events={};return table.unpack(result,1,result.n)end
 if ABYSS_HOST_FULL_TRACE then
  local frame={label=label,result=result,state={host=host,hosts=hosts,data=F.Data,presentation=F.Presentation,native=nativeControls}}
  if ABYSS_HOST_GRAPH_WRITE then
   print('HOST_EVENTS ['..table.concat(events,',')..']');ABYSS_HOST_GRAPH_WRITE(frame,'HOST_TRACE',true)
  else
   local line=graph(frame,true)
   print('HOST_EVENTS ['..table.concat(events,',')..']');print('HOST_TRACE '..line)
  end
 end
 events={}
 return table.unpack(result,1,result.n)
end
local host,root
local variant=ABYSS_HOST_CONSTRUCTOR or ''
local platform={seed=ABYSS_HOST_SEED or 1,nativeMonsterArtEnabled=false,imageSource='static',
 cursorEvents={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='enddrag'},
 color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end}
local focus
platform.controllerApi={events={Confirm='confirm',Cancel='cancel',Focus='focus'},
 directions={Left='left',Right='right'},modes={Specified='specified'},
 getFocus=function()return focus end,setFocus=function(value)focus=value;record('focus',value)end,
 isController=function()return false end}
if variant=='short-clock' then
 platform.seed=nil;platform.newSeed=function()
  record('newSeed',host:confirmCharacter());return '-9223372036854775808'
 end
elseif variant=='short-wide' then platform.seed='9223372036854775807'
elseif variant=='short-full-source' then platform.campaignProfile='full-source' end
if variant=='short-chapters' then platform.campaign=true;platform.campaignProfile='competition-two-act' end
if variant=='short-egg' then
 platform.createEasterEggArt=function()
  record('create egg art');local attempts=0
  return {sync=function(...)record('egg sync',...)end,tick=function(...)record('egg tick',...)end,
   status=function()return {phase='ready'}end,
   release=function(...)attempts=attempts+1;record('egg release',attempts,...);return attempts>1,'injected egg release failure'end}
 end
end
local function setup()
 local canvas=F.control({children=F.Layout});local root=F.Viewport.apply(canvas,1280,720)
 local made=F.GameUI.new(root,F.Data,F.Presentation,'click',platform)
 hosts[#hosts+1]=made
 return made,root
end
if variant~='' and variant:sub(1,6)~='short-' then
 local kind=ABYSS_HOST_CONSTRUCTOR
 local module=({deck='abyss_deck_ui',battle='abyss_battle_ui',map='abyss_map_ui',node='abyss_node_ui',potion='abyss_potion_discard_ui',egg='abyss_victory_easter_egg'})[kind]
 local dependency=require(module);local constructor=dependency.new
 dependency.new=function(...)
  local args=table.pack(...);record('constructor callback',kind)
  if kind=='deck' then record('callback result',args[5]())
  elseif kind=='battle' then record('callback result',args[7].onChange())
  elseif kind=='map' then record('callback result',args[3]({id='injected'}))
  elseif kind=='node' then record('callback result',args[7].onInspectCard({},false))
  elseif kind=='potion' then record('canManage callback result',args[4](nil));record('close callback result',args[6]())
  elseif kind=='egg' then record('callback result',args[2].onVisibility(true))end
  return constructor(table.unpack(args,1,args.n))
 end
 checkpoint('synchronous '..kind,nil,function()setup();return true end)
 print('GAME_UI_HOST_TRACE_PASS checkpoints=1')
 return
end
checkpoint('construct',nil,function()host,root=setup();return true end)
assert(host,'Host construction failed')
local function step(label,fn)return checkpoint(label,host,fn)end
local function button(panel,...)
 local box=root:GetChild(panel)
 for _,name in ipairs({...})do box=assert(box:GetChild(name),name)end
 return box.click and box or assert(box:GetChild('hit'))
end
local function pointer(box,event,id)return assert(box.listeners[event])(id and {touchId=id} or nil)end
if variant:sub(1,6)=='short-' then
 step('start',function()if variant=='short-route' then assert(host:setFastMode(true))end;return host:start()end)
 step('select',function()return host:selectCharacter('traveler')end)
 step('element',function()return host:selectElement('ironclad')end)
 local Map=require('abyss_map');local generate=Map.generate
 if variant=='short-map-failure' then
  local thrown={kind='injected Map.generate failure'}
  Map.generate=function()record('map error identity',thrown);error(thrown)end
 end
 step('confirm',function()return host:confirmCharacter()end)
 Map.generate=generate
 if variant=='short-disable-live' then
  step('real active combat with pending playback',function()
   assert(require('abyss_run').startCombat(host.run,'cultist_solo'));host:refresh()
   local result=button('battlePanel','endTurn').click()
   assert(host.battleUI.active and host.battleUI.busy,'requires real active pending playback')
   return result
  end)
  assert(host.battleUI.active and host.battleUI.busy,'disable fixture must still be active')
  local cancel,called=host.battleUI.feedback.cancel,false
  host.battleUI.feedback.cancel=function(...)
   called=true
   local inert=host.disabled and host.battleUI.active==false
    and root:GetChild('mapPanel').visible==false and root:GetChild('nodePanel').visible==false
   record('live cancel inert',inert,host.disabled,host.battleUI.active)
   assert(inert,'HOST_CANCEL_MUST_BE_INERT')
   record('live cancel synchronous refresh',host:refresh())
   return cancel(...)
  end
  local ok,accepted=step('disable live playback',function()return host:disable()end)
  assert(called,'live cancellation hook must execute')
  if ok then assert(accepted==true);print('HOST_DISABLE_LIVE_INERT_PASS')
  else assert(type(accepted)=='string' and accepted:find('HOST_CANCEL_MUST_BE_INERT',1,true),'unexpected disable failure')end
  print('GAME_UI_HOST_TRACE_PASS checkpoints='..count);return
 elseif variant=='short-route' then
  local Run=require('abyss_run')
  step('real map entry',function()return host.mapUI:choose(F.Nodes.available(host.run,host.map)[1].id)end)
  assert(host.run.phase=='combat' and host.mode=='battle')
  step('native end turn and playback',function()
   local result=button('battlePanel','endTurn').click()
   for _=1,400 do if not host.battleUI.busy then break end;host:update(.05)end
   assert(not host.battleUI.busy);return result
  end)
  -- A common terminal-combat fixture, matching the existing reward regressions.
  -- Production balance is unchanged; only the Host transition is under test.
  step('terminal combat fixture and real reward creation',function()
   for _,enemy in ipairs(host.run.combat.enemies)do enemy.hp=0 end
   local ok,why=Run.finishCombat(host.run);host:refresh();return ok,why
  end)
  assert(host.run.phase=='reward')
  step('native reward proceed',function()return button('battlePanel','continue').click()end)
  assert(host.run.phase=='map' and host.run.pendingCombatRewards)
  local reward=button('combatRewards')
  step('reward down',function()return pointer(reward,'down',4)end)
  step('reward up',function()return pointer(reward,'up',4)end)
  step('same-content replacement pending owner',function()
   local old=host.run.pendingCombatRewards
   host.run.pendingCombatRewards={rewards=old.rewards,combat=old.combat,flow=old.flow};host:refresh()
  end)
  local ok,value=step('stale reward owner click',function()return pointer(reward,'click',4)end)
  assert(ok and value==false,'stale pending owner must be rejected')
  step('fresh reward down',function()return pointer(reward,'down',5)end)
  step('fresh reward up',function()return pointer(reward,'up',5)end)
  step('fresh reward reopen',function()return pointer(reward,'click',5)end)
  assert(host.run.phase=='reward')
  step('native reward proceed again',function()return button('battlePanel','continue').click()end)
  step('disable',function()return host:disable()end)
  print('GAME_UI_HOST_TRACE_PASS checkpoints='..count);return
 elseif variant=='short-chapters' then
  local run,map=host.run,host.map
  local function terminalTreasure()
   while #Map.available(map)>0 do assert(Map.choose(map,Map.available(map)[1].id))end
   local floor=require('abyss_acts').get(run.act).last
   run.floor,run.phase=floor,'node'
   run.nodeFlow={id=map.currentNodeId,floor=floor,type='treasure',roomKind='boss_treasure',
    mapSeed=map.seed,mapSignature=map.sourceSignature,complete=false,reward={relics={}}}
   host:refresh()
  end
  step('controlled chapter one terminal treasure',terminalTreasure)
  step('real chapter one treasure claim',function()local ok,why=F.Nodes.claimBossTreasure(run,0);host:refresh();return ok,why end)
  assert(run.phase=='act_transition')
  step('native chapter continue',function()return host.nodeUI:press('confirm')end)
  assert(host.run==run and host.map==map and run.act==2 and run.phase=='map')
  step('controlled chapter two terminal treasure',terminalTreasure)
  step('real chapter two ending',function()local ok,why=F.Nodes.claimBossTreasure(run,0);host:refresh();return ok,why end)
  assert(run.phase=='victory' and host.mode=='victory')
  step('disable',function()return host:disable()end)
  print('GAME_UI_HOST_TRACE_PASS checkpoints='..count);return
 end
 if variant=='short-overlays' then
  step('combat',function()local ok,why=require('abyss_run').startCombat(host.run,'cultist_solo');host:refresh();return ok,why end)
  step('menu',function()return host:openMenu()end)
  step('help',function()return button('runMenu','help').click()end)
  step('close help',function()return host:closeExit()end)
  step('route',function()return button('runMenu','map').click()end)
  step('close route',function()return host:closeExit()end)
  step('resume',function()return host:closeExit()end)
  step('disable',function()return host:disable()end)
  print('GAME_UI_HOST_TRACE_PASS checkpoints='..count);return
 elseif variant=='short-egg' then
  step('victory',function()host.run.phase='victory';host.motion.deathReveal=nil;host:refresh()end)
  step('egg open',function()return host.easterEgg:open()end)
  step('egg update',function()return host:update(.1)end)
  step('egg close',function()return host.easterEgg:close()end)
  step('egg cleanup failure',function()return host:disable()end)
  step('egg cleanup retry',function()return host:disable()end)
  print('GAME_UI_HOST_TRACE_PASS checkpoints='..count);return
 end
 if variant=='short-map-failure' then step('confirm retry',function()return host:confirmCharacter()end)
 elseif variant=='short-refresh-reentry' then
  local panel=root:GetChild('menuPanel');local visible=panel.SetVisible;local once=false
  panel.SetVisible=function(...)
   if not once then once=true;record('native reentry');host.run=nil;host.mode='menu' end
   return visible(...)
  end
  step('refresh mixed capture',function()return host:refresh()end)
  assert(once,'native setter reentry must execute')
 else step('refresh',function()return host:refresh()end)end
 step('disable',function()return host:disable()end)
 print('GAME_UI_HOST_TRACE_PASS checkpoints='..count);return
end
step('refresh',function()return host:refresh()end)
local start=button('menuPanel','start')
step('pointer down',function()return pointer(start,'down',1)end)
step('foreign up',function()return pointer(start,'up',2)end)
step('foreign click',function()return pointer(start,'click',2)end)
step('pointer up',function()return pointer(start,'up',1)end)
step('start click',function()return pointer(start,'click',1)end)
step('close selection',function()return host:closeCharacters()end)
step('stale click',function()return pointer(start,'click',1)end)
step('start',function()return host:start()end)
step('select',function()return host:selectCharacter('traveler')end)
step('element',function()return host:selectElement('ironclad')end)
step('confirm',function()return host:confirmCharacter()end)
assert(host.run,'Host start failed')
step('deck',function()return host:openDeck()end)
step('deck close',function()return host:closeDeck()end)
step('resize',function()return host:resize(1280,720)end)
step('invalid dt',function()return host:update(0/0)end)
step('update',function()return host:update(.05)end)
step('open menu',function()return host:openMenu()end)
step('close menu',function()return host:closeExit()end)
local oldRefresh=host.refresh
host.refresh=function(...)record('replacement refresh',select('#',...));return oldRefresh(...)end
step('dynamic method',function()return host:openDeck()end)
step('dynamic close',function()return host:closeDeck()end)
local second
checkpoint('second shared platform',nil,function()second=setup();return true end)
local firstSync,secondSync=host.controller.sync,second.controller.sync
host.controller.sync=function(...)record('first controller');return firstSync(...)end
second.controller.sync=function(...)record('second controller');return secondSync(...)end
step('first captured controller',function()return host:syncController()end)
step('begin combat',function()local ok,why=require('abyss_run').startCombat(host.run,'cultist_solo');host:refresh();return ok,why end)
step('combat tick',function()return host:update(.05)end)
step('open exit',function()return host:openExit()end)
platform.settle=function(victory)record('settle',victory);record('reentry',host:confirmExit());return false end
step('settle false',function()return host:confirmExit()end)
platform.settle=function()record('settle throw');error('injected settlement error')end
step('settle throw',function()return host:confirmExit()end)
platform.settle=function(victory)record('settle nil',victory);record('reentry',host:confirmExit())end
step('settle nil',function()return host:confirmExit()end)
step('settle once',function()return host:confirmExit()end)
local release=host.battleUI.releaseMonsterSurfaces
local cancel=host.battleUI.feedback.cancel
host.battleUI.feedback.cancel=function(...)
 record('cancel inert',host.disabled,host.battleUI.active,host.mapUI.visible,host.nodeUI.visible)
 if host.disabled then record('cancel synchronous refresh',host:refresh())end
 return cancel(...)
end
host.battleUI.releaseMonsterSurfaces=function()record('cleanup failure');error('injected cleanup error')end
step('disable failure',function()return host:disable()end)
host.battleUI.releaseMonsterSurfaces=function(...)record('cleanup retry');return release(...)end
step('disable retry',function()return host:disable()end)
step('disabled update',function()return host:update(.1)end)
checkpoint('second disable',second,function()return second:disable()end)
print('GAME_UI_HOST_TRACE_PASS checkpoints='..count)
