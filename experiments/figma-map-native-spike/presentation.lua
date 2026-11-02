local M={MAX_SHAPES=1536,MAX_GLOWS=256,ANIMATED_WRITES=256}
function M.contract(owner)return {choose=function(_,id)return owner:choose(id)end}end
function M.state(node,current,available,reach)
 return node.id==current and 'current' or node.visited and 'visited' or available[node.id]and'available'or reach and not reach[node.id]and'sealed'or'future'
end
function M.reachable(nodes,current,available)
 local byId,seen={},{};for _,n in ipairs(nodes)do byId[n.id]=n end
 local todo={current};for id in pairs(available or{})do todo[#todo+1]=id end;while #todo>0 do local id=table.remove(todo);if id and not seen[id]then seen[id]=true;for _,nextId in ipairs(byId[id]and byId[id].nextIds or{})do todo[#todo+1]=nextId end end end
 return seen
end
function M.fade(y,bottom,top)return math.max(0,math.min(1,(top-y)/120,(y-bottom)/70))end
function M.ease(t,x1,y1,x2,y2)
 if t<=0 then return 0 elseif t>=1 then return 1 end
 local function cubic(v,a,b)local u=1-v;return 3*u*u*v*a+3*u*v*v*b+v*v*v end
 local lo,hi=0,1;for _=1,14 do local v=(lo+hi)/2;if cubic(v,x1,x2)<t then lo=v else hi=v end end
 return cubic((lo+hi)/2,y1,y2)
end
function M.sparkBudget(remaining)
 if remaining<16 then return 0,remaining>0 and 1 or 0 end
 local count=math.min(10,math.floor((remaining-16)/4));return count,16+4*count
end
function M.viewport(width,height)
 assert(type(width)=='number'and type(height)=='number'and width>0 and height>0,'valid canvas required')
 local phone,compact=width<640,width<900;local header=phone and 96 or 76;local side=compact and 60 or 230;local mapWidth=math.max(250,math.min(760,width-2*side))
 return{width=width,height=height,scale=1,phone=phone,compact=compact,header=header,legendWidth=compact and 46 or 178,top=height/2-header,bottom=-height/2,gap=phone and 84 or 100,columnGap=math.max(44,100*math.min(1,(mapWidth-68)/692)),focus=-height*.1}
end
-- Pure presentation sampling: fixed independent seeds, never Run RNG.
local function visualUnit(i,salt)local n=math.sin((i+1)*127.1+salt*311.7)*43758.5453;return n-math.floor(n)end
function M.emberSample(i,seconds,width,height)
 local duration=9+14*visualUnit(i,1);local phase=((seconds+20*visualUnit(i,2))/duration)%1
 return{duration=duration,phase=phase,x=-width/2+width*visualUnit(i,3)+(visualUnit(i,4)-.5)*120*phase,
  y=-height/2-10+height*1.05*phase,alpha=phase<.1 and phase*9 or 1-phase}
end
function M.hudMetrics(hp,maxHp,gold,width,height)
 -- Native fallback digit advance at 14px; retain reference 6px icon gap and 8px group gap.
 local cur=string.format('%.0f',hp);local max='/'..string.format('%.0f',maxHp);local money=string.format('%.0f',gold)
 local curW=#cur*9;local maxW=(#max-1)*9+5;local left=-width/2+20;local hpW=8+17+6+curW+maxW+8+36+12+2
 local goldLeft=left+hpW+8;local goldW=8+17+6+#money*9+12+2
 return{hpLeft=left,hpRight=left+hpW,hpWidth=hpW,hpTextLeft=left+8+17+6,current=cur,maximum=max,currentW=curW,maxW=maxW,
  barLeft=left+8+17+6+curW+maxW+8,goldLeft=goldLeft,goldWidth=goldW,coinRight=goldLeft+8+17,coinTextLeft=goldLeft+8+17+6,
  money=money,moneyW=#money*9,potionLeft=goldLeft+goldW+8,y=height/2-31}
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
 local function find(parent,name)
  local c=parent:GetChild(name);if c then return c end
  -- Native GetChildren is available in the source API; no child-path guessing.
  for _,child in ipairs(parent:GetChildren())do local got=find(child,name);if got then return got end end
 end
 -- Legacy header and legend both contain a 'title'; preserve scoped lookup once.
 cache.title=find(root,'title')
 local function at(name)if not cache[name]then cache[name]=assert(find(root,name),'missing experimental control '..name)end;return cache[name]end
 local function tint(c,r,g,b,a)c.imageColor=colour(r,g,b,a or 255)end
 local originalRender,originalUpdate=ui.render,ui.update
 local elapsed,filter=0,nil;local visibleIcons={};local movingSegments={};local moveFromId,moveToId;local emberAlpha={};local ambientShown=false;local hovered,hoverSince=nil,0;local nodeMeta={};local legendOpen=true;local menuOpen=false;local canvas;local cameraAt;local shakeId,shakeAt;local pickedId,pickedAt;local tokenFrom,tokenTo,tokenStarted,lastCurrent,tokenOwner;local painted=false;local anim={};local generation
 local types={'combat','elite','event','shop','camp','treasure','boss'}
 local inks={combat={228,105,90},elite={183,155,234},event={140,196,226},shop={127,209,185},camp={255,169,92},treasure={246,223,164},boss={255,90,74}}
 local function position(n)return{x=(n.lane-4)*Theme.layout.map.columnGap,y=Layout.firstY+(n.floor-(ui.map.firstFloor or 1))*Theme.layout.map.floorGap-ui.scroll}end
 local function paintToken(x,y,exists)
  for _,name in ipairs({'tokenHalo','tokenOuter','tokenInner','tokenStar'})do
   local radius=name=='tokenHalo'and 107 or 36;local c=at(name)
   c:SetVisible(exists and y-radius>=Layout.viewport.bottom and y+radius<=Layout.viewport.top)
   if exists then c:SetAnchoredPosition(x,y)end
  end
 end
 local function updateToken()
  if tokenTo then
   local t=math.min(1,(elapsed-tokenStarted)/.75);if ui.reducedMotion then t=1 end
   local eased=M.ease(t,.45,.05,.25,1);local hop=ui.reducedMotion and 0 or math.sin(t*math.pi)*22
   local x=tokenFrom.x+(tokenTo.x-tokenFrom.x)*eased;local y=tokenFrom.y+(tokenTo.y-tokenFrom.y)*eased+hop
   if t==1 and not ui.reducedMotion then y=y+(1-math.cos(elapsed*2*math.pi/3))*2 end
   paintToken(x,y,true)
  end
 end
 local function paintTransition()local writes=0;if #movingSegments>0 then local progress=ui.reducedMotion and 1 or M.ease(math.min(1,(elapsed-tokenStarted)/.75),.4,0,.2,1);for i,v in ipairs(movingSegments)do local part=math.max(0,math.min(1,progress*#movingSegments-(i-1)));local p=v.p;for _,c in ipairs({v.core,v.glow})do c:SetVisible(part>0);c:SetAnchoredPosition(p.x1+(p.x2-p.x1)*part/2,p.y1+(p.y2-p.y1)*part/2);c:SetSizeDelta(p.length*part+.5,c==v.core and 3.2 or 9)end;writes=writes+6 end;if progress==1 then movingSegments={};moveFromId=nil;moveToId=nil end end;ui.spikeTransition={segments=#movingSegments,progress=tokenStarted and M.ease(math.min(1,(elapsed-tokenStarted)/.75),.4,0,.2,1)or 1};return writes end
 local names={combat='普通战斗',elite='精英',event='未知事件',shop='商店',camp='营地',treasure='宝箱',boss='首领'}
 local descriptions={combat='战胜敌人，获得金币与卡牌奖励。',elite='强大的敌人，战胜后可获得遗物。',event='探索未知事件，作出你的选择。',shop='查看商品详情，再确认购买。',camp='恢复生命，或升级一张卡牌。',treasure='打开宝箱，获得遗物。',boss='击败首领，继续你的冒险。'}
 local labels={current='当前位置',visited='已走过',available='可前往 · 点击选择',future='尚未抵达',sealed='此路已断绝'}
 local function tooltip()
  local meta=hovered and nodeMeta[hovered];local visible=meta and ui.visible and not menuOpen and not ui.choosing
  at('mapTooltip'):SetVisible(visible and true or false);if not visible then return 1 end
  local p=position(meta.node);local y=p.y+95;if y+60>Layout.viewport.top then y=p.y-95 end
  at('mapTooltip'):SetAnchoredPosition(math.max(-(ui.canvasWidth or 1600)/2+120,math.min((ui.canvasWidth or 1600)/2-120,p.x)),y-4*(1-math.min(1,(elapsed-hoverSince)/.16)))
  at('tipName').text=names[meta.node.type];at('tipFloor').text='F'..meta.node.floor;at('tipDescription').text=descriptions[meta.node.type];at('tipState').text=labels[meta.state]
  local ink=inks[meta.node.type];at('tipName').fontColor=colour(ink[1],ink[2],ink[3],255);return 7
 end
 local function paintPick(budget)
  if not pickedId then return 0 end;budget=budget or M.ANIMATED_WRITES;if budget<16 then at('pickEffects'):SetVisible(false);return budget>0 and 1 or 0 end;at('pickEffects'):SetVisible(true);local maxSparks,pickWrites=M.sparkBudget(budget);local meta=nodeMeta[pickedId];if not meta then pickedId=nil;return 0 end
  local p=position(meta.node);local seconds=elapsed-pickedAt;local t=math.min(1,seconds/.6);local scale=t<.6 and(1.3+.4*t/.6)or(1.7-.6*(t-.6)/.4);local icon=at('pickedIcon');local ink=inks[meta.node.type]
  icon:SetVisible(t<1);icon:SetImage(options.imageSource or Enum.ImageSource.StaticReference,Theme.icon.node[meta.node.type]);icon:SetAnchoredPosition(p.x,p.y);icon:SetSizeDelta(32*scale,32*scale);tint(icon,ink[1],ink[2],ink[3],math.floor(255*(t<.6 and 1 or(1-t)/.4)))
  local life=math.min(1,seconds/.8);local eased=1-(1-life)^3
  for i=0,9 do local spark=at('pickSpark'..i);local angle=i*math.pi*2/10;local radius=22+(i*17%29);spark:SetVisible(life<1 and i<maxSparks);if i<maxSparks then spark:SetAnchoredPosition(p.x+math.cos(angle)*radius*eased,p.y+(math.sin(angle)*radius+12)*eased);spark:SetLocalScale(1-.8*life,1-.8*life,1);tint(at('pickSparkCore'..i),246,223,164,math.floor(255*(1-life)));tint(at('pickSparkGlow'..i),233,199,123,math.floor(30*(1-life)))end end
  if life==1 then pickedId=nil end;return pickWrites
 end
 local used,glows=0,0
 local function shape(p,solid,ink,width)
  used=used+1;assert(used<=M.MAX_SHAPES,'visible curve pool exceeded; experiment blocked')
  local c=at('p'..used);c:SetImage(options.imageSource or Enum.ImageSource.StaticReference,solid==true and 100001 or 100002);c:SetVisible(true);c:SetAnchoredPosition(p.x,p.y);c:SetSizeDelta(solid and p.length+(solid==true and .5 or 0)or width,width);c.localRotationZ=solid and p.angle or 0;tint(c,ink[1],ink[2],ink[3],math.floor((ink[4]or 255)*M.fade(p.y,Layout.viewport.bottom,Layout.viewport.top)))
  return c
 end
 local function draw()
  if not ui.map or not ui.visible then return end
  if tokenOwner~=ui.map then tokenOwner=ui.map;lastCurrent=nil;tokenFrom=nil;tokenTo=nil;filter=nil;cameraAt=nil;pickedId=nil;moveFromId=nil;moveToId=nil;hovered=nil end
  assert((ui.map.act or 1)==1,'figma map spike supports first act only; production theme stays unchanged')
  local view=Map.view(ui.map);local avail={};for _,n in ipairs((options.available or Map.available)(ui.map))do avail[n.id]=true end
  local nodes={};for _,n in ipairs(view.nodes)do nodes[n.id]=n end;local reach=M.reachable(view.nodes,view.currentNodeId,avail);if not view.currentNodeId then for _,n in ipairs(view.nodes)do reach[n.id]=true end end
  local preview={};if hovered and reach[hovered]then local seen={};local function route(id)if id==hovered then return true end;if seen[id]then return false end;seen[id]=true;for _,nextId in ipairs(nodes[id]and nodes[id].nextIds or{})do if route(nextId)then preview[id..'>'..nextId]=true;return true end end;return false end;if view.currentNodeId then route(view.currentNodeId)end end
  local taken={};for i=2,#view.path do taken[view.path[i-1]..'>'..view.path[i]]=true end
  if view.currentNodeId~=lastCurrent and lastCurrent then moveFromId,moveToId=lastCurrent,view.currentNodeId end
  local previousUsed,previousGlows=used,glows
  used,glows=0,0;anim={};movingSegments={}
  local viewport={bottom=Layout.viewport.bottom+4,top=Layout.viewport.top-4}
  for _,n in ipairs(view.nodes)do for _,id in ipairs(n.nextIds)do local target=nodes[id];local a,b=position(n),position(target)
   if b.y>=viewport.bottom and a.y<=viewport.top then
    local walked=taken[n.id..'>'..id];local nextEdge=n.id==view.currentNodeId and avail[id]or preview[n.id..'>'..id]
    if walked then
     for _,p in ipairs(Curve.segments(a,b,viewport,16,25,target.type=='boss'and 42 or 25))do
      local core=shape(p,true,{240,207,134},3.2);glows=glows+1;assert(glows<=M.MAX_GLOWS,'walked glow pool exceeded')
      local g=at('g'..glows);g:SetVisible(true);g:SetAnchoredPosition(p.x,p.y);g:SetImage(options.imageSource or Enum.ImageSource.StaticReference,100001);tint(g,233,199,123,38);g:SetSizeDelta(p.length+.5,9);g.localRotationZ=p.angle
      if id==moveToId and n.id==moveFromId and (view.currentNodeId~=lastCurrent or not tokenStarted or elapsed-tokenStarted<.75)then movingSegments[#movingSegments+1]={core=core,glow=g,p=p}end
     end
    else
     local sealed=not reach[n.id]or not reach[id];local dots=Curve.dots(a,b,viewport,nextEdge and 14 or sealed and 9 or 8,0,25,target.type=='boss'and 42 or 25,128)
     for _,p in ipairs(dots)do shape(p,nextEdge and 'dash' or false,nextEdge and{246,223,164}or sealed and{74,59,44,128}or{168,143,104,191},nextEdge and 3.2 or sealed and 2.2 or 2.8)end
     if nextEdge and not preview[n.id..'>'..id]then anim[#anim+1]={first=used-#dots+1,count=#dots,a=a,b=b,trim=target.type=='boss'and 42 or 25}end
    end
   end
  end end
  for i=used+1,previousUsed do at('p'..i):SetVisible(false)end
  for i=glows+1,previousGlows do at('g'..i):SetVisible(false)end
  for i=1,Layout.maxEdges do at('edge'..i):SetVisible(false)end
  visibleIcons={};nodeMeta={};for i,n in ipairs(view.nodes)do local box=at('node'..i);local state=M.state(n,view.currentNodeId,avail,reach);local icon=box:GetChild('icon');nodeMeta[n.id]={node=n,state=state,slot=i};local fx=ui.roomFx[n.id];if fx and fx.visible then box:GetChild('hit'):SetVisible(ui.visible and not ui.choosing)end
   box:GetChild('ring'):SetVisible(false);box:GetChild('positionToken'):SetVisible(false)
   local ink=state=='available'and inks[n.type]or state=='visited'and{138,115,82}or state=='sealed'and{91,76,62}or{189,183,170}
   local alpha=state=='current'and 0 or filter and filter~=n.type and 56 or state=='visited'and 158 or state=='future'and 178 or state=='sealed'and 128 or 255
   alpha=math.floor(alpha*M.fade(position(n).y,Layout.viewport.bottom,Layout.viewport.top));tint(icon,ink[1],ink[2],ink[3],alpha);if box.visible~=false and ui.roomFx[n.id]and ui.roomFx[n.id].visible then visibleIcons[#visibleIcons+1]={id=n.id,baseY=n.hasEmeraldKey and Theme.layout.map.emeraldIconY or 0,icon=icon,state=state,size=n.type=='boss'and 66 or 32,ink=ink,alpha=alpha}end
   if ui.roomFx[n.id]then ui.roomFx[n.id].ink={r=ink[1],g=ink[2],b=ink[3],a=alpha}end
  end
  local current=nodes[view.currentNodeId]
  if current and lastCurrent~=view.currentNodeId then
   tokenTo=position(current);tokenFrom=lastCurrent and nodes[lastCurrent]and position(nodes[lastCurrent])or tokenTo;tokenStarted=elapsed;lastCurrent=view.currentNodeId
  elseif current then local nextPos=position(current);if tokenTo then local dx,dy=nextPos.x-tokenTo.x,nextPos.y-tokenTo.y;tokenFrom.x,tokenFrom.y=tokenFrom.x+dx,tokenFrom.y+dy end;tokenTo=nextPos
  else lastCurrent=nil;tokenFrom=nil;tokenTo=nil end
  if current then updateToken();paintTransition()else paintToken(0,0,false)end
  at('figmaTitle').text=view.floor<1 and '选择起点' or '第 '..view.floor..' 层'
  at('actTitle').text=(view.act or 1)==1 and '第 一 幕' or '第 二 幕'
  at('notice'):SetAnchoredPosition(0,-(ui.canvasHeight or 900)/2+120)
  if options.run then local run=options.run();if run then
   local h=M.hudMetrics(run.hp,run.maxHp,run.gold or 0,ui.canvasWidth or 1600,ui.canvasHeight or 900)
   local function number(name,value,x,w,ink)local c=at(name);c.text='<b>'..value..'</b>';c.fontColor=colour(ink[1],ink[2],ink[3],255);c:SetSizeDelta(w+4,40);c:SetAnchoredPosition(x+w/2,h.y)end
   number('figmaHP',h.current,h.hpTextLeft,h.currentW,{243,236,221});number('figmaHPMax',h.maximum,h.hpTextLeft+h.currentW,h.maxW,{158,140,114})
   number('figmaGold',h.money,h.coinTextLeft,h.moneyW,{246,223,164});at('figmaDeck').text='<b>'..tostring(#run.deck)..'</b>'
   local function pill(key,left,width)
    for _,kind in ipairs({'Border','Fill'})do local height=kind=='Border'and 35 or 33;local w=kind=='Border'and width or width-2;local x=left+width/2
     at('pill'..key..kind):SetSizeDelta(w-height,height);at('pill'..key..kind):SetAnchoredPosition(x,h.y)
     at('pill'..key..kind..'L'):SetAnchoredPosition(x-(w-height)/2,h.y);at('pill'..key..kind..'R'):SetAnchoredPosition(x+(w-height)/2,h.y)
    end
   end
   pill('HP',h.hpLeft,h.hpWidth);pill('Gold',h.goldLeft,h.goldWidth)
   at('hudHeart'):SetAnchoredPosition(h.hpLeft+8+8.5,h.y);at('hudCoin'):SetAnchoredPosition(h.goldLeft+8+8.5,h.y)
   local hpRatio=math.max(0,math.min(1,run.hp/run.maxHp));at('hpTrack'):SetAnchoredPosition(h.barLeft+18,h.y);at('hpAmount'):SetSizeDelta(36*hpRatio,4);at('hpAmount'):SetAnchoredPosition(h.barLeft+18*hpRatio,h.y)
   for i=1,3 do local x=h.potionLeft+17+(i-1)*40;for _,prefix in ipairs({'potionBorder','potionInside','potion'})do at(prefix..i):SetAnchoredPosition(x,h.y)end;local potion=run.potions and run.potions[i];local icon=at('potion'..i);icon:SetVisible(potion~=nil);if potion then local id=type(potion)=='table'and potion.id or potion;local asset=Theme.icon.potion[id];if type(asset)=='table'then asset=asset.id end;if asset then icon:SetImage(options.imageSource or Enum.ImageSource.StaticReference,asset)end end end
  end end
  local counts={};for _,n in ipairs(view.nodes)do counts[n.type]=(counts[n.type]or 0)+1 end;for i,t in ipairs(types)do at('legendCount'..(i-1)).text=tostring(counts[t]or 0)end
  for f=1,17 do local current=f==view.floor;at('floorMark'..f):SetSizeDelta(current and 8 or f%5==0 and 5 or 3.5,current and 8 or f%5==0 and 5 or 3.5);at('floorMarkHole'..f):SetVisible(f>view.floor);at('progressHole'..f):SetVisible(f>view.floor);at('floorCurrentGlow'..f):SetVisible(current);if f==17 then tint(at('progress'..f),255,90,74)end;at('floorLabel'..f):SetVisible(f==1 or f==17 or f%5==0 or f==view.floor);at('floorLabel'..f).fontColor=colour(f==view.floor and 246 or 125,f==view.floor and 223 or 108,f==view.floor and 164 or 85,255);tint(at('progress'..f),f<=view.floor and 246 or 74,f<=view.floor and 223 or 59,f<=view.floor and 164 or 44);tint(at('floorMark'..f),f==view.floor and 246 or 110,f==view.floor and 223 or 90,f==view.floor and 164 or 66)end
  tint(at('progress17'),255,90,74)
  for _,name in ipairs({'mapField','mapLight','headerShade','headerDivider','titleLineLeft','titleLineRight','title','typeLegend'})do local c=cache[name];if c then c:SetVisible(false)end end
  for i=1,#Theme.layout.map.presentation.fog do local c=cache['fog'..i];if c then c:SetVisible(false)end end
  ui.spikeStats={shapes=used,glows=glows,animatedEdges=#anim}
  tooltip();generation=tostring(ui.map)..':'..tostring(view.currentNodeId)..':'..tostring(ui.scroll);painted=true
 end
 local nativeResize=ui.resize
 function ui:resize(width,height)
  local ok,reason=nativeResize(self,width,height);if not ok then return ok,reason end
  canvas=M.viewport(width,height);self.scale=1;at('stage'):SetLocalScale(1,1,1)
  Layout.viewport.bottom,Layout.viewport.top=canvas.bottom,canvas.top;Layout.focusY=canvas.focus;Layout.firstY=canvas.focus-canvas.gap;Layout.maxScroll=Layout.firstY+16*canvas.gap-canvas.focus
  Theme.layout.map.floorGap,Theme.layout.map.columnGap=canvas.gap,canvas.columnGap
  local dx,dy=(width-1600)/2,(height-900)/2
  for name,p in pairs(Layout.figmaAnchors)do
   if not name:match('^token')and not name:match('^legend')and not name:match('^floor')then
    local x,y=p[1],p[2]
    if name=='figmaStatus'then y=y-dy
    else y=y+dy;if x < -100 then x=x-dx elseif x>100 then x=x+dx end end
    at(name):SetAnchoredPosition(x,y)
   end
  end
  at('floorDenominator'):SetAnchoredPosition(69,height/2-50)
  at('hudPlate'):SetSizeDelta(width,canvas.header);at('hudPlate'):SetAnchoredPosition(0,height/2-canvas.header/2)
  at('hudDivider'):SetSizeDelta(width-40,1);at('hudDivider'):SetAnchoredPosition(0,height/2-canvas.header)
  at('figmaBackdrop'):SetSizeDelta(width,height);at('previewReturn'):SetAnchoredPosition(0,-height/2+38)
  at('mapPanel'):SetSizeDelta(width,height);at('dragArea'):SetSizeDelta(math.min(width,900),canvas.top-canvas.bottom);at('dragArea'):SetAnchoredPosition(0,(canvas.top+canvas.bottom)/2)
  at('menuDismiss'):SetSizeDelta(width,height);at('menuPopup'):SetAnchoredPosition(width/2-134,height/2-168)
  local lx=width/2-(canvas.compact and 29 or 109)
  for _,name in ipairs({'legendBorder','legendPlate','legendTitle'})do at(name):SetAnchoredPosition(lx,name=='legendTitle'and 137 or 0)end
  at('legendBorder'):SetSizeDelta(canvas.legendWidth+1,317);at('legendPlate'):SetSizeDelta(canvas.legendWidth-1,315);at('legendTitle'):SetVisible(legendOpen and not canvas.compact)
  for i=0,6 do local y=98-i*36;at('legendIcon'..i):SetAnchoredPosition(canvas.compact and lx or lx-58,y);at('legendText'..i):SetAnchoredPosition(lx+7,y);at('legendCount'..i):SetAnchoredPosition(lx+73,y);at('legendHit'..i):SetAnchoredPosition(lx,y);at('legendHit'..i):SetSizeDelta(canvas.legendWidth,36);at('legendText'..i):SetVisible(legendOpen and not canvas.compact);at('legendCount'..i):SetVisible(legendOpen and not canvas.compact)end
  local railX=-width/2+(canvas.compact and 26 or 78);local bottom=-height/2+40;local top=height/2-canvas.header-24
  for f=1,17 do local y=bottom+(f-1)*(top-bottom)/16;for _,prefix in ipairs({'floorMark','floorMarkHole','floorCurrentGlow','floorHit','floorLabel'})do at(prefix..f):SetAnchoredPosition(railX+(prefix=='floorLabel'and 23 or 0),y)end end
  for _,side in ipairs({'Left','Right'})do for j=0,27 do for k=0,9 do local c=at('pillar'..side..j..'Seg'..k);c:SetVisible(not(canvas.compact and side=='Right'));local pts={{5,29},{5,5},{29,5},{29,25},{11,25},{11,11},{23,11},{23,19},{18,19},{18,15},{18,15}};local a,b=pts[k+1],pts[k+2];local x=side=='Left'and(-width/2+(canvas.compact and 4 or 56))or(width/2-284);c:SetAnchoredPosition(x+(a[1]+b[1])/2,height/2-j*34-(a[2]+b[2])/2)end end end
  if canvas.compact then
   at('actTitle'):SetAnchoredPosition(0,height/2-56);at('figmaTitle'):SetAnchoredPosition(-10,height/2-77);at('figmaTitle').fontSize=18;at('figmaTitle').minimumFontSize=18;at('floorDenominator'):SetAnchoredPosition(55,height/2-81)
   for f=1,17 do at('progress'..f):SetAnchoredPosition(-72+(f-1)*9,height/2-98);at('progressHole'..f):SetAnchoredPosition(-72+(f-1)*9,height/2-98)end
   at('actRuleLeft'):SetVisible(false);at('actRuleRight'):SetVisible(false)
  else at('figmaTitle').fontSize=24;at('figmaTitle').minimumFontSize=24;at('actRuleLeft'):SetVisible(true);at('actRuleRight'):SetVisible(true)end
  self:focusCurrent();return true
 end
 local nativeVisible=ui.setVisible
 function ui:setVisible(visible)if not visible then cameraAt=nil;hovered=nil;menuOpen=false;at('mapMenu'):SetVisible(false)end;return nativeVisible(self,visible)end
 local nativeChoose,nativeFocus=ui.choose,ui.focusCurrent;local choosingView=false;local frozenScroll
 function ui:focusCurrent(animated)
  if choosingView then return self:setScroll(frozenScroll)end
  return nativeFocus(self,animated)
 end
 function ui:choose(id)
  if menuOpen then return false,'map_menu_open'end
  frozenScroll=self.scroll;choosingView=true;local accepted,reason=nativeChoose(self,id);choosingView=false
  if accepted then cameraAt=elapsed+.8;hovered=nil;tooltip();if not self.reducedMotion then pickedId=id;pickedAt=elapsed;paintPick()end end
  return accepted,reason
 end
 function ui:render()originalRender(self);draw()end
 function ui:update(dt)
  if tokenOwner~=self.map or lastCurrent~=(self.map and self.map.currentNodeId)then cameraAt=nil end
  if cameraAt and elapsed>=cameraAt and self.visible then cameraAt=nil;nativeFocus(self,true)end
  originalUpdate(self,dt)
  if not self.visible or not self.map then return end
  local key=tostring(self.map)..':'..tostring(self.map.currentNodeId)..':'..tostring(self.scroll)
  if not painted or generation~=key then draw()end
  elapsed=elapsed+math.max(0,math.min(dt or 0,.1))
  updateToken();local tipWrites=tooltip()
  local writes=(tokenTo and 8 or 0)+tipWrites
  writes=writes+paintTransition()
  at('ritualDisc').localRotationZ=self.reducedMotion and 0 or elapsed*360/300;at('ritualDisc'):SetAnchoredPosition(0,-self.scroll*.1);writes=writes+2
  for _,v in ipairs(visibleIcons)do local pulse=hovered==v.id and(v.state=='available'and 1.32 or v.state=='future'and 1.12 or 1)or v.state=='available'and not self.reducedMotion and(1+.07*(1-math.cos(elapsed*2*math.pi/1.8)))or 1;v.icon:SetSizeDelta(v.size*pulse,v.size*pulse);tint(v.icon,v.ink[1],v.ink[2],v.ink[3],v.alpha);writes=writes+2;if shakeId==v.id then local t=math.min(1,(elapsed-shakeAt)/.36);local key={0,-4,4,-3,2,0};local k=math.min(5,math.floor(t*5)+1);local f=t*5-(k-1);v.icon:SetAnchoredPosition(key[k]+(key[k+1]-key[k])*f,v.baseY);writes=writes+1;if t==1 then shakeId=nil end end end
  assert(writes<=M.ANIMATED_WRITES,'native icon animation budget exceeded')
  if not self.reducedMotion then for _,edge in ipairs(anim)do
   local points=Curve.dots(edge.a,edge.b,{bottom=Layout.viewport.bottom+4,top=Layout.viewport.top-4},14,elapsed*14/1.1,25,edge.trim,128)
   for j=1,edge.count do local p=points[j];writes=writes+(p and 4 or 1);assert(writes<=M.ANIMATED_WRITES,'animated curve budget exceeded')
    local c=at('p'..(edge.first+j-1));c:SetVisible(p~=nil);if p then c:SetAnchoredPosition(p.x,p.y);c.localRotationZ=p.angle;tint(c,246,223,164,math.floor(255*M.fade(p.y,Layout.viewport.bottom,Layout.viewport.top)))end
   end
  end end
  -- All 26 positions advance together every normal frame. Only unchanged integer
  -- alpha writes are skipped; do not round-robin particle positions into visible steps.
  if self.reducedMotion and ambientShown and M.ANIMATED_WRITES-writes>=26 then
   for i=0,25 do at('ember'..i):SetVisible(false)end;writes=writes+26;ambientShown=false
  end
  local revealWrites=ambientShown and 0 or 26
  if not self.reducedMotion and M.ANIMATED_WRITES-writes>=(ambientShown and 26 or 130) then
   local samples={};for i=0,25 do local p=M.emberSample(i,elapsed,self.canvasWidth or 1600,self.canvasHeight or 900);samples[i]=p;at('ember'..i):SetAnchoredPosition(p.x,p.y);writes=writes+1 end
   for i=0,25 do local alpha=samples[i].alpha;emberAlpha[i]=emberAlpha[i]or{};for j,spec in ipairs({{'emberGlow',12},{'emberMid',25},{'emberCore',230}})do local a=math.floor(alpha*spec[2]);if emberAlpha[i][j]~=a and writes<M.ANIMATED_WRITES-revealWrites then local core=j==3;tint(at(spec[1]..i),core and 246 or 240,core and 201 or 188,core and 120 or 114,a);emberAlpha[i][j]=a;writes=writes+1 end end end
   if not ambientShown then for i=0,25 do at('ember'..i):SetVisible(true)end;writes=writes+26;ambientShown=true end
  end
  -- Nonessential sparks use what remains after continuous ambience and critical input/path motion.
  if writes<M.ANIMATED_WRITES then writes=writes+paintPick(M.ANIMATED_WRITES-writes)end
  self.spikeAnimatedWrites=writes;assert(writes<=M.ANIMATED_WRITES,'presentation animation budget exceeded')

 end
 local function setMenu(value)
  menuOpen=value;at('mapMenu'):SetVisible(value);at('menuHelp'):SetVisible(false);at('menuMain'):SetVisible(true);hovered=nil;tooltip()
 end
 at('menuHit'):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()if ui.visible then setMenu(not menuOpen)end end)
 at('menuDismiss'):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()setMenu(false)end)
 at('menuContinue'):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()setMenu(false)end)
 at('menuLegend'):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()
  legendOpen=not legendOpen;for _,name in ipairs({'legendBorder','legendPlate','legendTitle'})do at(name):SetVisible(legendOpen)end
  for i=0,6 do for _,prefix in ipairs({'legendIcon','legendText','legendCount','legendHit'})do at(prefix..i):SetVisible(legendOpen and(not canvas or not canvas.compact or prefix=='legendIcon'or prefix=='legendHit'))end end
  at('menuLegendLabel').text=legendOpen and '收起图例' or '展开图例';setMenu(false)
 end)
 at('menuHelpHit'):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()at('menuMain'):SetVisible(false);at('menuHelp'):SetVisible(true)end)
 for i=1,Layout.maxNodes do local slot=i;local hit=at('node'..slot):GetChild('hit')
  if Enum.CursorEventType.CursorEnter then hit:AddCursorEventListener(Enum.CursorEventType.CursorEnter,function(event)
   if not ui.visible or event and type(event.touchId)=='number'and event.touchId>=0 then return end;hovered=ui.slots[slot];hoverSince=elapsed;draw()
  end)end
  if Enum.CursorEventType.CursorExit then hit:AddCursorEventListener(Enum.CursorEventType.CursorExit,function()if hovered==ui.slots[slot]then hovered=nil;draw()end end)end
  -- Touch information never issues a second choose command: existing native listener owns that.
  hit:AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function(event)
   if not ui.visible then return end;local id=ui.slots[slot];local meta=id and nodeMeta[id]
   if meta and meta.state~='available' and meta.state~='current'then hovered=id;hoverSince=elapsed;if meta.state=='sealed'or meta.state=='future'then shakeId=id;shakeAt=elapsed end;tooltip()end
  end)
 end
 for i,t in ipairs(types)do at('legendHit'..(i-1)):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()if not ui.visible then return false,'map_hidden'end;filter=filter==t and nil or t;draw()end)end
 for f=1,17 do local floor=f;at('floorHit'..f):AddCursorEventListener(options.clickEvent or Enum.CursorEventType.CursorClick,function()if not ui.visible then return false,'map_hidden'end;ui:setScroll(Layout.firstY+(floor-1)*Theme.layout.map.floorGap-Layout.focusY)end)end
 draw();return ui
end
return M
