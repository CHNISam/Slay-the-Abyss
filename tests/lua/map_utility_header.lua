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
    UI.refreshEntry(hit,run,{imageSource='static'})
    assert(run.potions==inventory,'painting must retain physical inventory identity')
    for _,name in ipairs(states)do
        local variant=hit:GetChild(name)
        assert(variant:GetChild('label').text=='药水 '..count..'/'..capacity)
        assert(not variant:GetChild('label').visible,'legacy count is hidden, not removed from contract')
        for i=1,5 do
            local slot=variant:GetChild('slot'..i);local id=run.potions[i]
            assert(slot.visible==(i<=capacity),'actual capacity, not potion count, decides physical slots')
            assert(slot:GetChild('bottle').visible==(i<=capacity and id~=nil),'empty slots never keep stale bottles')
            if i<=capacity and id then assert(slot:GetChild('bottle').image==Theme.icon.potion[id],'reuse official ID')end
            assert(run.potions[i]==before[i],'painting must not consume or compact inventory')
        end
    end
end
check(3,0)
run.potions={[1]='fire_potion',[3]='block_potion'};check(3,2)
run.potionSlots=5;run.potions[5]='energy_potion';check(5,3)
run.potions[1]=nil;check(5,2)
run.potions[3]='strength_potion';check(5,2)
run.potionSlots=3;check(3,1)
UI.refreshEntry(hit,nil,{imageSource='static'})
for _,name in ipairs(states)do
    local variant=hit:GetChild(name);assert(variant:GetChild('label').text=='药水')
    for i=1,5 do assert(not variant:GetChild('slot'..i).visible)end
end
print('MAP_UTILITY_HEADER_PASS 4 states, 3/5 capacity, sparse official icons, discard/refill and reset')
return {root=root,hit=hit,run=run,control=control}
