package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Trace=dofile('tests/lua/support/presentation_trace.lua')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Map,Nodes,Combat=require('abyss_run'),require('abyss_map'),F.Nodes,F.Combat
local trace=Trace.new()
local host,root=F.fixture(nil,function(victory)trace:add({'settle',victory});return true end,
    function(cue)trace:add({'music',cue})end,nil,nil,function(cue)trace:add({'sound',cue})end)
trace:attach(root)
host:refresh()
assert(host:openExit());assert(host:closeExit())
assert(host:start());host:refresh()
assert(host:openDeck());assert(host:closeDeck())
assert(host:openPotions());assert(host:closePotions())
-- A real camp flow exercises picker labels, card selection and continuation.
local run,map=Run.new(F.Data,42),Map.generate(F.Data,42)
while true do
    local choices=Map.available(map);assert(#choices>0)
    local found
    for _,node in ipairs(choices)do if node.type=='camp'then found=node;break end end
    if found then assert(Nodes.enter(run,map,found.id));break end
    assert(Map.choose(map,choices[1].id))
end
host.run,host.map=run,map;host.battleUI.run=run;host.mapUI.map=map
host.nodeUI.run,host.nodeUI.map=run,map
host.nodeUI:render();host:refresh()
assert(host.mode=='node')
local nodePanel=root:GetChild('nodePanel')
assert(nodePanel:GetChild('campView'):GetChild('forge'):GetChild('hit').click())
assert(nodePanel:GetChild('pickerView'):GetChild('forgeGrid'):GetChild('card1'):GetChild('hit').click())
assert(nodePanel:GetChild('confirm'):GetChild('hit').click())
host:refresh()
-- Committed combat events, independent VFX clocks and overlay input ownership.
run.phase='map';run.nodeFlow=nil
assert(Run.startCombat(run,'cultist_solo'))
run.combat=Combat.new(F.Data,{deck={'strike','defend'},enemies={'cultist','cultist'},seed=11})
host:refresh()
local panel=root:GetChild('battlePanel')
local slot
for i,card in ipairs(run.combat.hand)do if card.cardId=='strike'then slot=i end end
assert(slot);panel:GetChild('card'..slot):GetChild('hit').click()
panel:GetChild('enemy1'):GetChild('hit').click()
assert(host.battleUI.busy)
for _=1,70 do host:update(0.01)end
assert(not host.battleUI.busy)
assert(host:openExit());local before=Combat.copy(run);host:update(0.25)
assert(run.combat.player.hp==before.combat.player.hp and run.combat.rng==before.combat.rng)
assert(host:closeExit());host:refresh()
for _=1,70 do host:update(0.01)end
assert(next(host.battleUI.feedback.effects)==nil)
trace:assertNativeInteraction()
print('PRESENTATION_NATIVE_TRACE '..trace.count..' '..string.format('%.0f',trace.hash))
-- The immutable room-port fixture is replayed separately at 79543/1215629804.
-- PR256/268 add 214 card-frame writes and change exactly 593 reviewed visual
-- writes; the remaining 78950 writes retain their values and global order.
assert(trace.count==79757 and trace.hash==1467902785,'ordered native writes changed from the reviewed M3 visual contract')
