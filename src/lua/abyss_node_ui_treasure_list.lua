-- CombatRewardScreen's visible reward rows, adapted to the shared node canvas.
local Nodes = require('abyss_nodes')
local Theme = require('abyss_theme')
local L = Theme.layout.nativeNode.rewardList
local M = {}
local integer=require('abyss_numbers').integer
local function label(c,item)
    if item.kind=='gold' then return integer(item.amount)..' 金币' end
    if item.kind=='sapphire' then return '蓝钥匙' end
    return '遗物 · '..c.relicName(item.id)
end
local function description(c,item,boss)
    if item.kind=='gold' then return '点击领取 · 不影响其他奖励' end
    if item.kind=='sapphire' then return '二选一 · 放弃「'..c.relicName(item.relicId)..'」' end
    if not item.available then return '暂不可领取 · 可领取其他奖励或离开' end
    local prefix = boss and '三选一 · ' or item.linkedSlot and '与蓝钥匙二选一 · ' or ''
    return prefix..c.relicText(item.id)
end
local function binding(c,key,box,item,index,linked,boss,bind)
    local owner=c.self
    local token=Nodes.treasureRewardSource(owner.run,item.slot)
    local command,argument,choice='claimTreasureReward',token,nil
    local projection=function()return Nodes.treasureRewardSource(owner.run,item.slot)end
    if boss then command,argument='claimBossTreasure',index
    elseif linked and (item.origin=='base' or item.kind=='sapphire') then
        command,argument,choice='chooseTreasure',linked,item.kind=='sapphire' and 'sapphire' or 'relic'
        token=linked
        projection=function()return Nodes.treasureSource(owner.run,owner.map)end
    end
    return bind(c,key,box,token,projection,command,argument,
        function()return '已领取「'..label(c,item)..'」'end,choice,true,item)
end
local function renderRow(c,panel,item,index,y,opened,linked,boss,bind)
        local key='treasureView/rewardItem'..index
        local box=panel:GetChild('rewardItem'..index)
        c.show(box,opened and item~=nil)
        if item then
            local available=item.kind~='relic' or item.available==true
            c.state(box,available)
            box:GetChild('name').text=(available and '领取 · ' or '')..label(c,item)
            box:GetChild('description').text=description(c,item,boss)
            c.picture(box:GetChild('icon'),item.kind=='gold' and Theme.icon.gold or Theme.icon.relic[item.id] or Theme.icon.node.treasure)
            local handler,observe=binding(c,key,box,item,index,linked,boss,bind)
            c.action(key,opened and available,handler,nil,nil,observe)
            c.details:set(key,label(c,item),description(c,item,boss))
        else c.action(key,false,function()return false end) end
        box:SetAnchoredPosition(L.x,y);box:SetLocalScale(1,1,1)
end
function M.render(c,panel,items,opened,linked,bind)
    local boss=c.node.roomKind=='boss_treasure'
    for _,name in ipairs({'reward','take','previous','next'})do
        c.show(panel:GetChild(name),false);c.action('treasureView/'..name,false,function()return false end)
    end
    for index,y in ipairs(L.rows)do renderRow(c,panel,items[index],index,y,opened,linked,boss,bind)end
    local pose=opened and L.chest or Theme.layout.nativeNode.treasure.chest
    for _,name in ipairs({'closed','open','chest','glow'})do panel:GetChild(name):SetAnchoredPosition(pose[1],pose[2])end
    local heading,note=panel:GetChild('page'),panel:GetChild('bossDescription')
    heading:SetAnchoredPosition(L.heading[1],L.heading[2]);heading:SetSizeDelta(L.heading[3],L.heading[4])
    note:SetAnchoredPosition(L.note[1],L.note[2]);note:SetSizeDelta(L.note[3],L.note[4])
    c.show(heading,opened);c.show(note,opened)
    heading.text=#items>0 and ('宝箱奖励 · '..#items..' 项') or '奖励已领取'
    note.text=boss and '选择一件遗物，其余遗物将放弃' or linked and '金币可独立领取 · 遗物与蓝钥匙只能选一项' or '各项奖励可独立领取'
end
return M
