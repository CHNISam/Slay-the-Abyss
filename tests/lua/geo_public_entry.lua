local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function native(workKey)
 local canvas=F.control({children=F.Layout})
 local host
 local originalNew=F.GameUI.new
 F.GameUI.new=function(...)
  host=originalNew(...);return host
 end
 local originalNarrative=package.loaded.abyss_narrative
 local narrative={};for k,v in pairs(originalNarrative)do narrative[k]=v end
 if workKey then narrative.build={workKey=workKey} end
 package.loaded.abyss_narrative=narrative
 script={object=canvas,GetParam=function()return false end,EnableUpdate=function(self,value)self.updating=value end}
 Enum={CursorEventType={CursorClick='click'},ImageSource={StaticReference='static'},Device={Mobile='mobile',Controller='controller',MobileController='mobile-controller'}}
 Color=setmetatable({},{__call=function(_,r,g,b,a)return {r=r,g=g,b=b,a=a}end})
 game={IsTestPlay=function()return false end,GetUICanvasSize=function()return 1280,720 end,
  GetDevice=function()return 'pc' end,GetCursorUIPos=function()return 0,0 end,
  ServerSignal=function()return {SendSignal=function()end}end}
 dofile('src/lua/abyss_ui.lua');OnStart();OnStart()
 F.GameUI.new=originalNew;package.loaded.abyss_narrative=originalNarrative
 assert(host and script.updating,'actual ordinary-player native startup failed')
 local root=canvas:GetChild('stage');root.ui=host
 host.seed='2' -- deterministic offline route only; not natural/device evidence
 F.click(root,'menuPanel','start')
 assert(host.characterOpen and not host.run)
 local panel=root:GetChild('characterPanel')
 assert(panel:GetChild('traveler').visible)
 for i=1,4 do assert(not panel:GetChild('character'..i).visible)end
 assert(not panel:GetChild('hint').text:find('待验收',1,true),'old acceptance blocker remains in player flow')
 for _,id in ipairs({'raiden','hutao','arlecchino','furina','unknown'})do assert(not host:selectCharacter(id) and not host.run)end
 assert(host:selectCharacter('traveler'))
 for _,id in ipairs({'silent','defect','watcher','unknown'})do assert(not host:selectElement(id))end
 host.characterSelection.info={id='raiden'}
 assert(not host:confirmCharacter() and not host.run and host.seed=='2','configuration bypass created a future character')
 F.click(root,'characterPanel','traveler');F.click(root,'characterPanel','confirm')
 local run=host.run
 assert(run and not run.characterProfile and not run.data.originalV4Role and run.maxHp==80)
 assert(run.campaignProfile=='competition-two-act' and run.act==1)
 host:confirmCharacter() -- stale programmatic confirmation after the panel has closed
 assert(host.run==run,'duplicate confirmation created another run')
 assert(host.prologue and host.prologue:skip());OnUpdate(1);OnUpdate(1)
 assert(host.mode=='node' and run.nodeFlow.event.id=='neow')
 F.click(root,'nodePanel','eventView/option1')
 F.click(root,'nodePanel','eventView/option2')
 F.click(root,'nodePanel','eventView/option1')
 assert(host.mode=='map' and host.mapUI.navigationEnabled and host.run==run)
 local first=F.Nodes.available(run,host.map)[1]
 assert(first and host.mapUI:choose(first.id))
 assert(host.mode=='battle' and run.phase=='combat' and host.run==run)
 for _,held in ipairs(run.combat.hand)do assert(not held.cardId:match('^RD2%-'))end
end
native() -- unmodified generated narrative, including absent optional build metadata
native('competition') -- actual Production / IsTestPlay=false
native('alpha-test') -- uploaded Alpha / IsTestPlay=false
native('dev') -- a work-key cannot expose explicit Dev-only characters
print('GEO_PUBLIC_ENTRY_PASS 4; controlled native entry; live device NOT_RUN')
