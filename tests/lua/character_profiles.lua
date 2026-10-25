package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Characters=require("abyss_character_profiles")
local Data=require("abyss_data")
local Capability=require("abyss_card_capability")
local Combat=require("abyss_combat")
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local count=0
local function test(name,fn) fn();count=count+1;print("ok character_profiles "..count.." - "..name) end
local expected={silent={hp=70,n=12,color="green",suffix="G",count=5,relic="ring_of_the_snake"},
    defect={hp=75,n=10,color="blue",suffix="B",count=4,relic="cracked_core"},
    watcher={hp=72,n=10,color="purple",suffix="P",count=4,relic="pure_water"}}
for _,id in ipairs({"silent","defect","watcher"}) do
    local e=expected[id]
    test(id.." starter properties and independent basic IDs",function()
        local d,p=Characters.prepare(Data,id)
        eq(p.id,id);eq(p.experimental,true);eq(d.experimentalCharacter,id)
        eq(d.rules.player.maxHp,e.hp);eq(d.rules.player.energyPerTurn,3)
        eq(d.rules.player.drawPerTurn,5);eq(d.rules.player.startingGold,99)
        eq(#d.cards.starter_deck.cards,e.n);eq(#d.rules.player.startingRelics,1)
        eq(d.rules.player.startingRelics[1],e.relic)
        local catalog={};for _,c in ipairs(d.cards.cards) do assert(not catalog[c.id]);catalog[c.id]=c end
        eq(catalog["strike_"..e.color].sourceId,"Strike_"..e.suffix)
        eq(catalog["defend_"..e.color].sourceId,"Defend_"..e.suffix)
        eq(catalog["strike_"..e.color].effects[1].value,6)
        eq(catalog["strike_"..e.color].upgrade.effects[1].value,9)
        eq(catalog["defend_"..e.color].effects[1].value,5)
        eq(catalog["defend_"..e.color].upgrade.effects[1].value,8)
        for i,cardId in ipairs(d.cards.starter_deck.cards) do
            local card=assert(catalog[cardId]);assert(Capability.isImplemented(card),cardId)
            if i<=e.count then eq(cardId,"strike_"..e.color)
            elseif i<=e.count*2 then eq(cardId,"defend_"..e.color) end
        end
        assert(not catalog.strike and not catalog.defend and not catalog.bash)
        local relics={}; for _,relic in ipairs(d.relics.relics) do relics[relic.id]=relic end
        assert(relics.burning_blood,"unowned catalog prerequisite must be preserved")
        eq(#d.relics.relics,#Data.relics.relics+1)
        for _,relic in ipairs(d.relics.relics) do
            if relic.replaces then assert(relics[relic.replaces],"dangling relic prerequisite") end
        end
        for _,owned in ipairs(d.rules.player.startingRelics) do assert(owned~="burning_blood") end
    end)
    test(id.." base data and returned profile are detached",function()
        local beforeCards=#Data.cards.cards;local d,p=Characters.prepare(Data,id)
        d.rules.player.maxHp=1;d.cards.starter_deck.cards[1]="invalid";p.starterDeck[1]="another"
        eq(Data.rules.player.maxHp,80);eq(Data.rules.player.startingRelics[1],"burning_blood")
        eq(#Data.cards.cards,beforeCards);eq(Data.characterId,nil);eq(Data.experimentalCharacter,nil)
        local fresh,profile=Characters.prepare(Data,id)
        eq(fresh.rules.player.maxHp,e.hp);eq(profile.starterDeck[1],"strike_"..e.color)
        assert(not pcall(Characters.prepare,fresh,id))
    end)
    test(id.." class filtering prevents red pool contamination",function()
        local d=Characters.prepare(Data,id)
        for _,c in ipairs(d.cards.cards) do
            if c.type~="status" and c.type~="curse" and c.rarity~="special" then eq(c.color,e.color) end
            assert(c.id~="barricade" and c.id~="anger" and c.id~="offering")
        end
        local s=Combat.new(d,{seed=42,enemies={"cultist"},enableStances=id=="watcher"})
        eq(s.player.maxHp,e.hp);eq(s.player.hp,e.hp)
        eq(#s.hand+#s.draw,e.n)
    end)
end
test("Neutralize source basic and upgraded Weak follow damage",function()
    local d=Characters.prepare(Data,"silent")
    for _,up in ipairs({false,true}) do
        local s=Combat.new(d,{seed=42,enemies={"cultist"},deck={{cardId="neutralize",upgraded=up}}})
        s.enemies[1].hp=100; local before=s.energy
        assert(Combat.play(s,s.hand[1].uid,1));eq(s.energy,before)
        eq(s.enemies[1].hp,up and 96 or 97);eq(s.enemies[1].statuses.weak,up and 2 or 1)
    end
end)
test("Miracle is special retained exhausted zero-cost energy",function()
    local d=Characters.prepare(Data,"watcher")
    for _,up in ipairs({false,true}) do
        local s=Combat.new(d,{seed=42,enemies={"cultist"},enableStances=true,deck={{cardId="miracle",upgraded=up}}})
        local card=Combat.cardDefinition(s,s.hand[1]);local uid=s.hand[1].uid
        eq(card.color,"colorless");eq(card.rarity,"special");eq(card.cost,0)
        eq(card.selfRetain,true);eq(card.exhaust,true);assert(not card.ethereal)
        assert(Combat.endTurn(s));eq(s.hand[1].uid,uid)
        local before=s.energy;assert(Combat.play(s,uid));eq(s.energy,before+(up and 2 or 1))
        eq(s.exhaust[1].uid,uid)
    end
end)
test("unknown class and malformed source rejected",function()
    for _,id in ipairs({"Watcher","invalid",3,false}) do assert(not pcall(Characters.prepare,Data,id)) end
    assert(not pcall(Characters.prepare,{},"silent"))
end)
print("CHARACTER_PROFILES_PASS "..count)
