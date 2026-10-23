local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local function setup(deck, enemies)
    local host, ui, panel, event, tap, drain, deckToggle, root = H.setup(deck, enemies)
    assert(H.Run.obtainPotion(host.run, "energy_potion")); host:refresh()
    local function emit(name, kind, touch)
        local box = panel:GetChild(name)
        local hit = box.listeners and box or box:GetChild("hit")
        local callback = hit.listeners and hit.listeners[kind]
        -- Deliver physical events without inventing listeners missing on the baseline.
        if callback then return callback({touchId = touch}) end
    end
    local function potionTap(touch, slot)
        local name = "potion" .. (slot or 1)
        emit(name, "down", touch); emit(name, "up", touch); emit(name, "click", touch)
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
return {F = H.F, Run = H.Run, setup = setup, suite = suite}
