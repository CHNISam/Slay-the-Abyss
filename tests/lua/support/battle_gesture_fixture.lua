package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Run = require("abyss_run")
local function setup(deck, enemies, pointer)
    local host, root = F.fixture(nil,nil,nil,{CursorDown="down",CursorDrag="drag",CursorUp="up",
        CursorEndDrag="endDrag",CursorEnter="enter",CursorExit="exit"},nil,nil,pointer)
    assert(host:start())
    assert(Run.startCombat(host.run,"cultist_solo"))
    host.run.combat=F.Combat.new(F.Data,{deck=deck or {"defend","defend"},enemies=enemies or {"cultist"}})
    host:resize(1280,720); host:refresh()
    local ui, panel = host.battleUI, root:GetChild("battlePanel")
    local function event(name, kind, touch, x, y)
        local box=panel:GetChild(name)
        local hit=box.listeners and box or box:GetChild("hit")
        local callback=assert(hit.listeners and hit.listeners[kind], name.."/"..kind)
        local k=math.min(ui.canvasWidth/1280,ui.canvasHeight/720)
        x,y=x or box.x or 0,y or box.y or 0
        return callback({touchId=touch,GetUIPos=function() return ui.canvasWidth/2+x*k,ui.canvasHeight/2+y*k end})
    end
    local function tap(name,touch)
        event(name,"down",touch)
        local box=panel:GetChild(name)
        local hit=box.listeners and box or box:GetChild("hit")
        -- Physical Up is a no-op on controls without an Up listener.
        if hit.listeners and hit.listeners.up then event(name,"up",touch) end
        event(name,"click",touch)
    end
    local function drain()
        for _=1,400 do if not ui.busy then return end; host:update(0.05) end
        assert(not ui.busy,"feedback remained stuck")
    end
    local function openCloseDeck()
        assert(root:GetChild("deckEntry"):GetChild("open"):GetChild("hit").click({touchId=8}))
        assert(host.deckUI.visible and ui.gesture==nil)
        assert(root:GetChild("deckPanel"):GetChild("close"):GetChild("hit").click({touchId=8}))
        assert(not host.deckUI.visible and ui.active)
    end
    return host,ui,panel,event,tap,drain,openCloseDeck,root
end

return {F=F,Run=Run,setup=setup}
