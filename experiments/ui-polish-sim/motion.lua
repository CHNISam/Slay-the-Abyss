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
-- Motion probe: the REAL abyss_map_ui update(dt) advances MapRoomNode oscillate (breath scale/alpha)
-- between captures. Each frame = resolved tree after N seconds of host-driven update.
local ui,root=F.fixture()
local function capture(name)
    local controls={}
    for _,s in ipairs(Layout)do controls[#controls+1]=dump(root:GetChild(s.name),s)end
    scenes[#scenes+1]={name=name,tree={name='root',kind='container',size={1280,720},children=controls}}
end
assert(ui:start());assert(ui:selectCharacter('traveler'))
assert(F.confirmStart(ui,'ironclad'));for _=1,10 do ui:update(0.1)end
local step=tonumber(os.getenv('MOTION_STEP')) or 0.35
local n=tonumber(os.getenv('MOTION_FRAMES')) or 4
for i=0,n-1 do
  if i>0 then for _=1,7 do ui:update(step/7) end end
  local fx={} for _,f in ipairs(ui.mapUI.activeFx or {}) do if f.state=='available' then fx[#fx+1]=string.format('%.3f/%.2f',f.scale,f.alpha) end end
  io.stderr:write('FRAME t'..i..' available scale/alpha '..table.concat(fx,' ')..'\n')
  capture('motion-t'..i)
end
print('PARITY_SCENES '..encode(scenes))
