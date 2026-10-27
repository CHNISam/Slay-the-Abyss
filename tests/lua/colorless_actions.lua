package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function new(id,up)
    local s=C.new(data,{deck={},enemies={'jaw_worm','jaw_worm'},seed=7,shuffleSeed='7'})
    for _,enemy in ipairs(s.enemies)do enemy.hp=1000;enemy.maxHp=1000;enemy.block=0 end
    s.energy=5;s.hand={{cardId=id,uid=1,upgraded=up==true}};s.nextUid=10
    return s
end
local function add(s,id,uid,pile)s[pile or 'hand'][#s[pile or 'hand']+1]={cardId=id,uid=uid,upgraded=false}end
local s=new('apotheosis');for i,pile in ipairs({'hand','draw','discard','exhaust'})do add(s,'strike',i+1,pile)end
assert(C.play(s,1));for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do if c.cardId~='apotheosis'then assert(c.upgraded)end end end
s=new('dark_shackles');assert(C.play(s,1,1));eq(s.enemies[1].statuses.strength,-9);eq(s.enemies[1].statuses.shackled,9)
s=new('enlightenment',true);add(s,'bludgeon',2);assert(C.play(s,1));eq(C.cardDefinition(s,s.hand[1]).cost,1);eq(C.combatBaseCost(s,s.hand[1]),1)
s=new('madness');add(s,'strike',2);add(s,'defend',3);assert(C.play(s,1));local zero=0;for _,c in ipairs(s.hand)do if C.combatBaseCost(s,c)==0 then zero=zero+1 end end;eq(zero,1)
s=new('jack_of_all_trades',true);assert(C.play(s,1));eq(#s.hand,2);for _,c in ipairs(s.hand)do assert(c.cardId~='bandage_up');eq(s.catalog.cards[c.cardId].color,'colorless')end
s=new('chrysalis',true);assert(C.play(s,1));eq(#s.draw,5);for _,c in ipairs(s.draw)do eq(s.catalog.cards[c.cardId].type,'skill');eq(C.combatBaseCost(s,c),0)end
s=new('transmutation',true);assert(C.play(s,1));eq(s.energy,0);eq(#s.hand,5);for _,c in ipairs(s.hand)do assert(c.upgraded);eq(C.cardDefinition(s,c).cost,0)end
s=new('purity');for i=2,6 do add(s,'defend',i)end;assert(C.play(s,1));assert(s.pendingChoice);local token=s.pendingChoice.token
assert(C.chooseCard(s,token,2));assert(not C.chooseCard(s,token,3));assert(C.chooseCard(s,s.pendingChoice.token,3));assert(C.chooseCard(s,s.pendingChoice.token,4))
assert(not C.chooseCard(s,s.pendingChoice.token,5));assert(C.chooseCard(s,s.pendingChoice.token,0));eq(#s.hand,2);eq(#s.exhaust,4)
s=new('secret_weapon');add(s,'strike',2,'draw');add(s,'anger',3,'draw');add(s,'defend',4,'draw');assert(C.play(s,1));assert(s.pendingChoice);assert(C.chooseCard(s,s.pendingChoice.token,3));eq(s.hand[1].cardId,'anger');eq(#s.draw,2)
s=new('forethought',true);add(s,'bludgeon',2);add(s,'defend',3);assert(C.play(s,1));assert(C.chooseCard(s,s.pendingChoice.token,2));assert(C.chooseCard(s,s.pendingChoice.token,0));eq(s.draw[1].cardId,'bludgeon');assert(s.draw[1].freeToPlayOnce)
print('ok colorless cost changes, generation, and UID choices')
