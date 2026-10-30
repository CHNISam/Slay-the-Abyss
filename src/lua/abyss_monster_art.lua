-- One shared portrait pool. Additional matching enemies retain their gallery.
local CardDisplay=require('abyss_card_display')
local Data=require('abyss_monster_art_data')
local M={}
local bindings=setmetatable({},{__mode='k'})
-- Failed writes still have an owner, but never a paintable pose binding.
local owners=setmetatable({},{__mode='k'})
local function optionalChild(box,name)
 local ok,control=pcall(box.GetChild,box,name)
 return ok and control or nil
end
local function tint(state,colour,alpha)
 local key=table.concat({colour.r,colour.g,colour.b,colour.a or 255,alpha},':')
 if key==state.tone then return end
 state.tone=key
 local pool=state.root:GetChild('monsterSamples')
 for index,slot in ipairs(state.asset.slots)do
  local group=pool:GetChild(string.format('group%03d',math.floor((index-1)/60)))
  local control=group:GetChild(string.format('shape%04d',index-1))
  local c=slot.colour
  control.imageColor=state.platform.color(math.floor(c[1]*colour.r/255),math.floor(c[2]*colour.g/255),
   math.floor(c[3]*colour.b/255),math.floor(c[4]*(colour.a or 255)/255*alpha))
 end
end
function M.pose(box,x,y,sx,sy,colour,alpha)
 local state=bindings[box]
 if not state then return end
 state.root:SetAnchoredPosition(state.x+x-state.origin[1],state.y+y-state.origin[2])
 state.root:SetLocalScale(sx,sy,1)
 state.root:SetVisible(alpha>0)
 tint(state,colour,alpha)
end
function M.new(stage,platform,data)
 data=data or Data
 local overlay=optionalChild(stage,'topBar')
 local view={root=overlay and optionalChild(overlay,'monsterArt'),platform=platform,data=data,origin=data.hostOrigin or {0,0}}
 view.host={GetChild=function(_,name)return view.root and view.root:GetChild(name=='artSamples' and 'monsterSamples' or name)end}
 function view:clear()
  if not self.root then return end
  if self.box then
   bindings[self.box]=nil;owners[self.box]=nil
   self.box:GetChild('portrait'):SetVisible(true)
  end
  CardDisplay.clearNativeArt(self.host)
  self.root:SetVisible(false)
  self.box,self.asset,self.tone,self.actorId=nil,nil,nil,nil
 end
 function view:select(rows)
  local wanted,wantedId
  if self.root and self.data.enabled and self.platform.nativeMonsterArtEnabled~=false then
   for slot,entry in ipairs(rows)do
    if entry.actor.definitionId==self.data.asset.enemyId then wanted,wantedId=stage:GetChild('enemy'..slot),entry.id;break end
   end
  end
  if wanted~=self.box or wantedId~=self.actorId then self:clear();self.box,self.actorId=wanted,wantedId end
  if wanted then owners[wanted]=self end
 end
 function view:write(box,x,y,portrait,colour)
  if box~=self.box then return false end
  self.asset=self.data.asset
  local fallback=box:GetChild('portrait')
  local ok=CardDisplay.writeNativeArt(self.host,{id=self.asset.enemyId},self.asset,self.platform,fallback)
  if not ok then bindings[box]=nil;self.root:SetVisible(false);return false end
  self.x,self.y=x,y
  local pool=self.root:GetChild('monsterSamples')
  local scale=portrait/math.max(self.data.canvas[1],self.data.canvas[2])
  pool:SetLocalScale(scale,scale,1)
  bindings[box]=self
  M.pose(box,0,0,1,1,colour,1)
  return true
 end
 return view
end
function M.clearBox(box)
 local state=owners[box]
 if state then state:clear()end
end
return M
