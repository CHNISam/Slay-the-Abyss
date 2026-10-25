-- Explicit opt-in fixtures for six source-verified Watcher foundation cards.
-- Does not change any production pool, starter deck, presentation or class.
local M={}
local function copy(x)
    if type(x)~="table" then return x end
    local y={}; for k,v in pairs(x) do y[k]=copy(v) end; return y
end
local function stance(id) return {op="changeStance",stance=id} end
local cards={
    {id="eruption",name="Eruption",sts_name="Eruption",color="purple",type="attack",rarity="basic",cost=2,
        effects={{op="damage",value=9},stance("Wrath")},upgrade={cost=1}},
    {id="vigilance",name="Vigilance",sts_name="Vigilance",color="purple",type="skill",rarity="basic",cost=2,
        effects={{op="block",value=8},stance("Calm")},upgrade={effects={{op="block",value=12},stance("Calm")}}},
    {id="empty_fist",name="Empty Fist",sts_name="Empty Fist",color="purple",type="attack",rarity="common",cost=1,
        effects={{op="damage",value=9},stance("Neutral")},upgrade={effects={{op="damage",value=14},stance("Neutral")}}},
    {id="empty_body",name="Empty Body",sts_name="Empty Body",color="purple",type="skill",rarity="common",cost=1,
        effects={{op="block",value=7},stance("Neutral")},upgrade={effects={{op="block",value=10},stance("Neutral")}}},
    {id="crescendo",name="Crescendo",sts_name="Crescendo",color="purple",type="skill",rarity="common",cost=1,
        selfRetain=true,exhaust=true,effects={stance("Wrath")},upgrade={cost=0}},
    {id="tranquility",name="Tranquility",sts_name="Tranquility",color="purple",type="skill",rarity="common",cost=1,
        selfRetain=true,exhaust=true,effects={stance("Calm")},upgrade={cost=0}},
    -- aeubanks/sts@319009d5: Rushdown / MentalFortress / InnerPeace.
    {id="rushdown",name="Rushdown",sts_name="Rushdown",color="purple",type="power",rarity="uncommon",cost=1,
        effects={{op="gainStancePower",status="rushdown",value=2}},upgrade={cost=0}},
    {id="mental_fortress",name="Mental Fortress",sts_name="Mental Fortress",color="purple",type="power",rarity="uncommon",cost=1,
        effects={{op="gainStancePower",status="mental_fortress",value=4}},
        upgrade={effects={{op="gainStancePower",status="mental_fortress",value=6}}}},
    {id="inner_peace",name="Inner Peace",sts_name="Inner Peace",color="purple",type="skill",rarity="uncommon",cost=1,
        effects={{op="innerPeace",value=3}},upgrade={effects={{op="innerPeace",value=4}}}},
    {id="cut_through_fate",name="Cut Through Fate",sts_name="Cut Through Fate",color="purple",type="attack",rarity="common",cost=1,
        effects={{op="damage",value=7},{op="scry",value=2},{op="draw",value=1}},
        upgrade={effects={{op="damage",value=9},{op="scry",value=3},{op="draw",value=1}}}},
    {id="third_eye",name="Third Eye",sts_name="Third Eye",color="purple",type="skill",rarity="common",cost=1,
        effects={{op="block",value=7},{op="scry",value=3}},
        upgrade={effects={{op="block",value=9},{op="scry",value=5}}}},
    {id="just_lucky",name="Just Lucky",sts_name="Just Lucky",color="purple",type="attack",rarity="common",cost=0,
        effects={{op="scry",value=1},{op="block",value=2},{op="damage",value=3}},
        upgrade={effects={{op="scry",value=2},{op="block",value=3},{op="damage",value=4}}}},
    {id="nirvana",name="Nirvana",sts_name="Nirvana",color="purple",type="power",rarity="uncommon",cost=1,
        effects={{op="gainStatus",status="nirvana",value=3}},
        upgrade={effects={{op="gainStatus",status="nirvana",value=4}}}},
}
function M.withFoundationCards(data)
    assert(type(data)=="table" and type(data.cards)=="table" and type(data.cards.cards)=="table", "missing card data")
    local result=copy(data)
    local ids={}
    for _,c in ipairs(result.cards.cards) do assert(not ids[c.id],"duplicate input card"); ids[c.id]=true end
    for _,c in ipairs(cards) do
        assert(not ids[c.id],"Watcher foundation card already exists: "..c.id)
        result.cards.cards[#result.cards.cards+1]=copy(c)
    end
    assert(result.statuses and type(result.statuses.statuses)=="table","missing status definitions")
    local present={}
    for _,s in ipairs(result.statuses.statuses) do present[s.id]=true end
    for _,id in ipairs({"rushdown","mental_fortress"}) do
        assert(not present[id],"Watcher stance power already defined: "..id)
        result.statuses.statuses[#result.statuses.statuses+1]={id=id,name=id=="rushdown" and "猛虎下山" or "心灵堡垒",kind="buff",stack="intensity",decay="none",
            description=id=="rushdown" and "进入愤怒时，抽取等同层数的牌。" or "改变姿态时，获得等同层数的固定格挡。"}
    end
    assert(not present.nirvana,"Watcher scry power already defined: nirvana")
    result.statuses.statuses[#result.statuses.statuses+1]={id="nirvana",name="涅槃",kind="buff",stack="intensity",decay="none",
        description="每次占卜后，获得等同层数的固定格挡。"}
    return require("abyss_mantra").withCards(result)
end
return M
