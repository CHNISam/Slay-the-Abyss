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
    -- Runtime monster surfaces (abyss_monster_surfaces) are cloned under actorLayer/pages
    -- as nativeActorN; they are not in the static layout spec, so walk them explicitly.
    local dyn={}
    for key,child in pairs(c.children or {})do
        if type(key)=='string' and key:match('^nativeActor%d+$')then dyn[#dyn+1]={tonumber(key:match('%d+')),child}end
    end
    table.sort(dyn,function(a,b)return a[1]<b[1]end)
    for _,d in ipairs(dyn)do
        local child=d[2]
        local spec=Templates.AbyssMonsterActor.name==child.name and Templates.AbyssMonsterActor
            or Templates.AbyssMonsterPower and Templates.AbyssMonsterPower.name==child.name and Templates.AbyssMonsterPower
            or {name=child.name,kind='container',size={1280,720}}
        children[#children+1]=dump(child,spec)
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
-- Select80: production competition profile (single Traveler) — the screen Pan sees.
local scenes={}
local canvas=F.control({children=F.Layout})
local root=F.Viewport.apply(canvas,1280,720)
local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{campaign=true,campaignProfile='competition-two-act',seed=1,
 imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
local function capture(name)
    local controls={}
    for _,s in ipairs(Layout)do controls[#controls+1]=dump(root:GetChild(s.name),s)end
    scenes[#scenes+1]={name=name,tree={name='root',kind='container',size={1280,720},children=controls}}
end
for _=1,3 do ui:update(0.1)end
assert(ui:start());for _=1,3 do ui:update(0.1)end;capture('select')
if root:GetChild('characterPanel'):GetChild('deckView') then
  F.click(root,'characterPanel','details/deckOpen');for _=1,3 do ui:update(0.1)end;capture('select-deck')
end
print('PARITY_SCENES '..encode(scenes))
