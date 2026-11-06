local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
dofile('tests/lua/relic_query_contract.lua')
local H,B,U,Rare,Shop=F.hooks,F.boss,F.uncommon,F.rare,F.shop
local s=F.C.new(F.D,{seed=42,deck={'strike','defend'},enemies={'cultist'}});H.bindBattle(s,{'philosophers_stone','centennial_puzzle'})
local root=F.root(s)
for _,namespace in ipairs({'hooks','uncommon','rare','boss','shop'})do
 local module=F[namespace]
 for _,key in ipairs(F.publicMethods[namespace])do F.case(namespace..'.'..key..' nil/function restore',function()
  local original=assert(module[key]);F.eq(type(original),'function','public function exists');root.functionSnapshot=original
  local replacement=function(value)return value end;root.replacement=replacement
  module[key]=replacement;F.eq(rawequal(module[key],replacement),true,'ordinary replacement function identity')
  F.eq(module[key](root),root,'ordinary replacement receives real caller argument')
  F.snapshot('ordinary replacement '..namespace..'.'..key,root)
  module[key]=nil;F.eq(module[key],nil,'ordinary nil method read');F.snapshot('ordinary nil '..namespace..'.'..key,root)
  module[key]=original;F.eq(rawequal(module[key],root.functionSnapshot),true,'same function after nil restore')
 end)end
end
local spawn=B.onSpawnMonster;local calls=0
B.onSpawnMonster=function(state,enemy)calls=calls+1;F.eq(state,s);return spawn(state,enemy)end
F.call(root,'Boss battleStart reads replacement onSpawnMonster',B.battleStart,s,'philosophers_stone')
B.onSpawnMonster=spawn;F.eq(calls,#s.enemies,'same namespace dynamic method')
local original=H.hpChanged;local sentinel={kind='dynamic-hp-error'};root.sentinel=sentinel
H.hpChanged=function(state,...)if state==s then error(sentinel,0)end;return original(state,...)end
local ok,why=F.call(root,'Actor reads replaced HP callback with same table error',F.A.damage,s,s.enemies[1],s.player,1,true)
H.hpChanged=original;F.eq(ok,false);F.eq(why,sentinel,'same dynamic error object')
local r=F.R.new(F.D,42);local loss=require('abyss_relic_loss');local old=loss.lose;local normalize,unequip=H.localId,H.onUnequip
root=F.root(r);root.normalize=normalize;root.unequip=unequip
loss.lose=function(owner,id,api)
 F.eq(rawequal(api.localId,normalize),true,'existing Run normalization snapshot')
 F.eq(rawequal(api.onUnequip,unequip),true,'existing Run callback snapshot')
 H.onUnequip=function()error('late replacement must not change captured callback',0)end
 F.eq(rawequal(api.onUnequip,unequip),true,'captured callback remains original')
 F.snapshot('actual Run adapter function snapshots',{owner=owner,args={id,api},anchors=root})
 return true,'snapshot_preserved'
end
F.call(root,'real Run command retains function-value adapter',F.R.loseRelic,r,'probe')
loss.lose,H.onUnequip=old,unequip
F.finish('dynamic')
