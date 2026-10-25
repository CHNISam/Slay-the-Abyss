-- Real production module, isolated UI contract; never a platform performance result.
local live,moves,creates=0,0,0
local function node(parent)
 local c={alive=true,children={}}
 if parent then parent.children[#parent.children+1]=c end
 function c:SetAnchoredPosition() moves=moves+1 end
 function c:SetImage(source,id) assert(source==1 and id>=100001 and id<=100003) end
 return setmetatable(c,{__index=function() return function() end end})
end
local function destroy(c)
 assert(c.alive,'double destroy')
 for _,v in ipairs(c.children) do destroy(v) end
 c.alive=false;live=live-1
end
game={InstantiateClientUIControl=function(_,parent) creates=creates+1;live=live+1;return node(parent) end,DestroyClientUIControl=destroy}
Enum={ImageSource={StaticReference=1}}
Color={FromRGBA=function(...) for _,v in ipairs({...}) do assert(v>=0 and v<=255) end;return {...} end}
local M=dofile(arg[1] or 'art/spikes/art-pressure/production-25d.lua')
local root=node()
for _,mode in ipairs({'static','parallax'}) do
 local scene=M.new(root,1,2,{mode=mode})
 scene:show();assert(live==220 and scene.primitiveCount==207 and scene.containerCount==13)
 local made=creates;scene:show();assert(creates==made,'show must be idempotent')
 local before=moves
 for i=1,30 do scene:update(1/30) end
 assert(moves-before==(mode=='static' and 0 or 150),'mode must control layer movement')
 assert((mode=='static' and scene.phase==0) or (mode=='parallax' and scene.phase>0))
 scene:clear();assert(live==0);scene:clear();assert(live==0)
 scene:show();assert(live==220);scene:clear();assert(live==0)
end
assert(M.new(root,1,2).mode=='parallax','preserve default')
assert(not pcall(M.new,root,1,2,{mode='invalid'}),'reject invalid mode')
io.write('PASS production modes: real207 shapes/13 containers, static zero movement, parallax five layer updates, idempotence and rebuild\n')
