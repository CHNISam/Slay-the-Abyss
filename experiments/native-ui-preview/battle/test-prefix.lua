local writes=0
local function node(name)
 local values={name=name,children={},visible=true}
 local methods={}
 function methods:GetChild(n)if not values.children[n]then values.children[n]=node(n)end;return values.children[n]end
 function methods:SetAnchoredPosition(x,y)if (name:match('^hand%d+$') or name=='hit')then writes=writes+1 end;if values.throw then error('setter failed')end;if values.nested then local fn=values.nested;values.nested=nil;fn()end;if values.fail then return false end;values.x,values.y=x,y end
 function methods:GetAnchoredPosition()return values.x or 0,values.y or 0 end
 function methods:SetLocalScale(x,y,z)if (name:match('^hand%d+$') or name=='hit')then writes=writes+1 end;if values.fail then return false end;values.scale=x end
 function methods:SetSizeDelta(w,h)if name=='hit'then writes=writes+1 end;if values.fail then return false end;if values.throw then error('hit size failed')end;values.w,values.h=w,h end
 function methods:SetVisible(v)values.visible=v end
 function methods:SetImage()end
 function methods:SetAsLastSibling()end
 function methods:AddCursorEventListener(kind,fn)assert(type(fn)=='function');values.listeners=values.listeners or {};values.listeners[kind]=fn end
 return setmetatable({}, {__index=function(_,k)return methods[k]or values[k]end,__newindex=function(_,k,v)if k=='localRotationZ'and (name:match('^hand%d+$') or name=='hit')then writes=writes+1 end;values[k]=v end})
end
Enum={ImageSource={StaticReference=1},CursorEventType={CursorClick=1,CursorDown=2,CursorDrag=3,CursorUp=4,CursorEndDrag=5,CursorEnter=6,CursorExit=7}}
game={GetUICanvasSize=function()return 1280,720 end,GetCursorUIPos=function()return nil,nil end}
script={object=node('root'),EnableUpdate=function()end}
local AUTO_SEMANTIC_DEMO=false
