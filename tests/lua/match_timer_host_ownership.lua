local H=dofile('tests/helpers/act2_event_ui.lua')
for _,variant in ipairs({'host','root','reparent-render','nested-host-swap','host-reparent','host-root-swap','host-panel-reparent'})do
local r,m=H.fixture('match_game');local ui,get,shown,click,changes,root,host=H.setup(r,m)
assert(click('eventView/option1'));assert(click('eventView/option1'))
local pair
for i,a in ipairs(r.nodeFlow.event.board)do for j,b in ipairs(r.nodeFlow.event.board)do if i<j and a.cardId==b.cardId then pair={i,j};break end end;if pair then break end end
assert(pair);assert(click('pickerView/forgeGrid/card'..pair[1]));assert(click('pickerView/forgeGrid/card'..pair[2]))
local before=H.snapshot(r);local n=#r.deck
local panel=root:GetChild('pickerView')
if variant=='host'then host.children.nodePanel=H.control({name='nodePanel',children={}},host)
elseif variant=='root'then ui.root={}
elseif variant=='reparent-render'then
 local foreign=H.control({name='foreign',children={}});foreign.children.nodePanel=root;root.parent=foreign;ui:render()
elseif variant=='nested-host-swap'then
 local original=root.GetChild
 root.GetChild=function(owner,name)
  local child=original(owner,name)
  if name=='pickerView'then host.children.nodePanel={};root.GetChild=original end
  return child
 end
else
 local original=host.GetChild
 host.GetChild=function(owner,name)
  local child=original(owner,name);host.GetChild=original
  if variant=='host-reparent'then root.parent={}
  elseif variant=='host-root-swap'then ui.root={}
  else panel.parent={}end
  return child
 end
end
-- Do not pre-observe actions for reentry probes: the timer must perform the
-- injected native read itself, not consume it through the separately guarded input.
if variant=='host'or variant=='root'or variant=='reparent-render'then
 assert(not ui.actions['pickerView/forgeGrid/card1'].observe())
end
ui:update(2);H.same(r,before)
host.children.nodePanel=root;ui.root=root;root.parent=host;panel.parent=root;ui:update(2);H.same(r,before)
ui:render();ui:update(2);H.eq(#r.deck,n+1);H.eq(r.nodeFlow.event.attemptsLeft,4)
ui:update(2);H.eq(#r.deck,n+1)
end
print('MATCH_TIMER_HOST_PASS')
