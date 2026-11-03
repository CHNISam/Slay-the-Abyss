-- Catches native timing fallback blocking exit/restart, stale gestures retrying
-- settlement, and accepted native signals being sent more than once.
-- Real GameUI/Host, generated controls and abyss_ui.lua lifecycle; no device claim.
local F = dofile('tests/lua/support/game_ui_fixture.lua')
local GameUI = require('abyss_game_ui')
local canvas = F.control({children=F.Layout})
local host
local originalNew = GameUI.new
GameUI.new = function(...) host=originalNew(...); return host end
script = {object=canvas, GetParam=function() return false end,
    EnableUpdate=function(self,value) self.updating=value end}
Enum = {CursorEventType={CursorClick='click',CursorDown='down',CursorUp='up',CursorExit='out'},
    ImageSource={StaticReference='static'},
    Device={Mobile='mobile',Controller='controller',MobileController='mobile-controller'}}
Color = setmetatable({}, {__call=function(_,r,g,b,a) return {r=r,g=g,b=b,a=a} end})
local actors = F.monsterActors()
package.loaded.abyss_monster_actor_binding = {enabled=true,templateIndex=actors.templateIndex,
    containerTemplateIndex=actors.containerTemplateIndex,powerTemplateIndex=actors.powerTemplateIndex}
local attempts, accepted = 0, 0
game = {IsTestPlay=function() return false end,GetUICanvasSize=function() return 1280,720 end,
    InstantiateClientUIControl=actors.instantiate,DestroyClientUIControl=actors.destroy,
    GetDevice=function() return 'mobile' end,GetCursorUIPos=function() return 0,0 end,
    ServerSignal=function(name)
        assert(name=='ABYSS_LOSE','abandon/defeat must retain the native lose outcome')
        return {SendSignal=function()
            attempts=attempts+1
            if attempts==1 then error('injected native signal failure') end
            accepted=accepted+1
        end}
    end}
dofile('src/lua/abyss_ui.lua')
OnStart()
GameUI.new = originalNew
assert(host and script.updating,'real native entry must start')
host.seed=42 -- deterministic first-room encounters; native platform remains intact
local root = canvas:GetChild('stage')
local function hit(panel,button)
    local control=root:GetChild(panel)
    for part in button:gmatch('[^/]+') do control=assert(control:GetChild(part)) end
    return control:GetChild('hit')
end
local function fire(control,event,id) return assert(control.listeners[event])({touchId=id}) end
local function gesture(control,id) fire(control,'down',id); fire(control,'up',id) end
local function tap(panel,button,id)
    local control=hit(panel,button)
    local parent=control
    while parent do assert(parent.visible~=false,'hidden native button '..button); parent=parent.parent end
    assert(control.raycastTarget~=false,'inert native button '..button)
    gesture(control,id)
    return fire(control,'click',id)
end
local function open(id)
    assert(tap('exitEntry','open',id))
    assert(root:GetChild('runMenu').visible)
    assert(tap('runMenu','abandon',id+1))
    assert(root:GetChild('exitPanel').visible and not root:GetChild('runMenu').visible)
end
local function defeat()
    -- Finish the production opening, enter the first legal room, then let real
    -- enemy turns defeat a controlled three-HP player. Never assign a phase.
    assert(F.click(root,'nodePanel','eventView/option1'))
    assert(F.click(root,'nodePanel','eventView/option2'))
    assert(F.click(root,'nodePanel','eventView/option1'))
    assert(host.run.phase=='map','native Neow opening must finish through its buttons')
    host.run.hp=3
    assert(host.mapUI:choose(F.Nodes.available(host.run,host.map)[1].id))
    local feedbackUpdates,revealUpdates=0,0
    for _=1,30 do
        if host.run.phase~='combat' then break end
        local endTurn=root:GetChild('battlePanel'):GetChild('endTurn')
        local parent=endTurn
        while parent do assert(parent.visible~=false and parent.activeInHierarchy,'inactive end-turn button');parent=parent.parent end
        assert(endTurn.raycastTarget~=false and endTurn.interactable~=false)
        assert(endTurn.listeners.click)()
        assert(host.battleUI.busy,'end-turn listener must leave native feedback for OnUpdate')
        for _=1,600 do
            if not host.battleUI.busy then break end
            OnUpdate(0.05)
            feedbackUpdates=feedbackUpdates+1
        end
        assert(not host.battleUI.busy,'native battle feedback must finish')
    end
    for _=1,600 do
        if host.mode=='defeat' and not host.motion.deathReveal then break end
        OnUpdate(0.05)
        revealUpdates=revealUpdates+1
    end
    assert(feedbackUpdates>0 and revealUpdates>0,'OnUpdate must drive feedback and result reveal')
    assert(host.run.phase=='defeat' and host.mode=='defeat' and not host.motion.deathReveal)
    assert(root:GetChild('menuPanel'):GetChild('result').visible)
    assert(F.statValue(root,'time')=='暂不可用','unverified native time must stay unavailable')
end

assert(tap('menuPanel','start',1) and F.confirmStart(host))
OnUpdate(3600) -- resume-like input, not evidence about a device clock
defeat()
local oldRun=host.run
local frozen=oldRun.elapsedSeconds
OnUpdate(60)
assert(oldRun.elapsedSeconds==frozen,'terminal duration must freeze')
gesture(hit('menuPanel','start'),30)
open(31)
assert(tap('exitPanel','cancel',33))
assert(host.run==oldRun and host.mode=='defeat' and attempts==0)
assert(F.statValue(root,'time')=='暂不可用')
assert(not fire(hit('menuPanel','start'),'click',30),'cancel must invalidate old restart gesture')
assert(tap('menuPanel','start',34) and host.characterOpen and host.run==oldRun)
assert(F.confirmStart(host) and host.run~=oldRun and host.run.elapsedSeconds==0,
    'unavailable timer must permit restart without carrying old duration')
assert(not fire(hit('menuPanel','start'),'click',34),'restart gesture must be consumed')
print('NATIVE_EXIT_TIMER_RESTART_PASS actual defeat, unavailable timer, exit cancellation, fresh run')

OnUpdate(1.75)
defeat()
local run=host.run
local elapsed=run.elapsedSeconds
open(41)
assert(not tap('exitPanel','confirm',43) and attempts==1 and accepted==0)
assert(not host.settlementRequested and host.run==run)
assert(root:GetChild('exitPanel'):GetChild('status').text:find('重试',1,true))
assert(not fire(hit('exitPanel','confirm'),'click',43) and attempts==1,
    'duplicate failed gesture must not retry the native signal')
assert(tap('exitPanel','cancel',44) and host.run==run)
assert(F.statValue(root,'time')=='暂不可用')
open(45)
assert(tap('exitPanel','confirm',47) and attempts==2 and accepted==1 and host.settlementRequested)
assert(not fire(hit('exitPanel','confirm'),'click',47) and attempts==2 and accepted==1,
    'accepted native settlement must be sent exactly once')
OnUpdate(3600)
assert(host.run==run and run.elapsedSeconds==elapsed and accepted==1)
assert(F.statValue(root,'time')=='暂不可用')
assert(not fire(hit('menuPanel','start'),'click',34) and host.run==run)
assert(not host.disabled and script.updating,'native update must stay healthy')
print('NATIVE_EXIT_TIMER_RETRY_PASS native exit chain, signal failure/cancel/retry, single accepted request; device NOT_RUN')
OnDestroy()
assert(not script.updating)
