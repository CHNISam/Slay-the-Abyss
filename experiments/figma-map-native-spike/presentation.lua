local M={MAX_SHAPES=1536,MAX_GLOWS=256,ANIMATED_WRITES=256}
function M.contract(owner)return {choose=function(_,id)return owner:choose(id)end}end
function M.state(node,current,available)
 return node.id==current and 'current' or node.visited and 'visited' or available[node.id]and'available'or'future'
end
-- decorate an existing MapUI instance, not a second map owner or input system.
function M.attach(ui,root,options)
 local Curve=require('curve');local Map=require('abyss_map');local Layout=require('abyss_map_layout');local Theme=require('abyss_theme')
 assert(not ui.figmaSpikeAttached,'experimental presentation already attached');ui.figmaSpikeAttached=true
 options=options or {};local colour=options.color or Color
 local cache={};local function index(parent)
 for _,child in ipairs(parent:GetChildren())do if child.name then cache[child.name]=child end;index(child)end
 end
 index(root)
 for _,group in ipairs(ui.panel:GetChildren())do
  for _,prefix in ipairs({'p','g'})do local limit=prefix=='p'and M.MAX_SHAPES or M.MAX_GLOWS;for i=1,limit do if not cache[prefix..i]then local c=group:GetChild(prefix..i);if c then cache[prefix..i]=c end end end end
 end
 local function find(parent,name)
  local c=parent:GetChild(name);if c then return c end
  -- Native GetChildren is available in the source API; no child-path guessing.
  for _,child in ipairs(parent:GetChildren())do local got=find(child,name);if got then return got end end
 end
 local function at(name)if not cache[name]then cache[name]=assert(find(root,name),'missing experimental control '..name)end;return cache[name]end
 local function tint(c,r,g,b,a)c.imageColor=colour(r,g,b,a or 255)end
 local originalRender,originalUpdate=ui.render,ui.update
 local elapsed,filter=0,nil;local tokenFrom,tokenTo,tokenStarted,lastCurrent,tokenOwner;local painted=false;local anim={};local generation
 local types={'combat','elite','event','shop','camp','treasure','boss'}
 local inks={combat={228,105,90},elite={183,155,234},event={140,196,226},shop={127,209,185},camp={255,169,92},treasure={246,223,164},boss={255,90,74}}
 local function position(n)return{x=(n.lane-4)*Theme.layout.map.columnGap,y=Layout.firstY+(n.floor-(ui.map.firstFloor or 1))*Theme.layout.map.floorGap-ui.scroll}end
 local function paintToken(x,y,exists)
  for _,name in ipairs({'tokenHalo','tokenOuter','tokenInner','tokenStar'})do
   local radius=name=='tokenHalo'and 85 or 36;local c=at(name)
   c:SetVisible(exists and y-radius>=Layout.viewport.bottom and y+radius<=Layout.viewport.top)
   if exists then c:SetAnchoredPosition(x,y)end
  end
 end
 local function updateToken()
  if tokenTo then
   local t=math.min(1,(elapsed-tokenStarted)/.75);if ui.reducedMotion then t=1 end
   local eased=t*t*(3-2*t);local hop=ui.reducedMotion and 0 or math.sin(t*math.pi)*22
   local x=tokenFrom.x+(tokenTo.x-tokenFrom.x)*eased;local y=tokenFrom.y+(tokenTo.y-tokenFrom.y)*eased+hop
   if t==1 and not ui.reducedMotion then y=y+math.sin(elapsed*2*math.pi/3)*2 end
   paintToken(x,y,true)
  end
 end
 local used,glows=0,0
 local function shape(p,solid,ink,width)
  used=used+1;assert(used<=M.MAX_SHAPES,'visible curve pool exceeded; experiment blocked')
  local c=at('p'..used);c:SetImage(options.imageSource or Enum.ImageSource.StaticReference,solid and 100001 or 100002);c:SetVisible(true);c:SetAnchoredPosition(p.x,p.y);c:SetSizeDelta(solid and p.length+.5 or width,width);c.localRotationZ=solid and p.angle or 0;tint(c,ink[1],ink[2],ink[3],ink[4])
  return c
 end
 local function draw()
  if not ui.map or not ui.visible then return end
  if tokenOwner~=ui.map then tokenOwner=ui.map;lastCurrent=nil;tokenFrom=nil;tokenTo=nil;filter=nil end
  assert((ui.map.act or 1)==1,'figma map spike supports first act only; production theme stays unchanged')
  local view=Map.view(ui.map);local avail={};for _,n in ipairs((options.available or Map.available)(ui.map))do avail[n.id]=true end
  local nodes={};for _,n in ipairs(view.nodes)do nodes[n.id]=n end
  local taken={};for i=2,#view.path do taken[view.path[i-1]..'>'..view.path[i]]=true end
  local previousUsed,previousGlows=used,glows
  used,glows=0,0;anim={}
  local viewport={bottom=Layout.viewport.bottom+4,top=Layout.viewport.top-4}
  for _,n in ipairs(view.nodes)do for _,id in ipairs(n.nextIds)do local target=nodes[id];local a,b=position(n),position(target)
   if b.y>=viewport.bottom and a.y<=viewport.top then
    local walked=taken[n.id..'>'..id];local nextEdge=n.id==view.currentNodeId and avail[id]
    if walked then
     for _,p in ipairs(Curve.segments(a,b,viewport,16,25,target.type=='boss'and 42 or 25))do
      shape(p,true,{240,207,134},3.2);glows=glows+1;assert(glows<=M.MAX_GLOWS,'walked glow pool exceeded')
      local g=at('g'..glows);g:SetVisible(true);g:SetAnchoredPosition(p.x,p.y);g:SetImage(options.imageSource or Enum.ImageSource.StaticReference,100001);tint(g,233,199,123,38);g:SetSizeDelta(p.length+.5,9);g.localRotationZ=p.angle
     end
    else
     local dots=Curve.dots(a,b,viewport,nextEdge and 14 or 8,0,25,target.type=='boss'and 42 or 25,128)
     for _,p in ipairs(dots)do shape(p,false,nextEdge and{246,223,164}or{168,143,104,150},nextEdge and 3.2 or 2.5)end
     if nextEdge then anim[#anim+1]={first=used-#dots+1,count=#dots,a=a,b=b,trim=target.type=='boss'and 42 or 25}end
    end
   end
  end end
  for i=used+1,previousUsed do at('p'..i):SetVisible(false)end
  for i=glows+1,previousGlows do at('g'..i):SetVisible(false)end
  for i=1,Layout.maxEdges do at('edge'..i):SetVisible(false)end
  for i,n in ipairs(view.nodes)do local box=at('node'..i);local state=M.state(n,view.currentNodeId,avail);local icon=box:GetChild('icon')
   box:GetChild('ring'):SetVisible(false);box:GetChild('positionToken'):SetVisible(false)
   local ink=state=='available'and inks[n.type]or state=='visited'and{138,115,82}or{189,183,170}
   local alpha=state=='current'and 0 or filter and filter~=n.type and 56 or state=='visited'and 158 or state=='future'and 178 or 255
   tint(icon,ink[1],ink[2],ink[3],alpha)
   if ui.roomFx[n.id]then ui.roomFx[n.id].ink={r=ink[1],g=ink[2],b=ink[3],a=alpha}end
  end
  local current=nodes[view.currentNodeId]
  if current and lastCurrent~=view.currentNodeId then
   tokenTo=position(current);tokenFrom=lastCurrent and nodes[lastCurrent]and position(nodes[lastCurrent])or tokenTo;tokenStarted=elapsed;lastCurrent=view.currentNodeId
  elseif current then local nextPos=position(current);if tokenTo then local dx,dy=nextPos.x-tokenTo.x,nextPos.y-tokenTo.y;tokenFrom.x,tokenFrom.y=tokenFrom.x+dx,tokenFrom.y+dy end;tokenTo=nextPos
  else lastCurrent=nil;tokenFrom=nil;tokenTo=nil end
  if current then updateToken()else paintToken(0,0,false)end
  at('figmaTitle').text=view.floor<1 and '选择起点' or '第 '..view.floor..' 层 / 17'
  at('actTitle').text=(view.act or 1)==1 and '第 一 幕' or '第 二 幕'
  at('notice'):SetAnchoredPosition(0,-250)
  if options.run then local run=options.run();if run then at('figmaHP').text=string.format('%.0f/%.0f',run.hp,run.maxHp);at('figmaGold').text=string.format('%.0f',run.gold or 0);at('figmaDeck').text=tostring(#run.deck);local hpRatio=math.max(0,math.min(1,run.hp/run.maxHp));at('hpAmount'):SetSizeDelta(36*hpRatio,4);at('hpAmount'):SetAnchoredPosition(-506+18*hpRatio,324);for i=1,3 do local potion=run.potions and run.potions[i];local icon=at('potion'..i);icon:SetVisible(potion~=nil);if potion then local id=type(potion)=='table'and potion.id or potion;local asset=Theme.icon.potion[id];if type(asset)=='table'then asset=asset.id end;if asset then icon:SetImage(options.imageSource or Enum.ImageSource.StaticReference,asset)end end end
  end end
  local counts={};for _,n in ipairs(view.nodes)do counts[n.type]=(counts[n.type]or 0)+1 end;for i,t in ipairs(types)do at('legendCount'..(i-1)).text=tostring(counts[t]or 0)end
  for f=1,17 do at('floorLabel'..f):SetVisible(f==1 or f==17 or f%5==0 or f==view.floor);at('floorLabel'..f).fontColor=colour(f==view.floor and 246 or 125,f==view.floor and 223 or 108,f==view.floor and 164 or 85,255);tint(at('progress'..f),f<=view.floor and 246 or 74,f<=view.floor and 223 or 59,f<=view.floor and 164 or 44);tint(at('floorMark'..f),f==view.floor and 246 or 110,f==view.floor and 223 or 90,f==view.floor and 164 or 66)end
  for _,name in ipairs({'mapField','mapLight','headerShade','headerDivider','titleLineLeft','titleLineRight','title','typeLegend'})do local c=find(root,name);if c then c:SetVisible(false)end end
  for i=1,#Theme.layout.map.presentation.fog do local c=find(root,'fog'..i);if c then c:SetVisible(false)end end
  ui.spikeStats={shapes=used,glows=glows,animatedEdges=#anim}
  generation=tostring(ui.map)..':'..tostring(view.currentNodeId)..':'..tostring(ui.scroll);painted=true
 end
 function ui:render()originalRender(self);draw()end
 function ui:update(dt)
  originalUpdate(self,dt)
  if not self.visible or not self.map then return end
  local key=tostring(self.map)..':'..tostring(self.map.currentNodeId)..':'..tostring(self.scroll)
  if not painted or generation~=key then draw()end
  elapsed=elapsed+math.max(0,math.min(dt or 0,.1))
  updateToken()
  local writes=tokenTo and 8 or 0
  if not self.reducedMotion then for _,edge in ipairs(anim)do
   local points=Curve.dots(edge.a,edge.b,{bottom=Layout.viewport.bottom+4,top=Layout.viewport.top-4},14,elapsed*14/1.1,25,edge.trim,128)
   for j=1,edge.count do local p=points[j];writes=writes+(p and 2 or 1);assert(writes<=M.ANIMATED_WRITES,'animated curve budget exceeded')
    local c=at('p'..(edge.first+j-1));c:SetVisible(p~=nil);if p then c:SetAnchoredPosition(p.x,p.y)end
   end
  end end
 end
 for i,t in ipairs(types)do at('legendHit'..(i-1)):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()if not ui.visible then return false,'map_hidden'end;filter=filter==t and nil or t;draw()end)end
 for f=1,17 do local floor=f;at('floorHit'..f):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()if not ui.visible then return false,'map_hidden'end;ui:setScroll(Layout.firstY+(floor-1)*Theme.layout.map.floorGap-Layout.focusY)end)end
 draw();return ui
end
return M
