-- Private approved source: menus.js bindReferenceMenuMotion + character-reference.css.
-- One semantic controller is shared by real native callbacks and no-input tests.
function NewMenuController(root,initialPage)
 local c={root=root,page=initialPage or 'menu',generation=0,buttons={},reducedMotion=false,exitAttempted=false}
 local defs={play={'menu','mainMenu','menu'},collection={'menu','mainMenu','menu',true},history={'menu','mainMenu','menu',true},quit={'menu','mainMenu','menu'},back={'character','characterScreen','banner'},embark={'character','characterScreen','banner'},selected={'character','characterScreen','selected'},cancelExit={'exit','exitScreen','modal'},confirmExit={'exit','exitScreen','modal'},backToCharacter={'scope','scopeScreen','modal'}}
 for id,d in pairs(defs)do c.buttons[id]={id=id,page=d[1],panel=d[2],kind=d[3],disabled=d[4] or false,x=0,alpha=0,hovered=false,focused=false,down=false,brightness=1}end
 function c:paint(b)
  local hot=b.hovered or b.focused
  b.brightness=b.kind=='banner' and (b.down and .92 or (hot and 1.18 or 1)) or 1
  if not self.root then return end
  local node=self.root:GetChild(b.panel):GetChild(b.id)
  node:GetChild('focusOutline'):SetVisible(b.focused)
  if b.kind=='menu' then
   node:GetChild('face'):SetAnchoredPosition(b.x,0)
   local glow=node:GetChild('face'):GetChild('glow');glow.imageColor=math.floor(b.alpha*255+.5)*16777216+16777215;glow:SetVisible(b.alpha>0)
  elseif b.kind=='banner' then
   node:GetChild('normal'):SetVisible(b.brightness==1);node:GetChild('hover'):SetVisible(b.brightness==1.18);node:GetChild('pressed'):SetVisible(b.brightness==.92)
  elseif b.kind=='selected' then
   node:GetChild('normal'):SetVisible(not hot);node:GetChild('hover'):SetVisible(hot)
  elseif b.kind=='modal' then
   node:GetChild('hover'):SetVisible(hot);node:GetChild('pressed'):SetVisible(false)
  end
 end
 function c:reset()
  for _,b in pairs(self.buttons)do b.x=0;b.alpha=0;b.hovered=false;b.focused=false;b.down=false;self:paint(b)end
 end
 function c:show(page)
  self.generation=self.generation+1;self.page=page;self:reset()
  if self.root then
   self.root:GetChild('mainMenu'):SetVisible(page=='menu' or page=='exit')
   self.root:GetChild('characterScreen'):SetVisible(page=='character')
   self.root:GetChild('exitScreen'):SetVisible(page=='exit')
   self.root:GetChild('scopeScreen'):SetVisible(page=='scope')
   self.root:GetChild('exitScreen'):GetChild('exitError'):SetVisible(self.exitAttempted)
   if self.rebind then self:rebind()end
  end
 end
 function c:signal(token,id,phase)
  local b=self.buttons[id]
  if token~=self.generation or not b or b.disabled or b.page~=self.page then return false end
  if phase=='enter'then b.hovered=true
  elseif phase=='leave'then b.hovered=false;b.down=false
  elseif phase=='focus'then b.focused=true
  elseif phase=='blur'then b.focused=false;b.down=false
  elseif phase=='down'then b.down=true
  elseif phase=='up'then b.down=false
  elseif phase=='cancel'then b.down=false;b.hovered=false;b.focused=false
  elseif phase=='activate'then
   b.down=false
   if id=='play'then self:show('character')
   elseif id=='back'or id=='cancelExit'then self.exitAttempted=false;self:show('menu')
   elseif id=='quit'then self.exitAttempted=false;self:show('exit')
   elseif id=='embark'then self:show('scope')
   elseif id=='backToCharacter'then self:show('character')
   elseif id=='confirmExit'then self.exitAttempted=true;if self.root then self.root:GetChild('exitScreen'):GetChild('exitError'):SetVisible(true)end
   elseif id=='selected'then self.selectionCount=(self.selectionCount or 0)+1 end
   return true
  else return false end
  local hot=b.hovered or b.focused
  if b.kind=='menu' then
   if hot then b.alpha=.9 end
   if self.reducedMotion then b.x=hot and 50/3 or 0;b.alpha=hot and .9 or 0 end
  end
  self:paint(b);return true
 end
 function c:tick(dt)
  dt=math.max(0,math.min(dt,1/15))
  for _,b in pairs(self.buttons)do
   if b.kind=='menu' and not b.disabled then
    local hot=b.hovered or b.focused;local target=hot and 50/3 or 0
    if self.reducedMotion then b.x=target;b.alpha=hot and .9 or 0
    else
     b.x=b.x+(target-b.x)*math.min(dt*9,1);if math.abs(b.x-target)<2/3 then b.x=target end
     if hot then b.alpha=.9 else b.alpha=b.alpha+(0-b.alpha)*math.min(dt*12,1);if b.alpha<.01 then b.alpha=0 end end
    end
    self:paint(b)
   end
  end
 end
 c:show(c.page);return c
end
