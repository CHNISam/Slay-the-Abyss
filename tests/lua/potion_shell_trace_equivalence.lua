-- Pre-extraction shell renderer from 690a4a5797a6973985f04bf2c4e8f2136b848f8e.
-- QA-R2-02 moves identity captions to full-canvas siblings; compatibility labels now only hide.
-- Mock only native controls: compare ordered paths/writes, not just final visibility.
local Theme=require('abyss_theme')
local PotionView=require('abyss_battle_potion_view')
local Renderer=require('abyss_battle_render_actors')
local function before(owner,dependencies)
 local C=Theme.color
    local function potionSelected(slot)
        return owner.potionMenu and owner.potionMenu.slot==slot
            or owner.potionAim and owner.potionAim.slot==slot
    end
    local function paintPotionShell(slot,item)
        local selected=item~=nil and potionSelected(slot)==true
        local tones=C.potionShell
        for _,state in ipairs({'normal','hover','pressed','disabled'})do
            local face=dependencies.child('potion'..slot):GetChild(state)
            face:GetChild('emptyShell'):SetVisible(item==nil)
            face:GetChild('filledShell'):SetVisible(item~=nil and item.id~='fire_potion')
            face:GetChild('fireShell'):SetVisible(item~=nil and item.id=='fire_potion')
            face:GetChild('selectedShell'):SetVisible(selected)
            dependencies.tint(face:GetChild('filledShell'):GetChild('rim'),selected and tones.selected.border or tones.normal.border)
            dependencies.tint(face:GetChild('fireShell'):GetChild('rim'),selected and tones.selected.border or tones.fire.border)
            local bottle=face:GetChild('bottle');bottle:SetVisible(item~=nil)
            face:GetChild('label'):SetVisible(false)
            if item then
                dependencies.picture(bottle,Theme.icon.potion[item.id] or Theme.icon.intent.unknown)
                dependencies.tint(bottle,(Theme.icon.potionTint or {})[item.id]
                    or (item.id=='fire_potion' and tones.fire.ink or tones.normal.ink))
            end
        end
    end
 return paintPotionShell
end
local function value(v)
 if type(v)~='table' then return tostring(v) end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
 local parts={};for _,k in ipairs(keys)do parts[#parts+1]=k..'='..value(v[k])end
 return '{'..table.concat(parts,',')..'}'
end
local function fixture()
 local trace,controls={},{}
 local allowed={}
 for _,state in ipairs({'normal','hover','pressed','disabled'})do
  local p='potion3/'..state;allowed[p]=true
  for _,name in ipairs({'emptyShell','filledShell','fireShell','selectedShell','bottle','label'})do allowed[p..'/'..name]=true end
  allowed[p..'/filledShell/rim']=true;allowed[p..'/fireShell/rim']=true
 end
 allowed.potion3=true
 local function note(op,path,v)trace[#trace+1]=op..':'..path..':'..value(v)end
 local function control(path)
  assert(allowed[path],'unexpected native path '..path)
  if controls[path]then return controls[path]end
  local c={path=path}
  function c:GetChild(name)note('GetChild',path,name);return control(path..'/'..name)end
  function c:SetVisible(v)note('SetVisible',path,v)end
  setmetatable(c,{__newindex=function(_,key,v)assert(key=='text','unexpected field '..key);note('text',path,v)end})
  controls[path]=c;return c
 end
 return trace,{
  child=function(name)note('child',name,'');return control(name)end,
  tint=function(c,v)note('tint',c.path,v)end,
  picture=function(c,v)note('picture',c.path,v)end,
 }
end
local items={false,{id='fire_potion',name='火焰药水'},{id='energy_potion',name='能量药水'},
 {id='dexterity_potion',name='敏捷药水'},{id='future_unknown',name='未知药水'}}
local owners={{},{potionMenu={slot=3}},{potionMenu={slot=2}},{potionAim={slot=3}},
 {potionAim={slot=2}},{potionMenu={slot=2},potionAim={slot=3}}}
local original=Theme.icon.potionTint
local count=0
for _,palette in ipairs({original,false,{}})do
 Theme.icon.potionTint=palette or nil
 for _,item in ipairs(items)do for _,owner in ipairs(owners)do
  local a,old=fixture();before(owner,old)(3,item or nil)
  local b,new=fixture();Renderer.install(owner,{}, {platform={}},new).paintPotionShell(3,item or nil)
  assert(#a==#b,'different native call count')
  for i,line in ipairs(a)do assert(line==b[i],'native trace changed at '..i..': '..line..' ~= '..tostring(b[i]))end
  assert(#b>0,'empty trace cannot pass');count=count+1
 end end
end
Theme.icon.potionTint=original
assert(count==90,'all empty/known/unknown, owner and palette combinations must run')
print('POTION_SHELL_TRACE_EQUIVALENCE '..count..' cases passed')
