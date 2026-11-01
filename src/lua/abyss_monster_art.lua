-- Each drawable actor owns its source-art surface independently.
local CardDisplay=require('abyss_card_display')
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
 state.poseState={x,y,sx,sy,colour,alpha}
 state.root:SetAnchoredPosition(state.x+x-state.origin[1],state.y+y-state.origin[2])
 state.root:SetLocalScale(sx,sy,1)
 state.root:SetVisible(alpha>0)
 tint(state,colour,alpha)
end
local function newPool(stage,platform,data,poolIndex,actorBox)
 local overlay=not actorBox and optionalChild(stage,'topBar')
 local view={root=actorBox and optionalChild(actorBox,'monsterArt') or overlay and optionalChild(overlay,poolIndex and poolIndex>1 and 'monsterArt'..poolIndex or 'monsterArt'),platform=platform,data=data,origin=actorBox and {0,0} or data.hostOrigin or {0,0}}
 view.host={GetChild=function(_,name)return view.root and view.root:GetChild(name=='artSamples' and 'monsterSamples' or name)end}
 function view:onEngineDestroy()
  self.engineDestroyed=true
  if self.box then bindings[self.box]=nil;owners[self.box]=nil end
  self.box,self.asset,self.tone,self.actorId,self.selectedAsset,self.poseState=nil,nil,nil,nil,nil,nil
  self.root=nil
 end
 function view:clear()
  if self.engineDestroyed then return end
  if not self.root then return end
  if self.box then
   bindings[self.box]=nil;owners[self.box]=nil
   self.box:GetChild('portrait'):SetVisible(true)
  end
  CardDisplay.clearNativeArt(self.host)
  self.root:SetVisible(false)
  self.box,self.asset,self.tone,self.actorId,self.selectedAsset,self.poseState=nil,nil,nil,nil,nil,nil
 end
 function view:select(rows)
  assert(not self.engineDestroyed,'monster art engine destroyed')
  local wanted,wantedId,wantedAsset
  if self.root and self.data.enabled and self.platform.nativeMonsterArtEnabled~=false then
   for slot,entry in ipairs(rows)do
    local identity=self.data.bindings and self.data.bindings[entry.actor.definitionId]
    local asset=self.data.assets and self.data.assets[identity] or (entry.actor.definitionId==self.data.asset.enemyId and self.data.asset)
    if asset and (not poolIndex or slot==poolIndex)then wanted,wantedId,wantedAsset=actorBox or stage:GetChild('enemy'..slot),entry.id,asset;break end
   end
  end
  if wanted~=self.box or wantedId~=self.actorId or wantedAsset~=self.selectedAsset then self:clear();self.box,self.actorId=wanted,wantedId end
  self.selectedAsset=wantedAsset
  if wanted then owners[wanted]=self end
 end
 function view:write(box,x,y,portrait,colour)
  assert(not self.engineDestroyed,'monster art engine destroyed')
  if box~=self.box then return false end
  self.asset=self.selectedAsset or self.data.asset
  local fallback=box:GetChild('portrait')
  local ok=CardDisplay.writeNativeArt(self.host,{id=self.asset.enemyId},self.asset,self.platform,fallback)
  if not ok then bindings[box]=nil;self.root:SetVisible(false);return false end
  self.x,self.y=actorBox and 0 or x,actorBox and 0 or y
  local pool=self.root:GetChild('monsterSamples')
  local scale=portrait/math.max(self.data.canvas[1],self.data.canvas[2])
  pool:SetLocalScale(scale,scale,1)
  bindings[box]=self
  local pose=self.poseState
  if pose then M.pose(box,pose[1],pose[2],pose[3],pose[4],pose[5],pose[6])
  else M.pose(box,0,0,1,1,colour,1)end
  return true
 end
 return view
end
function M.new(stage,platform,data,surfaces)
 data=data or (platform.nativeMonsterArtEnabled==false and {} or require('abyss_monster_art_data'))
 if not surfaces then return newPool(stage,platform,data)end -- Explicit legacy unit fixture only.
 local view={pools={}}
 function view:release(box,engineDestroyed)local pool=self.pools[box];if pool then
  if engineDestroyed then pool:onEngineDestroy()else pool:clear()end;self.pools[box]=nil
 end end
 function view:onEngineDestroy()
  self.engineDestroyed=true
  for box in pairs(self.pools)do self:release(box,true)end
 end
 function view:clear()for box in pairs(self.pools)do self:release(box)end end
 function view:select(rows)
  assert(not self.engineDestroyed,'monster art engine destroyed')
  local wanted={}
  for _,entry in ipairs(rows)do
   local box=assert(surfaces:find(entry.id),'missing monster instance surface')
   wanted[box]=true
   local pool=self.pools[box]
   if not pool then pool=newPool(stage,platform,data,nil,box);self.pools[box]=pool end
   pool:select({entry})
  end
  for box,pool in pairs(self.pools)do if not wanted[box]then pool:clear();self.pools[box]=nil end end
 end
 function view:write(box,x,y,portrait,colour)
  assert(not self.engineDestroyed,'monster art engine destroyed')
  local pool=self.pools[box]
  return pool and pool:write(box,x,y,portrait,colour) or false
 end
 return view
end
function M.forgetBox(box)
 local state=owners[box];bindings[box]=nil;owners[box]=nil
 if state then state:onEngineDestroy()end
end
function M.clearBox(box)
 local state=owners[box]
 if state then state:clear()end
end
return M
