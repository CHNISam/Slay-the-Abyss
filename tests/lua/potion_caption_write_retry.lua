local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel=H.setup({'defend'},{'cultist'})
local caption=panel:GetChild('potionHelp'):GetChild('potionCaption1')
host.run.potions={};ui:render()
local visible=caption.SetVisible
local attempts=0
caption.SetVisible=function(self,value)
 attempts=attempts+1
 if attempts==1 then return false end
 return visible(self,value)
end
host.run.potions={'strength_potion'};ui:render()
assert(not caption.visible,'rejected visibility must not appear successful')
ui:render()
assert(caption.visible and attempts==2,'rejected visibility must be retried on the next render')
ui:render();assert(attempts==2,'successful unchanged visibility stays cached')
caption.SetVisible=visible
-- A later text write can throw after visibility has succeeded. Neither partial
-- output nor the previously committed state may suppress the following retry.
host.run.potions={};ui:render()
local mt=getmetatable(caption);local failing={}
for key,value in pairs(mt)do failing[key]=value end
local writes=0
failing.__newindex=function(self,key,value)
 if key=='text' then writes=writes+1;if writes==1 then error('injected caption text failure')end end
 return mt.__newindex(self,key,value)
end
rawset(caption,'text',nil);setmetatable(caption,failing)
host.run.potions={'strength_potion'}
local ok,why=pcall(function()ui:render()end)
assert(not ok and tostring(why):find('injected caption text failure',1,true),'text fault must remain explicit')
host.run.potions={};ui:render()
assert(not caption.visible and caption.text=='','return to formerly cached state repairs partial native output')
host.run.potions={'strength_potion'};ui:render()
assert(caption.visible and caption.text=='力','text and visibility recover after the failure')
setmetatable(caption,mt)
print('POTION_CAPTION_WRITE_RETRY_PASS')
