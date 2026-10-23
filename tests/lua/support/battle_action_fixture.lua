local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local function controls(panel)
    local function emit(name, kind, touch)
        local box = panel:GetChild(name)
        local hit = box.listeners and box or box:GetChild("hit")
        local callback = hit.listeners and hit.listeners[kind]
        -- Real hosts may omit an event listener. Do not invent that callback.
        if callback then return callback({touchId = touch}) end
    end
    local function tap(name, touch)
        emit(name, "down", touch); emit(name, "up", touch); emit(name, "click", touch)
    end
    return emit, tap
end
local function setup(deck, enemies)
    local host, ui, panel, _, _, drain, deckToggle, root = H.setup(deck, enemies)
    local emit, tap = controls(panel)
    return host, ui, panel, emit, tap, drain, deckToggle, root
end
local function reward()
    -- Initial deterministic one-hit fixture; every following transition is real.
    local h, u, p, emit, tap, drain, deckToggle, root = setup({"bludgeon"}, {"acid_slime_s"})
    tap("card1", 8); tap("enemy1", 8); drain(); assert(h.run.phase == "reward")
    return h, u, p, emit, tap, drain, deckToggle, root
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
        assert(failed == 0, "Action pointer failures: " .. failed)
    end
    return test, finish
end
return {F = H.F, Run = H.Run, setup = setup, reward = reward, controls = controls, suite = suite}
