-- Fixed319009 retrieval definitions, grouped by their original character.
local M={}
local function copy(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function choice(mode,count) return {op="pileChoice",mode=mode,value=count} end
local groups={
    ironclad={
        {id="headbutt",sourceId="Headbutt",name="头槌",color="red",type="attack",rarity="common",cost=1,
            effects={{op="damage",value=9},choice("headbutt",1)},
            upgrade={effects={{op="damage",value=12},choice("headbutt",1)}},
            text="造成9点伤害。将1张弃牌放到抽牌堆顶。",upgradeText="造成12点伤害。将1张弃牌放到抽牌堆顶。"},
        {id="exhume",sourceId="Exhume",name="发掘",color="red",type="skill",rarity="rare",cost=1,exhaust=true,
            effects={choice("exhume",1)},upgrade={cost=0},
            text="将1张非发掘的消耗牌放入手牌。消耗。",upgradeText="将1张非发掘的消耗牌放入手牌。消耗。"},
    },
    defect={
        {id="hologram",sourceId="Hologram",name="全息影像",color="blue",type="skill",rarity="common",cost=1,exhaust=true,
            effects={{op="block",value=3},choice("hologram",1)},
            upgrade={exhaust=false,effects={{op="block",value=5},choice("hologram",1)}},
            text="获得3点格挡。将1张弃牌放入手牌。消耗。",upgradeText="获得5点格挡。将1张弃牌放入手牌。"},
        {id="seek",sourceId="Seek",name="搜寻",color="blue",type="skill",rarity="rare",cost=0,exhaust=true,
            effects={choice("seek",1)},upgrade={effects={choice("seek",2)}},
            text="从抽牌堆选择1张牌放入手牌。消耗。",upgradeText="从抽牌堆选择2张牌放入手牌。消耗。"},
    },
}
function M.withCards(data,classId)
    local group=assert(groups[classId],"unsupported retrieval character")
    assert(type(data)=="table" and data.cards and type(data.cards.cards)=="table","missing retrieval card data")
    local out=copy(data);local seen={}
    for index,card in ipairs(out.cards.cards) do assert(not seen[card.id],"duplicate source card");seen[card.id]=index end
    for _,card in ipairs(group) do
        local index=seen[card.id]
        if index then
            -- The opt-in helper may replace develop's two native red cards,
            -- only in its detached copy. Other registrations remain errors.
            local existing=out.cards.cards[index]
            assert(classId=="ironclad" and existing.target~=nil and existing.experimental~=true,
                "retrieval card already defined")
        end
        local definition=copy(card);definition.experimental=true
        index=index or #out.cards.cards+1
        out.cards.cards[index]=definition;seen[card.id]=index
    end
    return out
end
return M
