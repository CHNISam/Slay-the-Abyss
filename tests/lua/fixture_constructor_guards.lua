local F=dofile('tests/lua/support/game_ui_fixture.lua')
local probe=F.control({name='probe',kind='container',size={1,1}})
local meta=getmetatable(probe)
local original=meta.__newindex
local admissions=0
meta.__newindex=function(box,key,value)
 admissions=admissions+1
 return original(box,key,value)
end
local root=F.control({name='root',kind='container',size={20,20},children={
 {name='cursor',kind='cursorArea',size={10,10}},
 {name='grid',kind='grid',size={10,10},itemTemplate='AbyssDeckCard'},
}})
meta.__newindex=original
assert(admissions==0,'trusted constructor fields must not repeatedly dispatch native write guards: '..admissions)
for _,box in ipairs({root,root:GetChild('cursor'),root:GetChild('grid')})do
 for _,method in ipairs({'GetChild','SetVisible','SetSizeDelta','SetImage','AddCursorEventListener'})do
  assert(type(rawget(box,method))=='function','native methods must remain own fields')
 end
 for _,key in ipairs({'alive','activeInHierarchy'})do
  assert(not pcall(function()box[key]=true end),'read-only native field accepted: '..key)
 end
end
local cursor=root:GetChild('cursor')
assert(not pcall(function()cursor.interactable=true end),'CursorArea accepted forbidden interactable')
assert(not pcall(function()root:SetVisible(nil)end),'boolean visibility contract weakened')
assert(not pcall(function()root:SetSizeDelta(0/0,10)end),'finite geometry contract weakened')
cursor:AddCursorEventListener('click',function()end)
assert(not pcall(function()cursor:AddCursorEventListener('click',function()end)end),'duplicate listener accepted')
assert(not pcall(function()root:AddCursorEventListener('click',function()end)end),'container accepted pointer listener')
local other=F.control({name='other',kind='container',size={20,20}})
assert(other.children~=root.children and other.listeners==nil,'fixture instances share mutable state')
print('FIXTURE_CONSTRUCTOR_GUARDS_PASS')
