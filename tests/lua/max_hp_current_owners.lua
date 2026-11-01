-- Public581 owner composition; controlled injury/failure, not natural play.
local F=dofile('tests/lua/support/max_hp_relics.lua')
local H=require('abyss_relic_hooks')
local External=require('abyss_external_random')
local function references(root)
 local found,pending={}, {root}
 while #pending>0 do
  local t=table.remove(pending)
  if not found[t]then
   local values={};found[t]=values
   for k,v in next,t do
    values[k]=v
    if type(k)=='table'then pending[#pending+1]=k end
    if type(v)=='table'then pending[#pending+1]=v end
   end
  end
 end
 return function()
  for t,values in next,found do
   for k,v in next,values do F.eq(rawget(t,k),v,'original graph reference/value')end
   for k in next,t do assert(values[k]~=nil,'original graph gained key')end
  end
 end
end
local count=0
for _,id in ipairs({'strawberry','pear','mango','lees_waffle'})do
 local r=F.R.new(F.D,42);r.hp=30
 assert(F.R.obtainRelic(r,'lizard_tail'));assert(F.R.startCombat(r,'cultist_solo'))
 F.C.damage(r.combat,r.combat.enemies[1],r.combat.player,5,true)
 F.eq(r.combat.player.hp,25);F.eq(r.hp,30)
 local before=F.C.copy(r);local refs=references(r);local entropy=External.snapshot()
 local equip=H.onEquip;local reached=0
 H.onEquip=function(owner,relic,...)
  local result,why=equip(owner,relic,...)
  if relic==id then reached=reached+1;error('POST_MAX_HP_PUBLIC_OWNER')end
  return result,why
 end
 local ok,why=F.R.obtainRelic(r,id);H.onEquip=equip
 F.eq(ok,false);assert(why);F.eq(reached,1);F.same(r,before);refs();F.same(External.snapshot(),entropy)
 assert(F.R.obtainRelic(r,id))
 local gain=id=='pear'and 10 or id=='mango'and 14 or 7
 F.eq(r.maxHp,80+gain);F.eq(r.combat.player.maxHp,r.maxHp)
 F.eq(r.hp,id=='lees_waffle'and 87 or 25+gain);F.eq(r.combat.player.hp,r.hp)
 F.eq(r.relicCounters.lizard_tail,-1);F.eq(r.combat.relicCounters.lizard_tail,-1)
 F.snapshotFailure(r,function()return F.R.obtainRelic(r,id)end)
 count=count+1;print('PASS public MaxHP active owner/rollback/retry '..id)
end
F.eq(count,4);print('MAX_HP_CURRENT_OWNERS_PASS '..count..' controlled/offline only')
