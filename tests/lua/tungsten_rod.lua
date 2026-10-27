package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A=require('abyss_run'),require('abyss_combat'),require('abyss_actor')
local Data=require('abyss_data')
local passed,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
test('real definition resolves the exact Rare source identity and public obtain',function()
 local r=Run.new(Data,42);local ok,id=Run.obtainRelic(r,'TungstenRod');assert(ok,id);eq(id,'tungsten_rod')
 local definition;for _,v in ipairs(r.data.relics.relics)do if v.id==id then definition=v end end
 eq(definition.sourceId,'TungstenRod');eq(definition.rarity,'rare');assert(definition.description:find('1',1,true))
end)
-- Effect tests use actual permanent obtain and real battle binding. Normal
-- treasure and the unchanged complete source Rare queue are checked separately.
for _,kind in ipairs({'NORMAL','THORNS','HP_LOSS'})do
 test(kind..' positive one is reduced to zero and zero stays zero',function()
  local r=Run.new(Data,42);assert(Run.obtainRelic(r,'TungstenRod'));assert(Run.startCombat(r,'cultist_solo'))
  local s=r.combat;local hp=s.player.hp
  local function hit(n)if kind=='NORMAL'then return A.damage(s,s.enemies[1],s.player,n,false)
   elseif kind=='THORNS'then return A.retaliate(s,s.enemies[1],s.player,n)
   else return A.loseHp(s,s.player,n)end end
  eq(hit(1),0);eq(s.player.hp,hp);eq(hit(0),0);eq(s.player.hp,hp)
  eq(hit(3),2);eq(s.player.hp,hp-2)
 end)
end
test('outside HP_LOSS and null-owner NORMAL share the same final relic reduction',function()
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'TungstenRod'));r.phase='node';local hp=r.hp
 local ok,lost=Run.eventDamage(r,3);assert(ok,lost);eq(lost,2);eq(r.hp,hp-2)
 ok,lost=Run.eventNormalDamage(r,3);assert(ok,lost);eq(lost,2);eq(r.hp,hp-4)
end)
print('TUNGSTEN_ROD '..passed..' passed; '..failed..' failed');assert(failed==0)
