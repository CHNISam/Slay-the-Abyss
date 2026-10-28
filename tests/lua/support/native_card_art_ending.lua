-- One focused offline integration: real GameUI / Run / Heart / Proceed.
-- Controlled deck, earned history/keys, skipped preceding rooms, zeroed Heart HP.
-- NOT a natural route, native engine, real-art provenance or platform acceptance.
-- The JS entrypoint supplies its generated one-host candidate module path.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local S=dofile('tests/lua/support/ending_proceed_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Display=require('abyss_card_display')
local function get(root,path)
 local c=root;for part in path:gmatch('[^/]+')do c=assert(c:GetChild(part),path)end;return c
end
local function shown(c)
 -- Native visible is own state, not inherited visibility. Read hierarchy only
 -- on ordinary controls (the art helper intentionally forbids that extra field).
 while c do if c.visible==false then return false end;c=c.parent end;return true
end
local function eq(a,b,message)assert(a==b,(message or '')..': '..tostring(a)..' ~= '..tostring(b))end
local focus,usingController,settled=nil,false,0
local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
 modes={Specified='specified',NearestControl='nearest'},isController=function()return usingController end,
 getFocus=function()return focus end,setFocus=function(c)assert(c);focus=c end}
local cursor={CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag',CursorEnter='enter',CursorExit='exit'}
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local face=get(root,'battlePanel/card1')
local pool=get(face,'artSamples')
-- Reuse the strict native image/transform contract on the one enabled pool.
-- All other controls retain game_ui_fixture's strict CursorArea fields and
-- documented read-only activeInHierarchy (required by the actual Proceed UI).
Native.decorate(pool)
local first,tail=get(pool,'group000/shape0000'),get(pool,'group000/shape0001')
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=42,prologue=false,campaign=true,
 cursorEvents=cursor,controllerApi=api,imageSource='static',imageTypes={basic=17,stretch=23},
 color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,settle=function()settled=settled+1;return true end})
root.ui=host;assert(host:start())
local run=host.run
assert(run.character==nil or run.character=='ironclad','ironclad-only fixture')
run.deck={{uid=91,cardId='cleave',upgraded=true}}
local map=S.stage(run)
host.map,host.mapUI.map,host.nodeUI.map=map,map,map
host:refresh()
assert(host.mode=='battle'and run.phase=='combat'and run.combat.enemies[1].definitionId=='corrupt_heart')
local card=assert(run.combat.hand[1]);eq(card.cardId,'cleave')
local function art(enabled,count)
 eq(pool.visible,enabled,'pool own visibility');eq(shown(pool),enabled,'pool effective visibility')
 eq(get(face,'art').visible,not enabled,'fallback visibility')
 eq(first.visible,enabled and count>=1,'first slot');eq(tail.visible,enabled and count>=2,'tail slot')
end
local function textFor(id,cost)
 eq(card.cardId,id,'card_id');local d=assert(F.Combat.cardDefinition(run.combat,card))
 local title=Display.title(F.Presentation[id].name,card.upgraded)
 eq(get(face,'name').text,title,'independent name');eq(get(face,'cost').text,cost,'independent cost')
 eq(get(face,'type').text,'攻击','independent type')
 local preview=F.Combat.cardPreview(run.combat,card,nil)
 eq(get(face,'label').text,Display.combatText(F.Presentation[id],d,card,preview),'independent description')
 return get(face,'name').text,get(face,'label').text
end
art(true,2);local name,description=textFor('cleave','1')
eq(first.imageType,23,'stretch enum forwarded');eq(tail.imageType,17,'basic enum forwarded')
run.combat.player.statuses.strength=7;host:refresh()
local nextName,nextDescription=textFor('cleave','1')
eq(nextName,name,'dynamic damage preserves title');assert(nextDescription~=description,'dynamic description updates')
card.cardId='heavy_blade';host:refresh();art(true,1);textFor('heavy_blade','2')
eq(first.imageId,106056,'card_id changes artwork')
card.cardId='strike';host:refresh();art(false,0);textFor('strike','1')
card.cardId='cleave';host:refresh();art(true,2);textFor('cleave','1')
print('PASS art: one real generated host; card_id cleave -> heavy_blade -> strike fallback -> cleave; independent four live texts; dynamic preview; 2 -> 1 tail clear')

local hit=get(face,'hit')
local down,up,click=hit.listeners.down,hit.listeners.up,hit.listeners.click
down({touchId=11});up({touchId=11});click({touchId=11})
eq(host.battleUI.selected,card.uid,'art does not intercept C-mode selection')
assert(not host.battleUI.busy and run.phase=='combat','selection does not play card')
down({touchId=12});up({touchId=12});click({touchId=12})
eq(host.battleUI.selected,nil,'second fresh tap cancels selection')
down({touchId=13}) -- retain a real old battle pointer callback across transition.
local owner=S.finish(run);host:refresh()
eq(host.mode,'node');eq(run.phase,'ending_proceed')
assert(not get(root,'battlePanel').visible and not face.visible)
assert(not pool.visible and not first.visible and not tail.visible,'transition must explicitly clear bound art')
assert(shown(get(root,'nodePanel/eventView'))and shown(get(root,'nodePanel/confirm/hit')))
eq(get(root,'nodePanel/eventView/name').text,'腐化之心已击败')
eq(get(root,'nodePanel/confirm/label').text,'继续')
assert(not shown(get(root,'menuPanel/result'))and not run.rewards and settled==0)
local frozen=S.C.copy(run,{[run.data]=run.data})
up({touchId=13});click({touchId=13});down({touchId=14});up({touchId=14});click({touchId=14})
host:update(0);host.battleUI:render(true)
S.same(run,frozen);assert(not pool.visible and not first.visible and not tail.visible,'stale battle callbacks revived art')
print('PASS transition: actual Heart combat -> ending_proceed; art pool and slots explicitly clear; stale battle input/render cannot restore art or mutate run')

local confirm=get(root,'nodePanel/confirm/hit')
assert(confirm.activeInHierarchy==true)
local readonly=pcall(function()confirm.activeInHierarchy=false end);assert(not readonly,'native hierarchy must remain read-only')
local stale=host.nodeUI.actions.confirm.handler
assert(host:openExit());assert(not stale());eq(run.phase,'ending_proceed')
assert(host:closeExit());assert(not stale(),'hidden-page closure must stay retired')
-- Ancestor engine inactivity is independent of own visibility. Retire a held
-- callback while inactive; restoring hierarchy must not revive that callback.
stale=host.nodeUI.actions.confirm.handler
confirm.listeners.down({touchId=21})
local nodePanel=get(root,'nodePanel');F.setEngineActive(nodePanel,false)
assert(confirm.visible and not confirm.activeInHierarchy)
host.nodeUI:update(0);assert(not stale());F.setEngineActive(nodePanel,true)
confirm.listeners.up({touchId=21});confirm.listeners.click({touchId=21})
eq(run.phase,'ending_proceed');assert(not stale(),'inactive owner cannot revive')
host.nodeUI:render();host:syncController();host:update(0)
local replaced=host.nodeUI.actions.confirm.handler
confirm.listeners.down({touchId=22})
run.endingProceed=S.C.copy(owner);host.nodeUI:update(0);run.endingProceed=owner
confirm.listeners.up({touchId=22});confirm.listeners.click({touchId=22})
assert(not replaced(),'replaced/restored Proceed owner must not revive stale callback')
eq(run.phase,'ending_proceed')
host.nodeUI:render();host:syncController();host:update(0)
local successful=host.nodeUI.actions.confirm.handler
usingController=true;host:syncController();assert(host.controller:focus(confirm))
assert(confirm.canControllerFocus);confirm.navigationListeners.confirm()
eq(run.phase,'victory');eq(run.ending,'true_victory');eq(host.mode,'victory')
assert(not run.endingProceed and not run.rewards and run.nodeFlow.complete)
assert(shown(get(root,'menuPanel/result'))and not shown(nodePanel))
assert(get(root,'menuPanel/title').text:find('真结局',1,true));eq(F.statValue(root,'floor'),'55 / 55')
-- Descendants may retain own visible=true under a hidden parent; that is not a
-- leak. Require ancestor-aware visibility and the genuinely bound art clear.
assert(confirm.visible and not shown(confirm),'expected inherited hidden child')
assert(not pool.visible and not first.visible and not tail.visible and not shown(pool))
frozen=S.C.copy(run,{[run.data]=run.data})
assert(not successful());assert(not stale());assert(not replaced())
up({touchId=13});click({touchId=13});confirm.navigationListeners.confirm();host:update(0)
S.same(run,frozen);assert(not pool.visible and not first.visible and not tail.visible);eq(settled,0)
print('PASS input: pointer selection/cancel preserved; stale modal/inactive/replaced owner callbacks rejected; fresh controller Proceed -> true_victory exactly once; no implicit settlement')
print('NATIVE_ART_ENDING_TRANSITION_PASS 1 focused integration; synthetic two-slot/one-host; native engine/real asset/natural route/save import NOT_RUN')
