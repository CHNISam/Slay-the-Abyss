package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=require('abyss_relic_hooks')
local C,I,R=require('abyss_combat'),require('abyss_inventory'),require('abyss_run')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function run(ids)return {relics=ids,relicCounters={},gold=0,hp=30,maxHp=80,potionSlots=3,potions={}}end
test('Omamori prevents two curses without card-obtain gold, third obtains normally',function()
 local r=run({'omamori','ceramic_fish'});H.onEquip(r,'omamori')
 for _=1,2 do assert(not H.beforeObtainCard(r,{type='curse'}));assert(r.gold==0)end
 assert(r.relicCounters.omamori==0);assert(H.beforeObtainCard(r,{type='curse'}));H.onObtainCard(r,{type='curse'});assert(r.gold==9)
 assert(H.beforeObtainCard(r,{type='attack'}));H.onObtainCard(r,{type='attack'});assert(r.gold==18)
end)
test('CeramicFish gainGold respects Ectoplasm',function()
 local r=run({'ceramic_fish','ectoplasm'});H.onObtainCard(r,{type='attack'});assert(r.gold==0)
end)
test('PotionBelt increases physical capacity by two only on equip and preserves holes',function()
 local r=run({'potion_belt'});r.potions[3]='fire_potion';H.onEquip(r,'potion_belt');assert(r.potionSlots==5 and r.potions[3]=='fire_potion' and not r.potions[2])
end)
test('MealTicket only heals entering shop; MawBank awards each entered room then shop spend disables permanently',function()
 local r=run({'meal_ticket','maw_bank'});H.onEquip(r,'maw_bank')
 H.onEnterRoom(r,'combat');assert(r.gold==12 and r.hp==30)
 H.onEnterRoom(r,'shop');assert(r.gold==24 and r.hp==45)
 H.onSpendGold(r,'event');H.onEnterRoom(r,'event');assert(r.gold==36)
 H.onSpendGold(r,'shop');H.onEnterRoom(r,'shop');assert(r.gold==36 and r.hp==60)
 H.onEnterRoom(r,'combat');assert(r.gold==36 and r.relicCounters.maw_bank==-2)
end)
test('MealTicket clamps healing; source IDs and project IDs both dispatch',function()
 local r=run({'MealTicket','MawBank'});r.hp=79;H.onEnterRoom(r,'shop');assert(r.hp==80 and r.gold==12)
end)
test('BloodVial TOP healing and BagOfMarbles BOTTOM status use actual opening API',function()
 local r=R.new(data,42);r.hp=30;r.relics={'blood_vial','bag_of_marbles'}
 assert(R.startCombat(r,'louse_pair'));assert(r.combat.player.hp==32)
 for _,e in ipairs(r.combat.enemies)do assert(e.statuses.vulnerable==1)end
 assert(r.combat.relics[1]=='blood_vial')
end)
test('BagOfMarbles respects Artifact and ignores dead actors',function()
 local r=R.new(data,42);assert(R.startCombat(r,'cultist_solo'));local s=r.combat;local e=s.enemies[1]
 C.addStatus(e,'artifact',1);H.battleStart(s,'bag_of_marbles');assert(e.statuses.artifact==0 and not e.statuses.vulnerable)
 e.hp=0;H.battleStart(s,'bag_of_marbles');assert(not e.statuses.vulnerable)
end)
test('Orichalcum fixed six ignores Dexterity/Frail; existing block suppresses',function()
 local r=R.new(data,42);r.relics={'orichalcum'};assert(R.startCombat(r,'cultist_solo'));local s=r.combat
 C.addStatus(s.player,'dexterity',50);C.addStatus(s.player,'frail',2)
 H.onPlayerEndTurn(s);assert(s.player.block==6)
 s.player.block=1;H.onPlayerEndTurn(s);assert(s.player.block==1)
end)
test('Combat.endTurn actually dispatches Orichalcum before enemy turn',function()
 local r=R.new(data,42);r.relics={'orichalcum'};assert(R.startCombat(r,'cultist_solo'))
 local s=r.combat;local before=#s.events;assert(R.endTurn(r));local blockAt,enemyAt
 for i=before+1,#s.events do
  if s.events[i].kind=='block' and s.events[i].detail.amount==6 then blockAt=i end
  if s.events[i].kind=='enemy_turn' then enemyAt=i end
 end
 assert(blockAt and enemyAt and blockAt<enemyAt)
end)
print('LUA_COMMON_RELIC_HOOKS_PASS '..n)
