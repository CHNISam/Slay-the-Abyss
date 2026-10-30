local F = dofile('tests/lua/support/game_ui_fixture.lua')
local Run = require('abyss_run')
local M = {F = F, Run = Run}
local cursor = {CursorDown='down', CursorUp='up', CursorEndDrag='end', CursorExit='exit'}
function M.setup(options)
    options = options or {}
    local calls, focus = 0, nil
    local api = options.controller and {
        events={Confirm='confirm', Cancel='cancel', Focus='focus', LostFocus='blur'},
        directions={Left='left', Right='right'}, modes={Specified='specified', NearestControl='nearest'},
        getFocus=function() return focus end, setFocus=function(value) focus=value end,
        isController=function() return true end,
    } or nil
    local ui, root = F.fixture(nil, function(victory)
        calls = calls + 1
        if options.settle then return options.settle(calls, victory) end
        return true
    end, nil, cursor, false, nil, nil, api)
    assert(F.start(ui))
    if options.revive == 'fairy' then assert(Run.obtainPotion(ui.run, 'fairy_in_a_bottle')) end
    if options.revive == 'tail' then assert(Run.obtainRelic(ui.run, 'lizard_tail')) end
    ui.run.hp = options.normal and 80 or 3
    if not options.map then
        assert(Run.startCombat(ui.run, 'cultist_solo'))
        local enemy = ui.run.combat.enemies[1]
        enemy.ai, enemy.intentIndex = nil, 1
        -- A controlled lethal amplitude on a real ATTACK identity, not natural Cultist damage.
        local known=require('abyss_monster_source_intents')
        local ok,reason=pcall(known.enum,enemy,{id='fatal'})
        assert(not ok and tostring(reason):find('unmapped source monster intent cultist:fatal',1,true),
            'unknown synthetic move must remain fail-closed')
        enemy.intents = {{id='cultist_1', kind='attack', effects={{op='damage', value=12}}}}
    end
    ui:refresh()
    return ui, root, function() return calls end, api
end
function M.hit(root, panel, button)
    return root:GetChild(panel):GetChild(button):GetChild('hit')
end
function M.fire(hit, event, id)
    return assert(hit.listeners[event], 'missing native listener ' .. event)(id and {touchId=id} or nil)
end
function M.gesture(hit, id) M.fire(hit, 'down', id); M.fire(hit, 'up', id) end
function M.tap(hit, id)
    local parent = hit
    while parent do assert(parent.visible ~= false, 'hidden native control'); parent=parent.parent end
    assert(hit.raycastTarget ~= false, 'native control is inert')
    M.gesture(hit, id)
    return M.fire(hit, 'click', id)
end
function M.event(ui, api, hit, event)
    ui:update(0); ui:syncController()
    assert(hit.canControllerFocus, 'controller target unavailable')
    api.setFocus(hit)
    return assert(hit.navigationListeners[event or 'confirm'])()
end
function M.until_(ui, predicate)
    for _=1,600 do if predicate() then return end; ui:update(0.01) end
    error('transition did not reach expected phase')
end
function M.phase(ui, kind)
    local current = ui.battleUI.feedback.current
    return current and current.kind == kind
end
function M.finish(ui)
    M.until_(ui, function() return ui.mode == 'defeat' and not ui.motion.deathReveal end)
end
function M.open(ui, root, api)
    if api then
        assert(M.event(ui, api, M.hit(root, 'exitEntry', 'open')))
        assert(ui.exitOpen and ui.menuOpen)
        assert(M.event(ui, api, M.hit(root, 'runMenu', 'abandon')))
    else
        assert(M.tap(M.hit(root, 'exitEntry', 'open'), 31))
        assert(ui.exitOpen and ui.menuOpen)
        assert(M.tap(M.hit(root, 'runMenu', 'abandon'), 32))
    end
    assert(ui.exitOpen and not ui.menuOpen)
end
return M
