local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Candidate=require('abyss_run_potion_candidate')
local DamageView=require('abyss_battle_damage_view')
local Surfaces=require('abyss_monster_surfaces')
local host,ui,panel,event=H.setup({'defend'},{'cultist'})
host.run.potions={'fire_potion','block_potion','energy_potion'};host:refresh()
local enemy=assert(Surfaces.get(panel):find(host.run.combat.enemies[1].id))
event('potion1','down',7)
event('potion1','drag',7,enemy.x,enemy.y)
assert(ui.potionAim and ui.potionAim.moving)
local original,calls,live=Candidate.prepare,0,0
local render,preview,renders,previews=ui.render,DamageView.potionPreview,0,0
ui.render=function(self,...)renders=renders+1;return render(self,...)end
DamageView.potionPreview=function(...)previews=previews+1;return preview(...)end
Candidate.prepare=function(run,...)
 calls=calls+1;if run==host.run then live=live+1 end
 return original(run,...)
end
local hp=host.run.combat.enemies[1].hp
local frames=ABYSS_RUNTIME_FRAMES or 30
for _=1,frames do event('potion1','drag',7,enemy.x,enemy.y)end
Candidate.prepare=original
ui.render=render;DamageView.potionPreview=preview
print('POTION_DRAG_HOTPATH events='..frames..' totalCandidates='..calls..' liveCandidates='..live..' renders='..renders..' previews='..previews)
assert(renders==frames and previews==frames,'drag redraw/preview freshness changed')
assert(host.run.combat.enemies[1].hp==hp and host.run.potions[1]=='fire_potion','preview changed the live outcome')
if not ABYSS_RUNTIME_BASELINE then assert(live==frames*4,'drag preflight simulated unrelated potion slots')end
-- Same coordinates, same identity, changed mutable candidate state. The fresh
-- preflight must reject without redrawing the previously valid pointer.
host.run.combat.pendingChoice={}
local x,y=ui.potionAim.x,ui.potionAim.y
event('potion1','drag',7,enemy.x+2,enemy.y)
assert(ui.potionAim and ui.potionAim.x==x and ui.potionAim.y==y,'stale drag candidate accepted an in-place rule change')
host.run.combat.pendingChoice=nil
event('potion1','drag',7,enemy.x+2,enemy.y)
assert(ui.potionAim.x~=x,'fresh drag preflight failed to recover')
event('dragLayer','up',7,enemy.x,enemy.y)
assert(not ui.potionAim and host.run.potions[1]==nil,'fresh drag release did not commit')
print('POTION_DRAG_HOTPATH_PASS fresh/state-change/recovery/use')
