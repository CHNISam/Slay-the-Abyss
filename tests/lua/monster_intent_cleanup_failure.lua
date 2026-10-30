local F=dofile('tests/lua/support/game_ui_fixture.lua')
local api=F.monsterActors();local destroy=api.destroy
local refused,blocked,attempts=nil,false,0
api.destroy=function(control)
 assert(control.alive~=false,'native invalid-handle destroy must not be attempted')
 if control==refused then attempts=attempts+1;if blocked then return false end end
 return destroy(control)
end
local focus
local controller={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},modes={Specified='specified'},
 getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return false end}
local canvas=F.control({children=F.Layout});local root=F.Viewport.apply(canvas,1280,720)
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=1,monsterActors=api,imageSource='static',
 color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,controllerApi=controller})
root.ui=host
assert(F.start(host));assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
host.run.combat=F.Combat.new(F.Data,{enemies={'wizard_gremlin'},deck={'strike'},seed=42});host:refresh();host:update(.51)
local manager=require('abyss_monster_surfaces').get(root:GetChild('battlePanel'))
local box=assert(manager:find(host.run.combat.enemies[1].id));local target=box:GetChild('hit');local intent=box:GetChild('intentHit')
assert(host.controller.byControl[target] and host.controller.byControl[intent],'actual actor controller ownership missing')
for _,layer in ipairs({'intentVfxBehind','intentVfxAfter'})do
 local pool=require('abyss_monster_power_surfaces').get(box:GetChild(layer))
 if pool then pool:each(function(control)refused=control end)end
end
assert(refused,'actual unknown particle required');blocked=true
local ok,reason=pcall(host.disable,host)
assert(not ok and tostring(reason):find('cleanup rejected'),'native destroy rejection must remain explicit')
assert(not host.controller.byControl[target] and not host.controller.byControl[intent],'particle failure skipped actor input retirement')
assert(host.monsterCleanupPending,'failed cleanup lost retry ownership')
local before=attempts;blocked=false
assert(host:disable()==false,'retry stays disabled rather than reactivating')
assert(attempts==before and not host.monsterCleanupPending,'retry must retire known-dead child ownership without calling invalid native handles')
assert(not refused.alive and not box.alive,'native hierarchy left alive after retry')
print('MONSTER_INTENT_CLEANUP_FAILURE_PASS')
