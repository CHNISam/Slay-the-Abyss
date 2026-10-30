local actorControl=dofile('tests/lua/support/game_ui_fixture.lua').actorControl
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Controller=require('abyss_run'),require('abyss_controller')
local count=0
for _,action in ipairs({'cancel','confirm'})do for _,anonymous in ipairs({false,true})do
 local focus,device=nil,false
 local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
  modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(value)focus=value end,
  isController=function()return device end}
 local pointer={CursorDown='down',CursorUp='up',CursorEndDrag='endDrag',CursorDrag='drag',CursorEnter='enter',CursorExit='exit'}
 local h,root=F.fixture(nil,nil,nil,pointer,false,nil,nil,api)
 assert(F.start(h));assert(Run.startCombat(h.run,'cultist_solo'))
 h.run.combat=F.Combat.new(F.Data,{deck={'defend','defend'},enemies={'cultist','jaw_worm'}})
 assert(Run.obtainPotion(h.run,'fire_potion'));h:refresh()
 local u,p=h.battleUI,root:GetChild('battlePanel')
 local function emit(name,kind,touch,x,y)
  local c=F.actorControl(p,name);local hit=c.listeners and c or c:GetChild('hit')
  return assert(hit.listeners[kind])({touchId=touch,GetUIPos=function()return 640+(x or c.x or 0),360+(y or c.y or 0)end})
 end
 local function drain()for _=1,400 do if not u.busy then return end;h:update(.05)end;assert(not u.busy)end
 local touch=not anonymous and 7 or nil
 local enemy=actorControl(p,"enemy2");local hp=h.run.combat.enemies[2].hp
 emit('potion1','down',touch);emit('potion1','drag',touch,enemy.x,enemy.y)
 assert(u.potionAim and u.potionAim.moving)
 device=true;h:syncController()
 assert(h.controller.scope=='aim' and focus and focus.canControllerFocus)
 if action=='cancel'then
  assert(focus.navigationListeners.cancel(),'actual controller Cancel did not dismiss moving aim')
 else
  assert(focus.navigationListeners.confirm()==false,'controller Confirm must refuse the invalidated physical drag token')
 end
 assert(not u.potionAim and Run.potionCount(h.run)==1 and h.run.combat.enemies[2].hp==hp)
 assert(Controller.pointerBlocked(h.controller),'controller must retain its existing one-frame block')
 h:update(.01);assert(not Controller.pointerBlocked(h.controller))
 if anonymous then
  p:GetChild('endTurn').click();assert(h.run.combat.turn==1,'anonymous '..action..' drag bypassed first ambiguous Click')
 else
  emit('endTurn','click',7);emit('endTurn','click',7)
  assert(h.run.combat.turn==1,'controller '..action..' exposed the old named potion origin')
 end
 -- A real controller confirm still works, without borrowing an old pointer token.
 h:syncController();local turn=p:GetChild('endTurn');assert(turn.canControllerFocus)
 api.setFocus(turn);turn.navigationListeners.confirm();assert(h.run.combat.turn==2);drain();h:update(.01)
 if not anonymous then
  emit('endTurn','click',7);assert(h.run.combat.turn==2,'controller confirm revived old potion origin')
 end
 emit('endTurn','down',touch);emit('endTurn','up',touch);emit('endTurn','click',touch)
 assert(h.run.combat.turn==3,'fresh physical press could not reclaim cancelled potion origin')
 assert(Run.potionCount(h.run)==1 and h.run.potions[1]=='fire_potion')
 count=count+1;print('POTION_CONTROLLER_CANCEL_CASE '..count)
end end
assert(count==4)
print('POTION_CONTROLLER_CANCEL_PASS 4; controlled/offline only')
