local F=dofile('tests/lua/support/game_ui_fixture.lua')
local host,root=F.fixture()
assert(F.start(host));assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
local battle=F.Combat.new(F.Data,{enemies={'looter','acid_slime_m'},deck={'strike'},seed=11})
local actor=battle.enemies[1]
for i,intent in ipairs(actor.intents)do if intent.id==actor.ai.escapeIntent then actor.intentIndex=i end end
host.run.combat=battle;host:refresh()
local manager=require('abyss_monster_surfaces').get(root:GetChild('battlePanel'))
local box=assert(manager:find(actor.id));local art=box:GetChild('monsterArt')
local survivor=manager:find(battle.enemies[2].id);local survivorX,survivorY=survivor.x,survivor.y
host.battleUI:endTurn()
local feedback=host.battleUI.feedback
for _=1,1000 do if feedback.escaping[actor.id]then break end;host:update(.01)end
assert(feedback.escaping[actor.id],'real escape contact missing')
host:update(.01)
assert(art.visible and art.scale[1]<0 and art.x>0,'original movement and flip must reach actual native drawing')
for _,name in ipairs({'hpBorder','hpTrack','hpGhost','hpFill','hp','blockEdge','blockIcon','block','name','statusRow','intentIcon','intentBadge','intentExtra','intent','intentHit'})do
 assert(not box:GetChild(name).visible,'escaping source HUD must stay hidden: '..name)
end
local age=feedback.escaping[actor.id].timer;local x=art.x
host.battleUI:render()
assert(feedback.escaping[actor.id].timer==age and art.x==x and art.scale[1]<0,'render must preserve escape timer/pose')
assert(not box:GetChild('statusRow').visible and not box:GetChild('hp').visible,'rerender restored escaping HUD')
assert(survivor.x==survivorX and survivor.y==survivorY,'escape must not reflow survivor')
for _=1,600 do if not box.alive then break end;host:update(.01)end
assert(not box.alive and not manager:find(actor.id),'terminal escape did not release actual native unit')
host:disable()
print('ORIGINAL_ESCAPE_GAME_UI_PASS')
