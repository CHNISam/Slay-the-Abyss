-- Synthetic parallax silhouettes, not approved production background artwork.
local IMAGE_PREFAB_ID = 0
local M={stages={
 {'空3D地面',0,0,0,0,0,0,0,0,0},
 {'3D遗迹7模型',0,0,0,0,0,0,1,0,0},
 {'3D遗迹28模型',0,0,0,0,0,0,4,0,0},
 {'3D遗迹84模型',0,0,0,0,0,0,12,0,0},
 {'2.5D三层192图元',0,0,0,0,0,0,0,3,64},
 {'2.5D六层768图元',0,0,0,0,0,0,0,6,128},
 {'2.5D六层1536图元',0,0,0,0,0,0,0,6,256},
 {'3D28+5角色10轻卡',5,0,10,0,0,0,4,0,0},
 {'3D28+5高角10高卡',0,5,0,10,0,0,4,0,0},
 {'2.5D768+轻量组合',5,0,10,0,0,0,0,6,128},
 {'2.5D1536+高精组合',0,5,0,10,0,0,0,6,256},
 {'3D84+高精组合技能',0,5,0,10,10,64,12,0,0},
 {'成品样板：原生3D',0,0,0,0,0,0,100,0,0},
 {'成品样板：2.5D207',0,0,0,0,0,0,0,-1,207},
 {'成品3D+轻量角色卡牌',5,0,10,0,0,0,100,0,0},
 {'成品2.5D+轻量角色卡牌',5,0,10,0,0,0,0,-1,207},
 {'成品3D+高精角色卡牌',0,5,0,10,0,0,100,0,0},
 {'成品2.5D+高精角色卡牌',0,5,0,10,0,0,0,-1,207},
 {'成品纯2D207静态',0,0,0,0,0,0,0,-2,207},
 {'成品纯2D+轻量角色卡牌',5,0,10,0,0,0,0,-2,207},
 {'成品纯2D+高精角色卡牌',0,5,0,10,0,0,0,-2,207},
}}
function M.new(root,hostTemplate)
 local self={root=root,hosts={},groups=-1,phase=0,requestId=0}
 function self:world(groups)
  if self.groups==groups then return end
  self.requestId=self.requestId+1
  local signal=game.ServerSignal('AP_SCENE');signal:AddInt(groups);signal:AddInt(self.requestId);signal:SendSignal()
  self.groups=groups;print('ARTSCENE_REQUEST groups='..groups..' expectedModels='..(groups==100 and 32 or groups*7)..' requestId='..self.requestId)
 end
 function self:clear()
  if self.production then self.production:clear();self.production=nil end
  for _,h in ipairs(self.hosts) do if h.alive then game.DestroyClientUIControl(h) end end
  self.hosts={};self:world(0)
 end
 function self:show(groups,layers,count)
  if self.production then self.production:clear();self.production=nil end
  for _,h in ipairs(self.hosts) do if h.alive then game.DestroyClientUIControl(h) end end
  self.hosts={};self:world(groups)
  root:GetChild('Backdrop'):SetActive(layers>0)
  if layers<0 then
   local holder=assert(game.InstantiateClientUIControl(hostTemplate,root));self.hosts[#self.hosts+1]=holder
   holder:SetActive(true);holder:SetVisible(true);holder:SetSizeDelta(1280,720)
   local w,h=game.GetUICanvasSize();local k=math.min(w/1280,h/720);holder:SetLocalScale(k,k,1)
   self.production=require('AP_Production25D').new(holder,hostTemplate,IMAGE_PREFAB_ID,{mode=layers==-2 and 'static' or 'parallax'});self.production:show()
  end
  for layer=1,layers do
   local holder=assert(game.InstantiateClientUIControl(hostTemplate,root));self.hosts[#self.hosts+1]=holder
   holder:SetActive(true);holder:SetVisible(true)
   for i=1,count do
    local image=assert(game.InstantiateClientUIControl(IMAGE_PREFAB_ID,holder))
    image:SetActive(true);image:SetVisible(true)
    local triangle=(i%3==0)
    image:SetImage(Enum.ImageSource.StaticReference,triangle and 100003 or 100001)
    local x=-720+((i*131+layer*53)%1440)
    local y=-290+((i*67+layer*31)%300)
    image:SetAnchoredPosition(x,y)
    image:SetSizeDelta(triangle and 220 or (30+i%45),triangle and (180+i%140) or (100+i%200))
    image.imageColor=Color.FromRGBA(18+layer*6,29+layer*7,44+layer*6,200)
   end
  end
  print('ARTSCENE_2D layers='..layers..' drawn='..(layers<0 and count or layers*count)..' mode='..(layers==-2 and 'static' or 'parallax'))
 end
 function self:update(dt)
  self.phase=self.phase+dt
  if self.production then self.production:update(dt)
  else for i,h in ipairs(self.hosts) do h:SetAnchoredPosition(math.sin(self.phase*.7)*i*5,0) end end
 end
 return self
end
return M
