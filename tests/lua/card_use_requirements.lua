-- Fixed constructor targets/types/costs and AbstractCard energy/Entangled gates.
-- Sources: docs/evidence/card-audit-m3/source-identity.json. No canUse override
-- exists in the 30 audited card classes. These are adapter command boundaries,
-- not original-game observations, natural acquisition or complete relic hooks.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C, data = require('abyss_combat'), require('abyss_data')
local cases = {
    {'strike',1,1,'attack','ENEMY'}, {'defend',1,1,'skill','SELF'},
    {'bash',2,2,'attack','ENEMY'}, {'cleave',1,1,'attack','ALL_ENEMY'},
    {'clothesline',2,2,'attack','ENEMY'}, {'iron_wave',1,1,'attack','ENEMY'},
    {'anger',0,0,'attack','ENEMY'}, {'body_slam',1,0,'attack','ENEMY'},
    {'flex',0,0,'skill','SELF'}, {'twin_strike',1,1,'attack','ENEMY'},
    {'pommel_strike',1,1,'attack','ENEMY'}, {'shrug_it_off',1,1,'skill','SELF'},
    {'thunderclap',1,1,'attack','ALL_ENEMY'}, {'uppercut',2,2,'attack','ENEMY'},
    {'inflame',1,1,'power','SELF'}, {'battle_trance',0,0,'skill','NONE'},
    {'bloodletting',0,0,'skill','SELF'}, {'barricade',3,2,'power','SELF'},
    {'carnage',2,2,'attack','ENEMY'}, {'disarm',1,1,'skill','ENEMY'},
    {'dropkick',1,1,'attack','ENEMY'}, {'entrench',2,1,'skill','SELF'},
    {'ghostly_armor',1,1,'skill','SELF'}, {'hemokinesis',1,1,'attack','ENEMY'},
    {'rampage',1,1,'attack','ENEMY'}, {'seeing_red',1,0,'skill','NONE'},
    {'shockwave',2,2,'skill','ALL_ENEMY'}, {'offering',0,0,'skill','SELF'},
    {'impervious',2,2,'skill','SELF'}, {'bludgeon',3,3,'attack','ENEMY'},
}
local count = 0
local function eq(a,b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end
for _, case in ipairs(cases) do
for _, upgraded in ipairs({false, true}) do
    local id, cost, kind, target = case[1], case[upgraded and 3 or 2], case[4], case[5]
    local state = C.new(data, {seed = 42, deck = {{cardId = id, upgraded = upgraded}}, enemies = {'cultist','jaw_worm'}})
    local card = state.hand[1]
    eq(C.cardDefinition(state, card).type, kind)
    state.energy = cost
    assert(C.canPlay(state, card.uid, 1)) -- Dropkick also plays without Vulnerable.
    if target == 'ENEMY' then
        local ok, why = C.canPlay(state, card.uid)
        eq(ok, false); eq(why, 'invalid_target')
        state.enemies[1].hp = 0
        ok, why = C.canPlay(state, card.uid, 1)
        eq(ok, false); eq(why, 'invalid_target')
        assert(C.canPlay(state, card.uid, 2)) -- Still require the selected live foe.
        state.enemies[1].hp = 50
    else
        assert(C.canPlay(state, card.uid)) -- SELF/NONE/ALL_ENEMY needs no selected foe.
    end
    if cost > 0 then
        state.energy = cost - 1
        local ok, why = C.canPlay(state, card.uid, 1)
        eq(ok, false); eq(why, 'insufficient_energy')
        state.energy = cost
    end
    C.addStatus(state.player, 'entangled', 1)
    local ok, why = C.canPlay(state, card.uid, 1)
    eq(ok, kind ~= 'attack')
    if kind == 'attack' then eq(why, 'entangled') end
    eq(#state.hand, 1); eq(state.hand[1], card); eq(state.energy, cost)
    count = count + 1
    print('ok card_use_requirements ' .. count .. ' - ' .. id .. (upgraded and '+' or '') .. ' target, exact-energy and Entangled gates')
end
end
print('LUA_CARD_USE_REQUIREMENTS_PASS ' .. count)
