-- Resolved native controls from the real host; offline evidence, never a device pass.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Layout=require('abyss_ui_layout')
local Templates=require('abyss_ui_templates')
for _,s in ipairs(Layout)do if s.name=='stage' then Layout=s.children;break end end
local function encode(v)
    if type(v)=='string' then return '"'..v:gsub('[%c"\\]',function(c)
        return ({['"']='\\"',['\\']='\\\\',['\n']='\\n'})[c] or string.format('\\u%04x',c:byte())end)..'"' end
    if type(v)~='table' then return v==nil and 'null' or tostring(v)end
    local out={}
    if #v>0 then for _,item in ipairs(v)do out[#out+1]=encode(item)end;return '['..table.concat(out,',')..']'end
    for key,item in pairs(v)do out[#out+1]=encode(key)..':'..encode(item)end
    return '{'..table.concat(out,',')..'}'
end
local function hex(c)return type(c)=='table' and string.format('#%02X%02X%02X%02X',c.r,c.g,c.b,c.a)or c end
local function dump(c,s)
    if c.visible==false then return {name=s.name,kind=s.kind,size=s.size,visible=false}end
    local children={}
    for _,spec in ipairs(s.children or {})do
        if s.kind~='presetButton' or spec.name=='normal' then children[#children+1]=dump(c:GetChild(spec.name),spec)end
    end
    if s.kind=='grid' then
        local template=Templates[s.itemTemplate]
        for i=0,math.min(c.itemCount or 0,12)-1 do
            local card=dump(c.items[i],template)
            local g=s.grid
            card.position={-s.size[1]/2+g.padding[3]+g.itemSize[1]/2+(i%g.columns)*(g.itemSize[1]+g.spacing[1]),
                s.size[2]/2-g.padding[1]-g.itemSize[2]/2-math.floor(i/g.columns)*(g.itemSize[2]+g.spacing[2])}
            children[#children+1]=card
        end
    end
    return {name=s.name,kind=s.kind,visible=c.visible,position={c.x or (s.position or {0,0})[1],c.y or (s.position or {0,0})[2]},
        size={c.sizeDeltaX or s.size[1],c.sizeDeltaY or s.size[2]},scale=c.scale,
        image=c.imageId or s.image,colour=hex(c.imageColor)or s.colour,rotation=c.localRotationZ,opacity=s.opacity,
        text=s.text and {content=c.text,fontSize=s.text.fontSize,minFontSize=s.text.minFontSize,colour=hex(c.fontColor)or s.text.colour,
            align=s.text.align,valign=s.text.valign},
        children=children}
end
local scenes={}
local ui,root=F.fixture()
local function capture(name)
    local controls={}
    for _,s in ipairs(Layout)do controls[#controls+1]=dump(root:GetChild(s.name),s)end
    scenes[#scenes+1]={name=name,tree={name='root',kind='container',size={1280,720},children=controls}}
end
local only=ABYSS_UI_POLISH_SCENES
assert(ui:start());capture('character-select')
assert(ui:selectCharacter('traveler'));capture('character-traveler')
assert(F.confirmStart(ui,'ironclad'));for _=1,5 do ui:update(0.1)end;capture('map-start')
local Nodes=F.Nodes
for _=1,3 do
  if ui.run.phase=='combat' then break end
  local a=Nodes.available(ui.run,ui.map); if not a[1] then break end
  ui.mapUI:choose(a[1].id); for _=1,10 do ui:update(0.1) end
  if ui.run.phase~='combat' and ui.run.phase~='map' then
    -- Neow or event: try continue buttons
    pcall(F.click,root,'nodePanel','choice1'); for _=1,10 do ui:update(0.1)end
  end
end
print('PHASE '..tostring(ui.run.phase))
if ui.run.phase=='combat' then
  for _=1,40 do ui:update(0.05)end;capture('battle')
end
print('PARITY_SCENES '..encode(scenes))
