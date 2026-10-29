local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local focus,device=nil,true
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus',LostFocus='blur'},directions={Left='left',Right='right'},
    modes={Specified='specified',NearestControl='nearest'},getFocus=function()return focus end,
    setFocus=function(value)
        if focus and focus.navigationListeners and focus.navigationListeners.blur then focus.navigationListeners.blur()end
        focus=value
        if value and value.navigationListeners and value.navigationListeners.focus then value.navigationListeners.focus()end
    end,isController=function()return device end}
local pointer={CursorDown='down',CursorUp='up',CursorEndDrag='end',CursorDrag='drag',CursorEnter='enter',CursorExit='exit'}
local ui,root=F.fixture(nil,nil,nil,pointer,false,nil,nil,api)
local function hit(panel,path)
    local c=root:GetChild(panel)
    for name in path:gmatch('[^/]+')do c=assert(c:GetChild(name),path)end
    return c:GetChild('hit') or c
end
local function ready()
    for _=1,400 do if not ui.battleUI.busy then break end;ui:update(.05)end
    ui:update(.01)
end
local function event(control,name)
    ui:update(.01);ui:syncController()
    assert(control.canControllerFocus,'unavailable controller target '..control.name)
    api.setFocus(control)
    return assert(control.navigationListeners[name or 'confirm'],'missing controller listener')(nil)
end
local function usePotion(name)
    event(hit('battlePanel',name))
    assert(ui.battleUI.potionMenu and ui.controller.scope=='battlePotion')
    event(hit('battlePanel','potionHelp/potionPopup/use'))
end
assert(focus==hit('menuPanel','start'),'title must have default focus')
event(focus);assert(ui.characterOpen and not ui.run)
event(hit('characterPanel','traveler'));event(hit('characterPanel','confirm'));assert(ui.mode=='map')
assert(focus and focus.parent.name:match('node'),'map defaults to an available route')
event(focus);assert(ui.mode=='battle' and ui.map.floor==1)
local battle=ui.run.combat
local slot
for i,card in ipairs(battle.hand)do if F.Combat.cardDefinition(battle,card).type=='attack' then slot=i;break end end
local card=hit('battlePanel','card'..slot)
-- Observing pointer input must not make later gamepad confirms depend on Up/Click.
card.listeners.down({touchId=7});card.listeners.up({touchId=7})
event(card);assert(ui.battleUI.selected==battle.hand[slot].uid)
card.listeners.click();assert(ui.battleUI.selected==battle.hand[slot].uid,'native Click accompanying Confirm must not toggle the card back off')
ui:update(.01);card.listeners.click({touchId=7})
assert(ui.battleUI.selected==battle.hand[slot].uid,'a delayed click from before gamepad confirmation must not undo the selection')
assert(ui.controller.scope=='aim' and focus.parent.name=='enemy1')
local energy,hp=battle.energy,battle.enemies[1].hp
event(focus,'cancel');assert(not ui.battleUI.selected and battle.energy==energy and battle.enemies[1].hp==hp)
assert(focus==card,'cancel restores the originating hand slot')
event(card);event(focus);ready()
assert(battle.energy<energy and battle.enemies[1].hp<hp,'confirm must actually play the selected attack')
local skill
for i,c in ipairs(battle.hand)do if F.Combat.cardDefinition(battle,c).type=='skill' then skill=i;break end end
assert(skill)
event(hit('battlePanel','card'..skill));assert(ui.controller.scope=='aim')
assert(focus==hit('battlePanel','playArea'),'untargeted card defaults to its explicit confirmation area')
local block=battle.player.block
event(focus);ready();assert(battle.player.block>block)
event(hit('deckEntry','open'));assert(ui.deckUI.visible and ui.controller.scope=='deck')
assert(not card.canControllerFocus,'deck blocks the battle below it')
event(focus,'cancel');assert(not ui.deckUI.visible and ui.controller.scope=='battle')
event(hit('exitEntry','open'));assert(ui.exitOpen and ui.menuOpen and focus and focus.parent.parent.name=='runMenu')
event(hit('runMenu','abandon'));assert(ui.exitOpen and not ui.menuOpen and focus==hit('exitPanel','cancel'))
local run=ui.run
event(focus,'cancel');assert(not ui.exitOpen and ui.run==run,'exit state='..tostring(ui.exitOpen)..' scope='..tostring(ui.controller.scope)..' sameRun='..tostring(ui.run==run))
event(hit('battlePanel','endTurn'));ready();assert(battle.turn==2)
assert(Run.obtainPotion(ui.run,'fire_potion'));ui:refresh()
usePotion('potion1');assert(ui.battleUI.potionAim and #ui.run.potions==1)
event(focus,'cancel');assert(not ui.battleUI.potionAim and #ui.run.potions==1)
usePotion('potion1')
assert(focus==hit('battlePanel','enemy1'),'potion defaults to an enemy; got '..focus.name..'/'..focus.parent.name)
local potionHp=battle.enemies[1].hp
local potionOk,potionReason=event(focus);ready();assert(#ui.run.potions==0 and battle.enemies[1].hp<potionHp,
    'potion result='..tostring(potionOk)..'/'..tostring(potionReason)..' count='..#ui.run.potions..' hp='..battle.enemies[1].hp..' before='..potionHp)
-- Real rewards with a deterministic victory fixture; select through native events.
for _,enemy in ipairs(battle.enemies)do enemy.hp=0 end
assert(Run.finishCombat(ui.run));ui:refresh();ready()
event(hit('battlePanel','cardReward'));assert(ui.battleUI.rewardScreen=='cards')
local left=hit('battlePanel','card1')
assert(left.navigation.left.target.parent.name=='card3','reward row wraps at the ends')
api.setFocus(left);assert(ui.battleUI.hover==1)
api.setFocus(hit('battlePanel','skip'));assert(ui.battleUI.hover==nil,'leaving a reward card must clear its enlarged hover pose')
local deck=#ui.run.deck
event(left);assert(#ui.run.deck==deck+1)
print('controller host: native menu/map, pointer switch, target/cancel/play, untargeted play, overlays, turn and reward passed')
ui:disable();assert(not focus or not focus.canControllerFocus)
ui,root=F.fixture(nil,nil,nil,pointer,true,nil,nil,api)
event(hit('menuPanel','start'));assert(ui.characterOpen and ui.controller.scope=='characters' and not ui.run)
event(hit('characterPanel','traveler'));event(hit('characterPanel','confirm'))
assert(ui.prologue:covering() and ui.controller.scope=='prologue')
event(focus,'cancel');ui:update(1);ui:update(1)
assert(ui.mode=='map' and not ui.prologue:covering())
event(focus);assert(ui.mode=='battle')
local choiceBattle=ui.run.combat
choiceBattle.hand={{uid=1000,cardId='strike'},{uid=1001,cardId='defend'}}
assert(Run.obtainPotion(ui.run,'elixir'));ui:refresh()
usePotion('potion1');ready();ui:update(.01)
assert(ui.deckUI.visible and choiceBattle.pendingChoice.multiple)
local token=choiceBattle.pendingChoice.token
event(focus,'cancel');assert(ui.deckUI.visible and choiceBattle.pendingChoice.token==token,
    'Back on a core selection cannot submit its selected cards')
local grid=root:GetChild('deckPanel'):GetChild('grid')
local first=grid.items[0]:GetChild('hit')
event(first);ready();ui:update(.01)
assert(ui.deckUI.visible and #choiceBattle.pendingChoice.selected==1)
event(hit('deckPanel','close'));ready()
assert(not choiceBattle.pendingChoice and #choiceBattle.exhaust==1)
ui:disable()
print('controller host: prologue skip and mandatory multiple selection cancel/confirm passed')
