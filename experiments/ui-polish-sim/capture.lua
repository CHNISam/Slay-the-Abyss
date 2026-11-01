-- Resolved native controls from the real host; offline evidence, never a device pass.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Layout=require('abyss_ui_layout')
local Templates=require('abyss_ui_templates')
local captureText=dofile('experiments/ui-polish-sim/text-style.lua')
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
        image=c.imageId or s.image,colour=hex(c.imageColor)or s.colour,rotation=c.localRotationZ or s.rotation,opacity=s.opacity,
        text=s.text and captureText(c,s,hex),
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
for _=1,5 do ui:update(0.1)end;capture('menu')
F.click(root,'exitEntry','open');for _=1,3 do ui:update(0.1)end;capture('menu-panel')
F.click(root,'runMenu','resume');for _=1,3 do ui:update(0.1)end
if os.getenv('MENU_ONLY') then print('PARITY_SCENES '..encode(scenes));return end
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
  F.click(root,'battlePanel','card1');capture('battle-selected')
  F.win(ui,root);capture('rewards')
  F.click(root,'battlePanel','cardReward');F.click(root,'battlePanel','skip')
  F.click(root,'battlePanel','continue');for _=1,5 do ui:update(0.1)end;capture('map-current')
  local function advance()
    local a=Nodes.available(ui.run,ui.map); local pick=a[1]
    for _,n in ipairs(a) do if n.type=='monster' then pick=n break end end
    if not pick then return false end
    ui.mapUI:choose(pick.id); for _=1,10 do ui:update(0.1) end
    if ui.run.phase~='combat' then local keys={} for k in pairs(ui.nodeUI.actions or {}) do keys[#keys+1]=k end table.sort(keys) io.stderr:write('KEYS '..table.concat(keys,',')..'\n') for _,k in ipairs({'eventView/option3','confirm','confirm'}) do if ui.run.phase=='map' then break end pcall(ui.nodeUI.press,ui.nodeUI,k); for _=1,10 do ui:update(0.1) end end for _=1,6 do if not root:GetChild('nodePanel').visible then break end for _,k in ipairs({'confirm','back'}) do pcall(ui.nodeUI.press,ui.nodeUI,k) for _=1,5 do ui:update(0.1) end end end io.stderr:write('PH '..ui.run.phase..' np='..tostring(root:GetChild('nodePanel').visible)..'\n') for _=1,10 do ui:update(0.1) end return ui.run.phase=='map' end
    for _=1,40 do ui:update(0.05)end
    F.win(ui,root);F.click(root,'battlePanel','cardReward');F.click(root,'battlePanel','skip')
    F.click(root,'battlePanel','continue');for _=1,5 do ui:update(0.1)end
    return ui.run.phase=='map'
  end
  for _=1,(tonumber(os.getenv('DEEP_STEPS')) or 4) do if not advance() then break end end
  for _=1,20 do ui:update(0.1) end
  print('DEEP '..tostring(ui.run.phase)..' '..tostring(ui.map.floor));capture('map-deep')
end

-- Multi-monster fixtures: fresh host, explicit Run encounter (same path tests use).
local Run=require('abyss_run')
for _,fx in ipairs({{'battle-multi','louse_pair',nil,{{-200,10},{80,30}}},{'battle-slimes','small_slimes',nil,{{-230,32},{35,8}}},
  {'battle-trio','louse_trio',4,{{-350,25},{-125,10},{80,30}}}})do
  ui,root=F.fixture()
  assert(ui:start());assert(F.confirmStart(ui,'ironclad'));for _=1,5 do ui:update(0.1)end
  if fx[3] then ui.run.floor=fx[3] end -- encounter minFloor (data/enemies.json)
  local ok,why=Run.startCombat(ui.run,fx[2]);assert(ok,fx[2]..' '..tostring(why))
  -- Legacy named-encounter path has no formation; apply the source MonsterHelper offsets
  -- copied verbatim from abyss_encounter_formation.lua (map rooms get these via sourceRoom).
  for i,p in ipairs(fx[4])do local e=ui.run.combat.enemies[i];if e then e.sourcePosition={x=p[1],y=p[2]}end end
  ui:refresh()
  for _=1,40 do ui:update(0.05)end;capture(fx[1])
end
print('PARITY_SCENES '..encode(scenes))
