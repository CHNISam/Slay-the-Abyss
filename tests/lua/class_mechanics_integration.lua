package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Combat = require('abyss_combat')
local Stances = require('abyss_stances')
local Orbs = require('abyss_orbs')
local data = require('abyss_data')
local count = 0
local function test(name, fn) fn(); count=count+1; print('ok class integration '..count..' - '..name) end
local function eq(a,b) assert(a==b, tostring(a)..' ~= '..tostring(b)) end
local function new(options)
    options = options or {}; if options.orbSlots then options.orbRandomSeed='42' end; options.deck={'strike'}; options.enemies={'jaw_worm'}
    local s=assert(Combat.new(data,options))
    s.enemies[1].hp=1000; s.enemies[1].maxHp=1000
    return s
end
test('default constructor does not enable experimental mechanics',function()
    local s=new(); eq(s.orbs,nil); eq(s.player.stance,nil)
    eq(Combat.attackAmount(s,s.player,s.enemies[1],6),6)
end)
test('stance changes affect the real card play entry',function()
    local s=new({enableStances=true})
    assert(Stances.change(s,'Wrath')); Stances.flush(s)
    local hp=s.enemies[1].hp
    assert(Combat.play(s,s.hand[1].uid,1)); eq(hp-s.enemies[1].hp,12)
    eq(Combat.attackAmount(s,s.enemies[1],s.player,6),12)
    eq(Combat.attackAmount(s,s.enemies[1],s.player,6,true),6)
end)
test('stance multipliers precede final rounding',function()
    local s=new({enableStances=true})
    assert(Stances.change(s,'Wrath')); Stances.flush(s)
    s.player.statuses.weak=1
    eq(Combat.attackAmount(s,s.player,s.enemies[1],3),4)
end)
test('divinity expires at the real next player turn',function()
    local s=new({enableStances=true})
    assert(Stances.change(s,'Divinity')); Stances.flush(s); eq(s.energy,6)
    assert(Combat.startPlayerTurn(s)); eq(s.player.stance,'Neutral'); eq(s.energy,3)
end)
test('plasma grants energy after refresh in the real player turn',function()
    local s=new({orbSlots=3})
    Orbs.channel(s,'plasma',Combat)
    assert(Combat.startPlayerTurn(s)); eq(s.energy,4)
end)
test('orb damage at end turn prevents a defeated last enemy acting',function()
    local s=new({orbSlots=3})
    s.enemies[1].hp=3; s.enemies[1].block=0
    Orbs.channel(s,'lightning',Combat)
    local hp=s.player.hp
    assert(Combat.endTurn(s)); eq(s.phase,'victory'); eq(s.player.hp,hp)
end)
test('Blade Dance pays once then generated Shivs use the real play and exhaust path',function()
    local Silent=require('abyss_silent')
    for _,upgraded in ipairs({false,true}) do
        local s=assert(Combat.new(Silent.withFoundationCards(data),{
            deck={{cardId='blade_dance',upgraded=upgraded}},enemies={'jaw_worm'}}))
        local hp=s.enemies[1].hp
        assert(Combat.play(s,s.hand[1].uid)); eq(s.energy,2)
        eq(#s.hand,upgraded and 4 or 3)
        assert(Combat.play(s,s.hand[1].uid,1)); eq(hp-s.enemies[1].hp,4)
        eq(#s.exhaust,1); eq(#s.discard,1)
    end
end)
print('CLASS_MECHANICS_INTEGRATION_PASS '..count)
