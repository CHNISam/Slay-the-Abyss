package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local Data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function start(character,id)
 local r=Run.new(Data,42,{character=character,experimental=true})
 assert(Run.obtainRelic(r,'Chemical X'))
 r.deck={{uid=31,cardId=id,upgraded=false}};r.nextDeckUid=32
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.energy=0
 for _,card in ipairs(s.hand)do if card.cardId==id then return r,s,card end end
 error('X card missing '..id)
end
local function play(r,s,c)assert(c);local ok,why=Run.play(r,c.uid,1);assert(ok,why);assert(s.energy==0,'Chemical X energy '..tostring(s.energy))end
test('Whirlwind at zero energy repeats twice and pays zero',function()
 local r,s,c=start('ironclad','whirlwind');play(r,s,c);assert(s.enemies[1].hp==990)
end)
test('Skewer at zero energy repeats twice',function()
 local r,s,c=start('silent','skewer');play(r,s,c);assert(s.enemies[1].hp==986)
end)
test('Malaise at zero energy applies two weakness and negative strength',function()
 local r,s,c=start('silent','malaise');play(r,s,c);assert(s.enemies[1].statuses.strength==-2 and s.enemies[1].statuses.weak==2)
end)
test('Doppelganger adds exactly two once',function()
 local r,s,c=start('silent','doppelganger');play(r,s,c);assert(s.player.statuses.energized==2 and s.player.statuses.draw_next_turn==2)
end)
test('Tempest zero energy channels two extra lightning',function()
 local r,s,c=start('defect','tempest');local before=s.orbChannelCounts.lightning or 0;play(r,s,c);assert(s.orbChannelCounts.lightning==before+2)
end)
test('Multi Cast zero energy evokes twice',function()
 local r,s,c=start('defect','multi_cast');play(r,s,c);assert(s.enemies[1].hp==984)
end)
test('Reinforced Body zero energy grants two blocks',function()
 local r,s,c=start('defect','reinforced_body');play(r,s,c);assert(s.player.block==14)
end)
test('Collect zero energy grants two Collect',function()
 local r,s,c=start('watcher','collect');play(r,s,c);assert(s.player.statuses.collect==2)
end)
test('Conjure Blade adds exactly two once',function()
 local r,s,c=start('watcher','conjure_blade');play(r,s,c)
 local found=false;for _,v in ipairs(s.draw)do if v.cardId=='expunger'then assert(v.expungerHits==2);found=true end end;assert(found)
end)
test('Transmutation adds exactly two once',function()
 local r,s,c=start('ironclad','transmutation');play(r,s,c);assert(#s.hand==2)
end)
test('free autoplay Whirlwind keeps all energy while gaining two repetitions',function()
 local _,s,c=start('ironclad','whirlwind');s.energy=3;for i,v in ipairs(s.hand)do if v==c then table.remove(s.hand,i);break end end
 C.queueCard(s,c,{targetIndex=1,energyOnUse=3,exhaustCards=false});require('abyss_card_actions').drain(C,s)
 assert(s.energy==3 and s.enemies[1].hp==975)
end)
test('free autoplay Reinforced Body keeps energy and grants five blocks',function()
 local _,s,c=start('defect','reinforced_body');s.energy=3;for i,v in ipairs(s.hand)do if v==c then table.remove(s.hand,i);break end end
 C.queueCard(s,c,{targetIndex=1,energyOnUse=3,exhaustCards=false});require('abyss_card_actions').drain(C,s)
 assert(s.energy==3 and s.player.block==35)
end)
print('LUA_CHEMICAL_X_PASS '..n)
