-- Real generated tree and public Nodes/Run; native methods alone are mocks.
-- Navigation, source queue/boolean and history eligibility below are staged input,
-- never naturally earned event probability, PC RNG, or native-client evidence.
local H={}
H.UI,H.Nodes,H.Run,H.Map=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map')
H.Copy,H.Data=require('abyss_combat').copy,require('abyss_data')
H.Pool,H.Random,H.Relics=require('abyss_event_pool'),require('abyss_sts_random'),require('abyss_relic_pool')
H.Hooks,H.Curses=require('abyss_relic_hooks'),require('abyss_curses')
local Layout,Presentation=require('abyss_ui_layout'),require('abyss_presentation')
local events={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
function H.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function H.same(a,b,path)
 if a==b then return end;path=path or 'state';H.eq(type(a),type(b))
 if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do H.same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
function H.snapshot(r)return H.Copy(r,{[r.data]=r.data})end
local function find(list,name)
 for _,spec in ipairs(list)do
  if spec.name==name then return spec end
  local found=spec.children and find(spec.children,name);if found then return found end
 end
end
function H.control(spec,parent)
 local c={name=spec.name,parent=parent,children={},listeners={},visible=spec.visible~=false,
  text=spec.text and spec.text.content or '',scale={1,1,1}}
 function c:GetChild(name)return self.children[name]end
 function c:SetVisible(value)assert(type(value)=='boolean');self.visible=value end
 function c:SetImage(source,id)assert(source=='static' and type(id)=='number');self.imageId=id end
 function c:SetSizeDelta(width,height)
     assert(type(width)=='number' and type(height)=='number' and width>=0 and height>=0 and width<math.huge and height<math.huge)
     self.size={width,height};self.sizeDeltaX,self.sizeDeltaY=width,height
 end
 function c:SetLocalScale(x,y,z)self.scale={x,y,z}end
 function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
 function c:AddCursorEventListener(event,fn)assert(not self.listeners[event]);self.listeners[event]=fn end
 function c:emit(event,id)return assert(self.listeners[event],event)({touchId=id})end
 for _,child in ipairs(spec.children or {})do c.children[child.name]=H.control(child,c)end
 return c
end
local base=H.Run.new(H.Data,'42',{experimental=true,campaign=true})
base.act,base.floor=2,17;base.unknown.pools=H.Pool.new('full',false,2)
local baseMap=H.Map.generate(base.data,'42',2)
function H.fixture(id,deck,gold)
 local r,m=H.snapshot(base),H.Copy(baseMap);local n=H.Map.available(m)[1]
 if deck then r.deck=H.Copy(deck);r.nextDeckUid=100 end;r.gold=gold or 100
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId=id end end
 assert(H.Nodes.enter(r,m,n.id));return r,m
end
function H.front(r,id,tier)
 tier=tier or 'common';local foundTier=false
 for n=0,31 do
  local state=H.Random.atCounter(r.eventSeed,n);local nextState=H.Random.cloneState(state)
  if H.Relics.rarity('event',H.Random.randomInt(nextState,99))==tier then r.relicPool.rng=state;foundTier=true;break end
 end
 assert(foundTier);local q=r.relicPool.queues[tier]
 for i,v in ipairs(q)do if v==id then table.remove(q,i);table.insert(q,1,id);return end end
 error('missing staged source ID '..id)
end
function H.boolean(r,wanted)
 for n=0,31 do
  local state=H.Random.atCounter(r.eventSeed,n);local nextState=H.Random.cloneState(state)
  if H.Random.randomBoolean(nextState)==wanted then r.miscRng=state;return end
 end
 error('bounded seeded boolean input missing')
end
function H.setup(run,map)
 local host=H.control({name='host',children={assert(find(Layout,'nodePanel'))}})
 local root=host:GetChild('nodePanel');local changes={}
 local ui=H.UI.new(root,run,map,Presentation,'click',function(ok,why)changes[#changes+1]={ok,why}end,
  {cursorEvents=events,imageSource='static'})
 ui:setVisible(true)
 local function get(path)
  local node=root;for part in path:gmatch('[^/]+')do node=assert(node:GetChild(part),path)end;return node
 end
 local function shown(path)
  local node=get(path);while node do if not node.visible then return false end;node=node.parent end;return true
 end
 local function click(path,id)
  assert(shown(path),'hidden '..path);local hit=get(path):GetChild('hit');id=id or 1
  if hit.listeners.down then hit:emit('down',id);hit:emit('up',id)end
  return hit:emit('click',id)
 end
 return ui,get,shown,click,changes,root,host
end
function H.parity(r,m,choice,uid,click)
 local expected,expectedMap=H.snapshot(r),H.Copy(m)
 local ok,why=H.Nodes.chooseEvent(expected,choice,uid)
 local actual,reason=click();H.eq(actual,ok);H.eq(reason,why);H.same(r,expected);H.same(m,expectedMap)
 return actual,reason
end
function H.unchanged(r,m,fn)
 local before,mapBefore=H.snapshot(r),H.Copy(m);local ok,why=fn();H.eq(ok,false)
 assert(type(why)=='string');H.same(r,before);H.same(m,mapBefore);return why
end
function H.selecting(deck)
 local r,m=H.fixture('beggar',deck)
 assert(H.Nodes.chooseEvent(r,'donate'));assert(H.Nodes.chooseEvent(r,'confirm'));return r,m
end
H.count=0
function H.test(name,fn)fn();H.count=H.count+1;print('ok Act2 event UI '..H.count..' - '..name)end
function H.finish()print('ACT2_EVENT_UI_PASS '..H.count)end
return H
