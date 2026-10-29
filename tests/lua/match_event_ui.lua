local H=dofile('tests/helpers/match_event.lua')
local ok,UI=pcall(require,'abyss_match_event_ui')
assert(ok and type(UI.install)=='function','native Match UI leaf must exist')
local control=dofile('tests/lua/support/game_ui_fixture.lua').control
local function find(list)
 for _,item in ipairs(list)do if item.name=='pickerView'then return item end
  local found=item.children and find(item.children);if found then return found end
 end
end
local Layout=assert(ABYSS_MATCH_LAYOUT or find(require('abyss_ui_layout')),'Match test must use the generated native layout')
local eq,same,test=H.eq,H.same,H.test
local function setup(r,beforeRender)
 local root=control({name='host',kind='container',children={Layout}});local self={run=r,map={},visible=true,actions={},busy=false}
 self.root=root
 local ctx={root=root,self=self,options={imageSource='static',color=function(a,b,c,d)return {r=a,g=b,b=c,a=d}end}}
 ctx.self.presentation=require('abyss_presentation')
 function ctx.child(name)return assert(root:GetChild(name),name)end
 function ctx.show(c,v)c:SetVisible(v~=nil and v~=false)end
 function ctx.ink()end;function ctx.tint()end
 function ctx.picture(c,id)c:SetImage('static',id)end
 ctx.inspectCards,ctx.skinFaces,ctx.artFaces={},{},{}
 function ctx.state(c,enabled)for _,name in ipairs({'normal','disabled','hover','pressed','selected'})do c:GetChild(name):SetVisible(name==(enabled and'normal'or'disabled'))end end
 function ctx.action(key,enabled,fn,reason,_,observe)self.actions[key]={enabled=enabled,handler=fn,reason=reason,observe=observe}end
 require('abyss_node_ui_faces').install(ctx);UI.install(ctx)
 if beforeRender then beforeRender(ctx)end
 local function render()
  self.view={node={type='event',event=H.view(r)}};self.actions={};ctx.renderMatch(self.view,self.view.node)
 end
 function self:render()render()end
 function ctx.commit(command,choice,describe,token)
  eq(command,'chooseEvent');local accepted,why=H.choose(r,choice,token);if accepted then describe()end;render();return accepted,why
 end
 render()
 return ctx,function(path)local box=root;for name in path:gmatch('[^/]+')do box=assert(box:GetChild(name),path)end;return box end
end
test('all twelve actual native card faces stay concealed until core reveal and use original card copy',function()
 local r=H.play(H.fixture());local ctx,get=setup(r);local before=H.C.copy(r)
 for i=1,12 do
  local path='pickerView/forgeGrid/card'..i
  assert(get(path..'/matchBack').visible)
  local gridSpec;for _,spec in ipairs(Layout.children)do if spec.name=='forgeGrid'then gridSpec=spec end end
  for _,spec in ipairs(gridSpec.children[i].children)do
   if spec.name~='hit'and spec.name~='matchBack'then eq(get(path..'/'..spec.name).visible,false)end
  end
  eq(get(path..'/name').visible,false);eq(get(path..'/name').text,'');eq(get(path..'/description').visible,false)
  for _,name in ipairs({'plate','glyph','label'})do eq(get(path..'/matchBack/'..name).raycastTarget,false)end
 end
 same(r,before);assert(ctx.self.actions['pickerView/forgeGrid/card1'].handler())
 local slot=H.view(r).match.slots[1];assert(get('pickerView/forgeGrid/card1/name').visible);assert(not get('pickerView/forgeGrid/card1/matchBack').visible)
 assert(get('pickerView/forgeGrid/card1/name').text:find(ctx.cardName(slot.cardId,false),1,true))
 assert(get('pickerView/label').text:find('5',1,true));eq(ctx.self.actions['pickerView/forgeGrid/card1'].enabled,false)
end)
test('Match and real normal forge reuse the same faces with restored backs, selection and stale ownership',function()
 local r=H.play(H.fixture());local before=H.C.copy(r.deck)
 local ctx,get=setup(r,function(c)
  local box=c.child('pickerView'):GetChild('forgeGrid'):GetChild('card1')
  c.fillCard(box,r.deck[1].cardId,false,{instance=r.deck[1]})
 end)
 local old=ctx.self.actions['pickerView/forgeGrid/card1'].handler;ctx.resetMatch()
 eq(old(),false);same(r.deck,before)
 local render=ctx.self.render;ctx.self.mode,ctx.self.picker,ctx.self.selected='picker','upgrade',nil
 ctx.self.upgradeRows=H.C.copy(r.deck);ctx.self.view={node={type='camp'}}
 local camp=require('abyss_node_ui_camp').new(ctx.self,ctx);local node={type='camp',upgradeCards=H.C.copy(r.deck)}
 ctx.self.render=function()camp:render(node)end;camp:render(node)
 for i=1,12 do eq(get('pickerView/forgeGrid/card'..i..'/matchBack').visible,false)end
 eq(get('pickerView/forgeGrid/card1/name').visible,true)
 assert(get('pickerView/forgeGrid/card1/name').text:find(ctx.cardName(r.deck[1].cardId,false),1,true))
 local forge=ctx.self.actions['pickerView/forgeGrid/card1'].handler;assert(forge());eq(ctx.self.selected,r.deck[1].uid)
 ctx.self.render=render;ctx.self.picker,ctx.self.selected='match',nil;ctx.self:render()
 eq(forge(),false);eq(old(),false);same(r.deck,before)
 assert(get('pickerView/forgeGrid/card1/matchBack').visible);eq(get('pickerView/forgeGrid/card1/name').text,'')
end)
test('old callbacks cannot double flip, target a new run/map, or operate hidden/reparented controls',function()
 local r=H.play(H.fixture());local ctx,get=setup(r);local old=ctx.self.actions['pickerView/forgeGrid/card1'].handler
 assert(old());local before=H.C.copy(r);eq(old(),false);same(r,before)
 for _,kind in ipairs({'hidden','map','run','detached'})do
  ctx.self:render();local action=ctx.self.actions['pickerView/forgeGrid/card2'].handler;local map=ctx.self.map
  if kind=='hidden'then ctx.self.visible=false elseif kind=='map'then ctx.self.map={}
  elseif kind=='run'then ctx.self.run=H.fixture()else get('pickerView/forgeGrid/card2').parent=nil end
  eq(action(),false);same(r,before);ctx.self.visible=true;ctx.self.map=map;ctx.self.run=r
  if kind=='detached'then get('pickerView/forgeGrid/card2').parent=get('pickerView/forgeGrid')end
  eq(action(),false);same(r,before)
 end
end)
test('source reveal delays resolve only once, pause hidden, and cleanup waits before Leave',function()
 local r=H.play(H.fixture());local ctx=setup(r);local p=H.pairs(r)[1]
 assert(ctx.self.actions['pickerView/forgeGrid/card'..p[1]].handler());assert(ctx.self.actions['pickerView/forgeGrid/card'..p[2]].handler())
 local count=#r.deck;ctx.updateMatch(.9);eq(#r.deck,count);ctx.self.visible=false;ctx.updateMatch(100);eq(#r.deck,count)
 ctx.self.visible=true;ctx.self:render();ctx.updateMatch(.9);eq(#r.deck,count);ctx.updateMatch(.1);eq(#r.deck,count+1)
 ctx.updateMatch(100);eq(#r.deck,count+1)
 for n=2,5 do local pair=H.pairs(r)[n];assert(H.flip(r,pair[1]));assert(H.flip(r,pair[2]));assert(H.resolve(r))end
 eq(r.nodeFlow.event.stage,'cleanup');ctx.self:render();ctx.updateMatch(.9);eq(r.nodeFlow.event.stage,'cleanup')
 ctx.updateMatch(.1);eq(r.nodeFlow.event.stage,'result')
end)
test('late resolve error rolls back and exposes a user retry without an automatic retry loop',function()
 local r=H.play(H.fixture());local ctx,get=setup(r);local p=H.pairs(r)[1]
 assert(H.flip(r,p[1]));assert(H.flip(r,p[2]));ctx.self:render();local before=H.C.copy(r)
 local original=H.Hooks.onObtainCard;H.Hooks.onObtainCard=function()return false,'match_late_refusal'end
 ctx.updateMatch(2);same(r,before);assert(get('pickerView/matchRetry').visible)
 ctx.updateMatch(100);same(r,before);H.Hooks.onObtainCard=original
 assert(ctx.self.actions['pickerView/matchRetry'].handler());eq(r.nodeFlow.event.attemptsLeft,4);assert(not get('pickerView/matchRetry').visible)
end)
print('MATCH_EVENT_UI_PASS '..H.count)
