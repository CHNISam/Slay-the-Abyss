local UI,Theme=require('abyss_potion_discard_ui'),require('abyss_theme')
local states={'normal','hover','pressed','disabled'}
local function control(spec)
    local c={spec=spec,visible=spec.visible~=false,children={},image=spec.image}
    function c:GetChild(name)return self.children[name]end
    function c:SetVisible(value)self.visible=value end
    function c:SetImage(_,id)self.image=id end
    for _,s in ipairs(spec.children or {})do c.children[s.name]=control(s)end
    return c
end
local function find(spec,name)
    if spec.name==name then return spec end
    for _,child in ipairs(spec.children or {})do local found=find(child,name);if found then return found end end
end
local entry=assert(find({children=require('abyss_ui_layout')},'potionEntry'))
local root=control(find(entry,'open'))
local hit=root:GetChild('hit')
local run={potionSlots=3,potions={},data={rules={player={potionSlots=3}}}}
local function check(capacity,count)
    local inventory=run.potions;local before={}
    for i=1,5 do before[i]=inventory[i]end
    UI.refreshEntry(hit,run,{imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
    assert(run.potions==inventory,'painting must retain physical inventory identity')
    for _,name in ipairs(states)do
        local variant=hit:GetChild(name)
        assert(variant:GetChild('label').text=='药水 '..count..'/'..capacity)
        assert(variant:GetChild('label').visible,'approved large management count remains visible')
        for i=1,5 do
            local slot=variant:GetChild('slot'..i);local id=run.potions[i]
            assert(not slot.visible,'compatibility miniature slots stay hidden under count-only entry')
            assert(slot:GetChild('bottle').visible==(i<=capacity and id~=nil),'empty slots never keep stale bottles')
            local shown=i<=capacity and id or nil
            assert(slot:GetChild('emptyShell').visible==(shown==nil),'only empty physical slots use dashed shell')
            assert(slot:GetChild('filledShell').visible==(shown~=nil and shown~='fire_potion'))
            assert(slot:GetChild('fireShell').visible==(shown=='fire_potion'))
            assert(not slot:GetChild('selectedShell').visible,'management entry does not invent per-slot selection')
            assert(not slot:GetChild('border').visible and not slot:GetChild('plate').visible,'old solid shell cannot repaint')
            local face=slot:GetChild('emptyShell'):GetChild('face')
            assert(face.spec.opacity==128/255 and face.spec.colour=='#1A1312','real empty tree preserves alpha and source colour')
            if shown then
                local want=(shown=='fire_potion' and Theme.color.potionShell.fire or Theme.color.potionShell.normal).ink
                local actual=slot:GetChild('bottle').imageColor
                assert(actual.r==want.r and actual.g==want.g and actual.b==want.b)
            end
            if i<=capacity and id then assert(slot:GetChild('bottle').image==Theme.icon.potion[id],'reuse official ID')end
            assert(run.potions[i]==before[i],'painting must not consume or compact inventory')
        end
    end
end
for _,name in ipairs(states)do
    local variant=hit:GetChild(name)
    for i=1,5 do variant:GetChild('slot'..i):GetChild('selectedShell'):SetVisible(true)end
end
check(3,0)
run.potions={[1]='fire_potion',[3]='block_potion'};check(3,2)
run.potionSlots=5;run.potions[5]='energy_potion';check(5,3)
run.potions[1]=nil;check(5,2)
run.potions[3]='strength_potion';check(5,2)
run.potionSlots=3;check(3,1)
UI.refreshEntry(hit,nil,{imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
for _,name in ipairs(states)do
    local variant=hit:GetChild(name);assert(variant:GetChild('label').text=='药水')
    for i=1,5 do assert(not variant:GetChild('slot'..i).visible)end
end
print('MAP_UTILITY_HEADER_PASS 4 states, 3/5 capacity, sparse official icons, discard/refill and reset')
return {root=root,hit=hit,run=run,control=control}
