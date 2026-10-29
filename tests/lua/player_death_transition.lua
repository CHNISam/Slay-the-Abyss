local F = dofile('tests/lua/support/game_ui_fixture.lua')
local Run = require('abyss_run')
local T = F.Theme.motion
local count = 0
local function test(name, fn)
    fn(); count = count + 1; print('ok player death ' .. count .. ' - ' .. name)
end
local function setup(options)
    options = options or {}
    local sounds, music, settlements = {}, {}, 0
    local ui, root = F.fixture(nil, function() settlements = settlements + 1 return true end,
        function(signal) music[#music + 1] = signal end, nil, nil,
        function(cue) sounds[#sounds + 1] = cue end)
    assert(F.start(ui))
    if options.fairy then assert(Run.obtainPotion(ui.run, 'fairy_in_a_bottle')) end
    if options.tail then assert(Run.obtainRelic(ui.run, 'lizard_tail')) end
    ui.run.hp = 3
    assert(Run.startCombat(ui.run, 'cultist_solo'))
    local battle = ui.run.combat
    local enemy = battle.enemies[1]
    enemy.ai, enemy.intentIndex = nil, 1
    enemy.intents = {{id = 'fatal', kind = 'attack', effects = {{op = 'damage', value = 12}}}}
    if options.thorns then F.Combat.addStatus(enemy, 'thorns', 5) end
    ui:refresh()
    return ui, root, battle, sounds, function() return settlements end, music
end
local function until_(ui, predicate)
    for _ = 1, 600 do
        if predicate() then return end
        ui:update(0.01)
    end
    error('transition did not reach expected phase')
end
local function stepIs(ui, kind)
    local current = ui.battleUI.feedback.current
    return current and current.kind == kind
end
local function cueCount(sounds, cue)
    local total = 0
    for _, value in ipairs(sounds) do if value == cue then total = total + 1 end end
    return total
end

test('fatal hit, player collapse, opaque handoff and result reveal preserve committed state', function()
    local ui, root, battle, sounds, settlements, music = setup()
    local panel = root:GetChild('battlePanel')
    panel:GetChild('endTurn').click()
    assert(ui.run.phase == 'defeat' and ui.mode == 'battle' and ui.battleUI.busy)
    local feedback = ui.battleUI.feedback
    local sequence = {}
    for _, entry in ipairs(feedback.queue) do sequence[#sequence + 1] = entry.kind end
    assert(table.concat(sequence, ','):find('damage,player_death,defeat', 1, true),
        'fatal contact must be followed by a dedicated player death, not just the ordinary banner')
    until_(ui, function() return stepIs(ui, 'damage') end)
    assert(panel:GetChild('hero').visible and cueCount(sounds, 'hurt') == 1)
    until_(ui, function() return stepIs(ui, 'player_death') end)
    assert(ui.mode == 'battle' and ui.battleUI.busy and feedback.deaths.player)
    assert(music[#music] == 'ABYSS_BGM_DEFEAT', 'combat music must stop at player death, not after the entire transition')
    ui:update(T.slow / 2)
    local portrait = panel:GetChild('hero'):GetChild('portrait')
    assert(portrait.y < 0 and portrait.imageColor.a < 255, 'player must visibly collapse/fade')
    assert(cueCount(sounds, 'defeat') == 1 and cueCount(sounds, 'enemy_die') == 0)
    until_(ui, function() return stepIs(ui, 'defeat') end)
    local shade = panel:GetChild('feedback'):GetChild('deathShade')
    ui:update(T.banner / 2)
    assert(shade.visible and shade.imageColor.a > 0 and shade.imageColor.a < 255)
    assert(not panel:GetChild('hero').visible, 'banner refresh must not resurrect the collapsed player')
    assert(not ui:start() and not ui:settle() and settlements() == 0)
    until_(ui, function() return ui.mode == 'defeat' end)
    local veil = root:GetChild('menuPanel'):GetChild('deathShade')
    assert(veil.visible and veil.imageColor.a == 255, 'result handoff must be covered, not a hard cut')
    assert(not ui:start() and not ui:settle() and settlements() == 0)
    local hp, gold, rng = battle.player.hp, ui.run.gold, battle.rng
    ui:update(T.slow / 2)
    assert(veil.visible and veil.imageColor.a > 0 and veil.imageColor.a < 255)
    ui:update(T.slow)
    assert(not veil.visible and not ui.battleUI.busy)
    assert(battle.player.hp == hp and ui.run.gold == gold and battle.rng == rng)
    assert(cueCount(sounds, 'defeat') == 1)
    local previous = ui.run
    assert(F.start(ui) and ui.run ~= previous and ui.run.phase ~= 'defeat')
    assert(not veil.visible and not shade.visible, 'restart clears both halves of the veil')
end)

test('retaliation death enters the same transition without a second enemy death cue', function()
    local ui, root, battle, sounds = setup({thorns = true})
    local slot
    for i, card in ipairs(battle.hand) do if F.Combat.cardDefinition(battle, card).type == 'attack' then slot = i break end end
    assert(slot)
    local panel = root:GetChild('battlePanel')
    panel:GetChild('card' .. slot):GetChild('hit').click()
    panel:GetChild('enemy1'):GetChild('hit').click()
    assert(ui.run.phase == 'defeat')
    until_(ui, function() return stepIs(ui, 'player_death') end)
    assert(cueCount(sounds, 'defeat') == 1)
    until_(ui, function() return ui.mode == 'defeat' end)
end)

test('Fairy recovery never queues a player death or covers combat', function()
    local ui, root, battle, sounds = setup({fairy = true})
    root:GetChild('battlePanel'):GetChild('endTurn').click()
    assert(battle.player.hp > 0 and ui.run.phase == 'combat')
    for _, entry in ipairs(ui.battleUI.feedback.queue) do assert(entry.kind ~= 'player_death' and entry.kind ~= 'defeat') end
    until_(ui, function() return not ui.battleUI.busy end)
    assert(cueCount(sounds, 'defeat') == 0 and ui.mode == 'battle')
    assert(not root:GetChild('battlePanel'):GetChild('feedback'):GetChild('deathShade').visible)
end)

test('Lizard Tail recovery also remains ordinary combat', function()
    local ui, root, battle, sounds = setup({tail = true})
    root:GetChild('battlePanel'):GetChild('endTurn').click()
    assert(battle.player.hp > 0 and ui.run.phase == 'combat')
    for _, entry in ipairs(ui.battleUI.feedback.queue) do assert(entry.kind ~= 'player_death' and entry.kind ~= 'defeat') end
    until_(ui, function() return not ui.battleUI.busy end)
    assert(cueCount(sounds, 'defeat') == 0 and ui.mode == 'battle')
end)

test('cancel clears the death veil and player pose before another battle', function()
    local ui, root = setup()
    local panel = root:GetChild('battlePanel')
    panel:GetChild('endTurn').click()
    until_(ui, function() return stepIs(ui, 'defeat') end)
    ui:update(T.banner / 2)
    ui.battleUI.feedback:cancel()
    ui:refresh()
    assert(not ui.battleUI.busy and not panel:GetChild('feedback'):GetChild('deathShade').visible)
    local portrait = panel:GetChild('hero'):GetChild('portrait')
    assert(portrait.y == 0 and portrait.imageColor.a == 255)
    assert(F.start(ui))
    -- Restart may legitimately open Neow; this fixture isolates new battle presentation.
    ui.run.phase, ui.run.floor = 'map', 1
    assert(Run.startCombat(ui.run, 'cultist_solo')); ui:refresh()
    assert(panel:GetChild('hero').visible and not ui.battleUI.feedback.deaths.player)
end)

test('fault during the veil animation releases input and leaves no veil', function()
    local ui, root = setup()
    local panel = root:GetChild('battlePanel')
    panel:GetChild('endTurn').click()
    until_(ui, function() return stepIs(ui, 'defeat') end)
    local shade = panel:GetChild('feedback'):GetChild('deathShade')
    local overlay = panel:GetChild('feedback')
    local original, injected = overlay.GetChild, false
    overlay.GetChild = function(self, name)
        if name == 'deathShade' and not injected then injected = true error('INJECTED_DEATH_VEIL_FAILURE') end
        return original(self, name)
    end
    ui:update(0.01)
    assert(injected and not ui.battleUI.busy and ui.mode == 'defeat' and not shade.visible)
    assert(F.start(ui), 'presentation failure must not strand restart')
end)

test('fast mode and stalled frames cannot skip the visible player death step', function()
    local ui, root = setup()
    ui.battleUI.feedback:setFastMode(true)
    root:GetChild('battlePanel'):GetChild('endTurn').click()
    until_(ui, function() return stepIs(ui, 'player_death') end)
    assert(ui.battleUI.busy and ui.mode == 'battle')
    ui:update(10)
    assert(stepIs(ui, 'defeat') and ui.battleUI.busy and ui.mode == 'battle')
    ui:update(10)
    assert(ui.mode == 'defeat')
end)

test('a stalled contact frame still renders the beginning of the collapse', function()
    local ui, root = setup()
    root:GetChild('battlePanel'):GetChild('endTurn').click()
    until_(ui, function() return stepIs(ui, 'damage') end)
    ui:update(0.4)
    assert(stepIs(ui, 'player_death'))
    assert(root:GetChild('battlePanel'):GetChild('hero').visible,
        'elapsed time before the death step must not consume its animation')
    ui:update(0.1)
    local portrait = root:GetChild('battlePanel'):GetChild('hero'):GetChild('portrait')
    assert(portrait.imageColor.a > 0 and portrait.imageColor.a < 255)
end)

test('exit-menu settlement cannot bypass the result reveal', function()
    local ui, root, _, _, settlements = setup()
    root:GetChild('battlePanel'):GetChild('endTurn').click()
    until_(ui, function() return ui.mode == 'defeat' end)
    assert(ui:openExit())
    assert(not ui:confirmExit() and settlements() == 0)
    assert(ui:closeExit())
    ui:update(T.slow)
    assert(ui:settle() and settlements() == 1)
end)

test('standalone restart clears death ownership before rendering the new hero', function()
    local function find(entries)
        for _, entry in ipairs(entries) do
            if entry.name == 'battlePanel' then return F.Combat.copy(entry) end
            local found = find(entry.children or {})
            if found then return found end
        end
    end
    local spec = find(F.Layout)
    assert(spec); spec.name = 'stage'
    local root = F.control({name = 'root', children = {spec}})
    local ui = require('abyss_battle_ui').new(root, F.Data, F.Presentation, 'click', {
        imageSource = 'static', color = function(r,g,b,a) return {r=r,g=g,b=b,a=a} end})
    ui:start()
    ui.run.combat.player.hp = 1
    for _ = 1, 8 do
        if ui.run.phase == 'defeat' then break end
        root:GetChild('stage'):GetChild('endTurn').click()
        for _ = 1, 600 do if not ui.busy then break end ui:update(0.01) end
    end
    assert(ui.run.phase == 'defeat' and ui.feedback.deaths.player)
    ui:start()
    assert(ui.run.phase == 'combat' and not ui.feedback.deaths.player)
    assert(root:GetChild('stage'):GetChild('hero').visible)
end)

print('LUA_PLAYER_DEATH_TRANSITION_PASS ' .. count)
