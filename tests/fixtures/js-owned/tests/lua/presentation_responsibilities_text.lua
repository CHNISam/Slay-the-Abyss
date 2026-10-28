package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Trace=dofile('tests/lua/support/presentation_trace.lua')
local P=require('abyss_character_presentation')
local Profiles=require('abyss_character_profiles')
local Data=require('abyss_data')
local Existing=require('abyss_presentation')
local trace=Trace.new()
for _,id in ipairs({'ironclad','silent','defect','watcher'})do
    local prepared=Profiles.prepare(Data,id)
    local shown=P.prepare(Existing,prepared)
    for _,card in ipairs(prepared.cards.cards)do
        trace:add({id,card.id,shown[card.id]})
    end
end
-- A nested effect keeps the original dynamic path, validation and punctuation.
local conditional={id='probe',name='测试',type='attack',cost=1,
    effects={{op='conditional',['if']='target_poison',['then']={{op='damage',value=7}}}}}
local shown=P.prepare({},{cards={cards={conditional}}}).probe
assert(shown.text=='若目标有中毒，对目标造成 7 点伤害。')
assert(shown.combatText=='若目标有中毒，对目标造成 {effects.0.then.0.value} 点伤害。')
trace:add(shown)
local orb={id='probe',name='测试',type='skill',cost=1,
    effects={{op='channelOrb',orb='lightning',value=1},{op='channelOrb',orb='lightning',value=1}}}
assert(P.prepare({},{cards={cards={orb}}}).probe.text=='生成 2 个闪电球。')
for _,effect in ipairs({{op='invented',value=1},{op='channelOrb',orb='unknown',value=1}})do
    conditional.effects={effect};assert(not pcall(P.prepare,{},{cards={cards={conditional}}}))
end
print('PRESENTATION_WORDING_TRACE '..trace.count..' '..string.format('%.0f',trace.hash))
-- Filled from the independently executed pre-refactor implementation.
-- This records every base/upgrade/static/live display field in source order.
assert(trace.count==361 and trace.hash==1837256485,'wording changed from the frozen native contract')
