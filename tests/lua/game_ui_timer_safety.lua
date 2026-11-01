-- Real generated controls + production GameUI, with controlled native APIs.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function finish(ui,root,seconds)
 ui.run.elapsedSeconds=seconds;ui.run.phase='defeat';ui:refresh()
 return F.statValue(root,'time')
end
local ui,root=F.fixture()
assert(F.start(ui))
assert(finish(ui,root,0)=='00:00','zero is a valid recorded duration, not an unavailable sentinel')
assert(finish(ui,root,62.25)=='01:02')
assert(finish(ui,root,3725.9)=='62:05')
assert(finish(ui,root,864000)=='14400:00','long recorded durations have no arbitrary cap')
for _,value in ipairs({false,'62',-1,math.huge,-math.huge,0/0,1e100})do
 assert(finish(ui,root,value)=='暂不可用','invalid elapsed value must not be formatted: '..tostring(value))
end
assert(finish(ui,root,nil)=='暂不可用')
assert(F.start(ui) and ui.run.elapsedSeconds==0)
ui:update(60.5);ui:update(1.75)
assert(finish(ui,root,ui.run.elapsedSeconds)=='01:02')
ui:update(100);assert(ui.run.elapsedSeconds==62.25,'terminal duration must freeze')
print('TIMER_VALUE_SAFETY_PASS valid zero/minutes, invalid values, terminal freeze, restart')

local GameUI=require('abyss_game_ui')
local canvas=F.control({children=F.Layout})
local host
local originalNew=GameUI.new
GameUI.new=function(...)host=originalNew(...);return host end
script={object=canvas,GetParam=function()return false end,EnableUpdate=function(self,v)self.updating=v end}
Enum={CursorEventType={CursorClick='click'},ImageSource={StaticReference='static'},Device={Mobile='mobile',Controller='controller',MobileController='mobile-controller'}}
Color=setmetatable({},{__call=function(_,r,g,b,a)return {r=r,g=g,b=b,a=a}end})
local actors=F.monsterActors()
package.loaded.abyss_monster_actor_binding={enabled=true,templateIndex=actors.templateIndex,
 containerTemplateIndex=actors.containerTemplateIndex,powerTemplateIndex=actors.powerTemplateIndex}
game={IsTestPlay=function()return false end,GetUICanvasSize=function()return 1280,720 end,
 InstantiateClientUIControl=actors.instantiate,DestroyClientUIControl=actors.destroy,
 GetDevice=function()return 'mobile' end,GetCursorUIPos=function()return 0,0 end,
 ServerSignal=function()return {SendSignal=function()end}end}
dofile('src/lua/abyss_ui.lua');OnStart();GameUI.new=originalNew
assert(host and script.updating,'actual native public entry must start')
local nativeRoot=canvas:GetChild('stage');nativeRoot.ui=host
assert(F.start(host))
-- Actual OnUpdate path remains internally compatible, but has no verified
-- foreground/background clock guarantee and therefore must not claim accuracy.
OnUpdate(60.5);OnUpdate(1.75)
assert(host.run.elapsedSeconds==62.25,'native fallback must not alter internal accumulation')
assert(finish(host,nativeRoot,62.25)=='暂不可用','unverified native clock must be unavailable even for plausible values')
for _,value in ipairs({0,3074457345,184467440737.0955,math.huge,-1,0/0})do
 assert(finish(host,nativeRoot,value)=='暂不可用','native values must never leak into the timer display')
end
assert(F.start(host) and host.run.elapsedSeconds==0)
OnUpdate(3600) -- background/resume-like interval, not a device timing claim
host.run.phase='victory';host.run.nodeFlow={complete=true,result='boss_treasure_complete'};host:refresh()
assert(F.statValue(nativeRoot,'time')=='暂不可用','victory shares safe fallback after background-like update')
assert(host:settle(),'safe fallback must not disable settlement')
print('NATIVE_TIMER_FALLBACK_PASS public OnStart/OnUpdate, defeat/victory, restart, background, settlement; device NOT_RUN')
