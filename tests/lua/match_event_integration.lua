-- Controlled public Nodes + composition-root/native-mock integration.
-- Source boards are inspected only by this test; concealed UI state stays detached.
local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
local Theme=require('abyss_theme')
local function playing()
 local r,m=H.fixture('match_game');local ui,get,shown,click=H.setup(r,m)
 eq(get('eventView/name').text,'留影牌局');assert(shown('eventView'))
 H.parity(r,m,'continue',nil,function()return click('eventView/option1')end)
 H.parity(r,m,'start',nil,function()return click('eventView/option1')end)
 return r,m,ui,get,shown,click
end
local function token(ui,index)return ui.view.node.event.match.slots[index].token end
local function pairsOf(r)
 local result,first={},{}
 for i,card in ipairs(r.nodeFlow.event.board)do
  if first[card.cardId]then result[#result+1]={first[card.cardId],i};first[card.cardId]=nil
  else first[card.cardId]=i end
 end
 return result
end
local function timed(r,m,ui,choice,key,seconds)
 local expected,mapBefore=H.snapshot(r),H.Copy(m)
 assert(H.Nodes.chooseEvent(expected,choice,ui.view.node.event.match[key]))
 ui:update(seconds);same(r,expected);same(m,mapBefore)
end
test('production composition selects one reused Match board without disclosing concealed identities or exit controls',function()
 local r,m,ui,get,shown=playing();local before,mapBefore=H.snapshot(r),H.Copy(m)
 eq(ui.picker,'match_board');eq(ui.mode,'picker');eq(ui.pageCount,1)
 assert(shown('pickerView/forgeGrid'));assert(not shown('eventView'))
 for _,path in ipairs({'back','confirm','pickerView/previous','pickerView/next','pickerView/forgePrevious','pickerView/forgeNext','pickerView/matchRetry'})do assert(not shown(path),path)end
 assert(ui.view.node.event.board==nil)
 for i,slot in ipairs(ui.view.node.event.match.slots)do
  eq(slot.cardId,nil);eq(slot.uid,nil)
  assert(shown('pickerView/forgeGrid/card'..i..'/matchBack'))
  eq(get('pickerView/forgeGrid/card'..i..'/name').text,'')
  eq(get('pickerView/forgeGrid/card'..i..'/description').text,'')
 end
 ui:render();same(r,before);same(m,mapBefore)
end)
test('production native flips and timed awards run five attempts, cleanup, result and separate final Leave exactly once',function()
 local r,m,ui,get,shown,click=playing();local pairs=pairsOf(r);local count=#r.deck
 local stale
 for n=1,5 do
  local a,b=pairs[n][1],pairs[n][2]
  local first=ui.actions['pickerView/forgeGrid/card'..a].handler
  H.parity(r,m,'flip',token(ui,a),function()return click('pickerView/forgeGrid/card'..a)end)
  H.unchanged(r,m,first)
  assert(get('pickerView/forgeGrid/card'..a..'/name').text~='')
  H.parity(r,m,'flip',token(ui,b),function()return click('pickerView/forgeGrid/card'..b)end)
  eq(r.nodeFlow.event.stage,'resolving');stale=ui.actions['pickerView/forgeGrid/card'..b].handler
  ui:update(.9);eq(#r.deck,count+n-1)
  timed(r,m,ui,'resolve','resolveToken',.1);eq(#r.deck,count+n)
  H.unchanged(r,m,stale);ui:update(0);eq(#r.deck,count+n)
 end
 eq(r.nodeFlow.event.stage,'cleanup');assert(shown('pickerView'));assert(not shown('back'))
 ui:update(.9);eq(r.nodeFlow.event.stage,'cleanup')
 timed(r,m,ui,'finish','completionToken',.1);eq(r.nodeFlow.event.stage,'result')
 eq(ui.mode,'main');assert(shown('eventView'));assert(not shown('pickerView'))
 H.parity(r,m,'leave',nil,function()return click('eventView/option1')end)
 eq(r.phase,'map');eq(r.nodeFlow.complete,true);eq(#r.deck,count+5)
end)
test('hide/show and resize retire old Match actions while rearming resolving timers; changing owners restores ordinary picker geometry',function()
 local r,m,ui,get,shown,click=playing();local pair=pairsOf(r)[1]
 local old=ui.actions['pickerView/forgeGrid/card1'].handler
 ui:resize(1600,900);H.unchanged(r,m,old)
 H.parity(r,m,'flip',token(ui,pair[1]),function()return click('pickerView/forgeGrid/card'..pair[1])end)
 H.parity(r,m,'flip',token(ui,pair[2]),function()return click('pickerView/forgeGrid/card'..pair[2])end)
 local prior=H.snapshot(r);local oldSecond=ui.actions['pickerView/forgeGrid/card'..pair[2]].handler
 ui:update(.9);ui:setVisible(false);ui:update(100);same(r,prior)
 ui:setVisible(true);H.unchanged(r,m,oldSecond);ui:update(.9);same(r,prior)
 timed(r,m,ui,'resolve','resolveToken',.1)
 old=ui.actions['pickerView/forgeGrid/card1'].handler
 local nextRun,nextMap=H.fixture('duplicator',{{uid=7,cardId='strike'}})
 ui.run,ui.map=nextRun,nextMap;ui:render();H.unchanged(nextRun,nextMap,old)
 assert(click('eventView/option1'));assert(click('pickerView/card1'))
 assert(shown('pickerView/target'));assert(get('pickerView/label').text:find('复制'))
 local values=Theme.layout.nativeNode.picker.label
 eq(get('pickerView/label').x,values[1]);eq(get('pickerView/label').y,values[2])
 for i=1,12 do eq(get('pickerView/forgeGrid/card'..i..'/matchBack').visible,false)end
 eq(get('pickerView/matchRetry').visible,false)
end)
test('native late resolve failure stays on the same pair and only an explicit retry can award',function()
 local r,m,ui,get,shown,click=playing();local pair=pairsOf(r)[1]
 assert(click('pickerView/forgeGrid/card'..pair[1]));assert(click('pickerView/forgeGrid/card'..pair[2]))
 local before=H.snapshot(r);local original=H.Hooks.onObtainCard
 H.Hooks.onObtainCard=function()return false,'controlled_native_match_failure'end
 ui:update(2);same(r,before);assert(shown('pickerView/matchRetry'))
 ui:update(100);same(r,before)
 ui:setVisible(false);ui:setVisible(true);ui:update(100);same(r,before);assert(shown('pickerView/matchRetry'))
 H.Hooks.onObtainCard=original
 H.parity(r,m,'resolve',ui.view.node.event.match.resolveToken,function()return click('pickerView/matchRetry')end)
 eq(#r.deck,#before.deck+1);assert(not shown('pickerView/matchRetry'))
 eq(get('pickerView/hint').text,'请选择两张石牌')
end)
print('MATCH_EVENT_INTEGRATION_PASS '..H.count)
