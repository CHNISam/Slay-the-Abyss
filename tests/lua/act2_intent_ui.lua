local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C=H.F.Combat
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
local function detail(id,move,effects,kind)
 local host,ui,panel,_,tap=H.setup({'defend'},{id})
 local enemy=host.run.combat.enemies[1]
 if effects then enemy.intents={{id='intent_fixture',kind=kind,effects=effects}};enemy.intentIndex=1
 else
  for i,intent in ipairs(enemy.intents)do if intent.id==move then enemy.intentIndex=i end end
  assert(enemy.intents[enemy.intentIndex].id==move)
 end
 local before=C.copy(host.run.combat)
 host:refresh();tap('enemy1',1)
 same(host.run.combat,before)
 return panel:GetChild('notice').text,panel:GetChild('enemy1')
end
local heal=detail('mystic','heal')
assert(heal:find('全体',1,true) and heal:find('16',1,true) and not heal:find('未知',1,true),'Mystic group heal intent is missing')
local strength=detail('mystic','buff')
assert(strength:find('全体',1,true) and strength:find('力量',1,true) and strength:find('2',1,true),'Mystic group strength intent is missing')
local cleanse=detail('champ','anger')
assert(cleanse:find('移除',1,true) and cleanse:find('负面',1,true) and cleanse:find('6',1,true) and not cleanse:find('未知',1,true),'Champ cleanse intent is missing')
local vampire,box=detail('mystic',nil,{{op='enemyVampireDamage',value=10}},'attack')
assert(box:GetChild('intent').text=='10' and vampire:find('实际',1,true) and vampire:find('回复',1,true),'life-drain damage and healing must both be explained')
local wake=detail('lagavulin',nil,{},'stunned')
assert(wake:find('惊醒',1,true))
local stun,stunBox=detail('mystic',nil,{},'stunned')
assert(not stun:find('惊醒',1,true) and stun:find('不行动',1,true) and stunBox:GetChild('intentLabel').text=='昏眩')
print('ACT2_INTENT_UI_PASS 6')
