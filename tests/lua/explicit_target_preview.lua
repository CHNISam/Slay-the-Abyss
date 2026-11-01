-- Real generated GameUI host, native cursor/controller callbacks and Combat.
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local F=H.F
local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print('PASS '..name)
    else failed=failed+1;print('FAIL '..name..': '..tostring(why))end
end
local function value(panel,slot)
    local text=panel:GetChild('card'..(slot or 1)):GetChild('label').text
    text=text:gsub('<color=#[%x]+>',''):gsub('</color>',''):gsub('↑',''):gsub('↓','')
    return tonumber(text:match('(%d+)'))
end
local function setup()
    local host,ui,panel,event,tap,drain=H.setup({'strike','strike'},{'cultist','jaw_worm'})
    F.Combat.addStatus(host.run.combat.enemies[1],'vulnerable',2)
    host:refresh()
    return host,ui,panel,event,tap,drain
end
test('default target is not explicit; Down previews before one Click commits unchanged damage',function()
    local host,ui,panel,event,tap=setup();local b=host.run.combat
    tap('card1',7);assert(ui.target==1 and value(panel)==6,'default target leaked')
    local hp=b.enemies[1].hp
    event('enemy1','down',8)
    assert(value(panel)==9,'explicit pointer Down must show 9 before commit; got '..tostring(value(panel)))
    assert(value(panel,2)==6 and b.energy==3 and #b.hand==2 and b.enemies[1].hp==hp,'preview mutated combat')
    event('enemy1','up',8);assert(value(panel)==9)
    event('enemy1','click',8)
    assert(b.energy==2 and #b.hand==1 and b.enemies[1].hp==hp-9 and not ui.selected and ui.cardAim==nil)
end)
test('pointer target changes 9 to 6 to 9 and EndDrag cancels only preview',function()
    local host,ui,panel,event,tap=setup();tap('card1',7)
    event('enemy1','down',8);assert(value(panel)==9)
    event('enemy2','down',9);assert(value(panel)==6)
    event('enemy1','down',10);assert(value(panel)==9)
    event('enemy1','endDrag',10);assert(value(panel)==6)
    event('enemy1','down',11);assert(value(panel)==9)
    event('enemy1','exit',12);assert(value(panel)==9,'foreign touch cleared current preview')
    event('enemy1','endDrag',10);assert(value(panel)==9,'old token cleared current preview')
    event('enemy1','exit',11);assert(value(panel)==6,'leaving target retained preview')
    assert(host.run.combat.energy==3 and #host.run.combat.hand==2)
end)
test('selection refresh and stale release cannot preview or submit replacement selection',function()
    local host,ui,panel,event,tap=setup();tap('card1',7)
    event('enemy1','down',8);event('enemy1','up',8);assert(value(panel)==9)
    tap('card1',9);assert(value(panel)==6 and not ui.selected and ui.cardAim==nil)
    tap('card1',9);assert(value(panel)==6)
    event('enemy1','click',8);assert(value(panel)==6 and host.run.combat.energy==3)
    event('enemy1','down',10);assert(value(panel)==9)
    tap('card2',11);assert(value(panel)==6 and value(panel,2)==6)
end)
test('state refresh recomputes; turn phase actor battle and inactive invalidate aim',function()
    for _,kind in ipairs({'status','turn','phase','actor','battle','inactive'})do
        local host,ui,panel,event,tap=setup();local b=host.run.combat
        tap('card1',7);event('enemy1','down',8);assert(value(panel)==9,kind)
        if kind=='status'then b.enemies[1].statuses.vulnerable=nil
        elseif kind=='turn'then b.turn=b.turn+1
        elseif kind=='phase'then b.phase='enemy'
        elseif kind=='actor'then b.enemies[1]=F.Combat.copy(b.enemies[1])
        elseif kind=='battle'then host.run.combat=F.Combat.new(F.Data,{deck={'strike'},enemies={'cultist'}})
        else ui.active=false end
        ui:render();assert(value(panel)==6,kind..' retained old preview')
        if kind~='status'then assert(ui.cardAim==nil,kind..' retained stale token')end
        assert(b.energy==3 and #b.hand==2,kind..' mutated combat')
    end
end)
test('new actual gesture retires an older enemy pointer preview',function()
    local host,ui,panel,event,tap=setup();tap('card1',7)
    event('enemy1','down',8);assert(value(panel)==9)
    event('card1','down',7);event('card1','drag',7,-285,0)
    assert(ui.gesture and ui.gesture.moving and value(panel)==6,'old pointer target overrode new drag')
    assert(ui.cardAim==nil and host.run.combat.energy==3)
end)
test('actual drag still previews and empty ground clears without automatic target',function()
    local host,ui,panel,event=setup();local b=host.run.combat
    local enemy=F.actorControl(panel,'enemy1')
    event('card1','down',7);event('card1','drag',7,enemy.x,enemy.y)
    assert(value(panel)==9)
    event('dragLayer','drag',7,-285,0);assert(value(panel)==6)
    assert(b.energy==3 and #b.hand==2)
end)
test('controller Focus previews before Confirm; switch, cancel, stale focus and damage stay correct',function()
    local focus
    local api={events={Confirm='confirm',Cancel='cancel',Focus='focus',LostFocus='blur'},directions={Left='left',Right='right'},modes={Specified='specified'},getFocus=function()return focus end,isController=function()return true end}
    api.setFocus=function(c)focus=c;if c and c.navigationListeners and c.navigationListeners.focus then c.navigationListeners.focus()end end
    local host,root=F.fixture(nil,nil,nil,{CursorDown='down',CursorUp='up',CursorDrag='drag',CursorEndDrag='endDrag'},false,nil,nil,api)
    assert(F.start(host));assert(H.Run.startCombat(host.run,'cultist_solo'))
    host.run.combat=F.Combat.new(F.Data,{deck={'strike','strike'},enemies={'cultist','jaw_worm'}})
    local b=host.run.combat;F.Combat.addStatus(b.enemies[1],'vulnerable',2)
    host:resize(1280,720);host:refresh()
    local ui,panel=host.battleUI,root:GetChild('battlePanel')
    local function hit(name)local box=F.actorControl(panel,name);return box:GetChild('hit')end
    local function press(c,kind)host:update(.01);host:syncController();api.setFocus(c);return c.navigationListeners[kind or 'confirm']()end
    press(hit('card1'));assert(ui.selected and value(panel)==9,'controller focused first enemy must preview 9')
    api.setFocus(hit('enemy2'));assert(value(panel)==6)
    api.setFocus(hit('enemy1'));assert(value(panel)==9)
    assert(b.energy==3 and #b.hand==2)
    press(hit('enemy1'),'cancel');assert(not ui.selected and value(panel)==6)
    hit('enemy1').navigationListeners.focus();assert(value(panel)==6,'old focus resurrected selection')
    press(hit('card1'));local hp=b.enemies[1].hp
    press(hit('enemy1'));assert(b.energy==2 and b.enemies[1].hp==hp-9 and not ui.selected)
    host:disable()
end)
print('explicit target preview: '..passed..' passed, '..failed..' failed')
assert(failed==0)
