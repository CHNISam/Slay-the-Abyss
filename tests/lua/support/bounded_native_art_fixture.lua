local M={created={},destroyed={},failCreate=false,failDestroy=false}
local methods={}
function methods:GetChild(name)assert(self.alive,'dead GetChild');return self.children[name]end
function methods:SetVisible(v)assert(self.alive,'dead visibility');assert(type(v)=='boolean');self.visible=v end
function methods:SetImage(source,id)assert(source=='static');self.image=id end
for _,pair in ipairs({{'SetAnchorMin','anchorMin'},{'SetAnchorMax','anchorMax'},{'SetPivot','pivot'},
 {'SetSizeDelta','size'},{'SetLocalScale','scale'},{'SetLocalRotation','rotation'},{'SetAnchoredPosition','position'}})do
 local method,field=pair[1],pair[2]
 methods[method]=function(self,...)assert(self.alive,'dead transform');self[field]={...};self.writes=(self.writes or 0)+1 end
end
function M.control(kind,parent)
 local c=setmetatable({kind=kind,alive=true,visible=true,parent=parent,children={}},
  {__index=function(_,key)assert(key~='activeInHierarchy','undocumented hierarchy API');return methods[key]end,
   __newindex=function(t,key,value)
    assert(not (kind=='image' and key=='raycastTarget'),'Native Image has no raycastTarget field')
    rawset(t,key,value)
   end})
 return c
end
function M.face()
 local box=M.control('container');box.children.art=M.control('image',box)
 box.children.artSamples=M.control('container',box);box.children.artSamples.visible=false
 return box
end
function M.instantiate(index,parent)
 assert(index==41 or index==73,'template ID was confused with gallery ID')
 if M.failCreate then error('injected instantiate failure')end
 local c=M.control(index==41 and 'image' or 'container',parent)
 c.templateIndex=index;parent.children[#parent.children+1]=c;M.created[#M.created+1]=c
 return c
end
local function die(c)for _,child in pairs(c.children)do die(child)end;c.alive=false end
function M.destroy(c)
 M.destroyCalls=(M.destroyCalls or 0)+1
 if M.failDestroy then return false end
 die(c);M.destroyed[#M.destroyed+1]=c
end
function M.metadata(id,n)
 local slots={}
 for i=1,n do slots[i]={image=i%2==0 and 100002 or 106057,imageType='basic',position={i/10,-i/20},
 size={2,3},scale={1,1},anchorMin={.5,.5},anchorMax={.5,.5},pivot={.5,.5},rotation={11,22,33},colour={4,5,6,7}}end
 return {runtime=true,cardId=id,luaSha256=id,capacity=n,slots=slots}
end
M.platform={imageSource='static',imageTypes={basic=17,stretch=23},color=function(...)return {...}end}
function M.configure(runtime)runtime.configure({instantiate=M.instantiate,destroy=M.destroy,imageTemplateIndex=41,containerTemplateIndex=73})end
return M
