package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,D,V,H,P,E=require('abyss_combat'),require('abyss_data'),require('abyss_battle_intent_view'),require('abyss_corrupt_heart'),require('abyss_spire_pair'),require('abyss_events')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS ending intent '..count..' '..name)end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function fresh(ids)
 local data=C.copy(D);data.rules.player.drawPerTurn=0
 return assert(C.new(data,{seed=42,enemies=ids,deck={}}))
end
local function choose(enemy,id)
 for i,intent in ipairs(enemy.intents)do if intent.id==id then enemy.intentIndex=i;return end end;error(id)
end
local function text(view,expected)assert(view.text:find(expected,1,true),expected..' absent from '..view.text)end
test('pair secondary actions use existing detail rows and mixed badges',function()
 local s=fresh({'spire_shield','spire_spear'});local shield,spear=s.enemies[1],s.enemies[2]
 choose(shield,'fortify');local v=V.intentView(s,1);text(v,'全体');text(v,'30');eq(#v.rows,1)
 choose(spear,'piercer');v=V.intentView(s,2);text(v,'全体');text(v,'2');text(v,'力量')
 choose(shield,'bash');v=V.intentView(s,1);eq(v.badge,'debuff');text(v,'力量');text(v,'1')
 s.orbs={slots=3,focus=0,balls={}};v=V.intentView(s,1);text(v,'集中');text(v,'随机')
end)
test('Smash block uses actual frozen output instead of intent rounding',function()
 local s=fresh({'spire_shield','spire_spear'});local e=s.enemies[1];choose(e,'smash')
 e.statuses.weak=1;e.statuses.strength=1;s.player.statuses.vulnerable=1
 local expected=P.actualDamage(s,e,C.attackAmount(s,e,s.player,34))
 local shown=C.intentAttackAmount(s,e,s.player,34);assert(shown~=expected)
 local v=V.intentView(s,1);eq(v.value,tostring(shown));text(v,'格挡');text(v,tostring(expected));eq(v.badge,'defend')
 local actions=P.takeTurn(s,e,function()error('Smash must not draw a boolean')end,function(state,enemy,base)return C.attackAmount(state,enemy,state.player,base)end)
 eq(actions[#actions-1].value,expected)
 e.statuses.strength=20;v=V.intentView(s,1);text(v,'获得 '..expected..' 点格挡')
 local frame=E.frame(s);frame.catalog=s.catalog;frame.rules=s.rules
 text(V.intentView(frame,1),'获得 '..expected..' 点格挡')
end)
test('Heart Debilitate names all five cards and their draw-pile destination',function()
 local s=fresh({'corrupt_heart'});local v=V.intentView(s,1)
 for _,id in ipairs({'dazed','slimed','wound','burn','void'})do text(v,s.catalog.cards[id].name)end
 text(v,'抽牌堆');text(v,'随机');eq(#v.rows,8)
end)
test('Heart buff stages and queued immutable plan share actual source values',function()
 local s=fresh({'corrupt_heart'});local e=s.enemies[1];choose(e,'buff')
 for stage,extra in ipairs({{'artifact',2},{'beat_of_death',1},{'painful_stabs',-1},{'strength',10},{'strength',50},{'strength',50}})do
  e.heartBuffCount=stage-1;e.heartBuffPlan=nil;e.statuses.strength=-3
  local v=V.intentView(s,1);eq(#v.rows,2);text(v,'5');text(v,s.catalog.statuses[extra[1]].name)
  if extra[1]=='painful_stabs'then assert(not v.text:find('失去',1,true));eq(v.rows[2].icon,'buff')end
  local plans=H.actions(s,e,e.intents[e.intentIndex]);eq(plans[1].value,5);eq(plans[2].value,extra[2]);eq(e.heartBuffCount,stage)
  local frame=E.frame(s);frame.catalog=s.catalog;frame.rules=s.rules
  e.statuses.strength=99;text(V.intentView(s,1),'5');same(V.intentView(frame,1),v)
 end
end)
test('repeated full previews leave state/RNG/counter and captured old frames unchanged',function()
 for _,ids in ipairs({{'spire_shield','spire_spear'},{'corrupt_heart'}})do
  local s=fresh(ids);local before=C.copy(s)
  for _=1,3 do for i in ipairs(s.enemies)do V.intentView(s,i)end end
  same(s,before)
 end
 local s=fresh({'corrupt_heart'});local e=s.enemies[1];choose(e,'buff');H.actions(s,e,e.intents[e.intentIndex])
 local frame=E.frame(s);frame.catalog=s.catalog;frame.rules=s.rules;local view=V.intentView(frame,1)
 H.advance(s,e,function()return 0 end);same(V.intentView(frame,1),view)
end)
print('ENDING_INTENT_VIEW_PASS '..count..' controlled offline source projection; no live UI claim')
