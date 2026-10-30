local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local confirm=dofile("tests/lua/support/confirm_potion_popup.lua")
local function setup(deck, enemies)
    local host, ui, panel, event, tap, drain, deckToggle, root = H.setup(deck, enemies)
    assert(H.Run.obtainPotion(host.run, "energy_potion")); host:refresh()
    -- Physical releases belong to the actual control pressed, even if its actor
    -- was retired meanwhile. Keep callbacks, never remap a dead actor to a survivor.
    local pressed={}
    local function emit(name, kind, touch)
        local actor=name:match('^enemy%d+$')
        local callbacks=actor and kind~='down' and pressed[name]
        if not callbacks then
            local box=H.F.actorControl(panel,name)
            local hit=box.listeners and box or box:GetChild('hit')
            callbacks=hit.listeners
            if actor and kind=='down' then
                local saved={};for event,fn in pairs(callbacks or {})do saved[event]=fn end
                pressed[name]=saved;callbacks=saved
            end
        end
        local callback=callbacks and callbacks[kind]
        -- Deliver physical events without inventing listeners missing on the baseline.
        if callback then return callback({touchId = touch}) end
    end
    local function potionTap(touch, slot)
        local name = "potion" .. (slot or 1)
        local previous=ui.potionAim
        emit(name, "down", touch); emit(name, "up", touch); emit(name, "click", touch)
        confirm(ui,panel,touch,previous)
    end
    return host, ui, panel, event, tap, drain, deckToggle, root, emit, potionTap
end
local function suite(label)
    local passed, failed = 0, 0
    local function test(name, fn)
        local ok, why = pcall(fn)
        if ok then passed = passed + 1; print("PASS " .. name)
        else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(why)) end
    end
    local function finish()
        print(label .. " " .. passed .. " passed; " .. failed .. " failed")
        assert(failed == 0, "Potion pointer failures: " .. failed)
    end
    return test, finish
end
return {F = H.F, Run = H.Run, setup = setup, suite = suite, confirm = confirm}
