local F=dofile('tests/lua/support/max_hp_relics.lua');local H=require('abyss_relic_hooks')
local count,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
test('late nested failure rolls HP, maximum, battle, queues, public owners and external entropy back',function()
 local External=require('abyss_external_random');local original=H.onEquip
 for _,id in ipairs({'strawberry','pear','mango','lees_waffle'})do
  local r=F.R.new(F.D,42);r.hp=20;assert(F.R.startCombat(r,'cultist_solo'))
  local beforeEntropy=External.snapshot();local reached=false
  H.onEquip=function(staged,relic,...)
   original(staged,relic,...);reached=true;assert(staged.maxHp>80);error('POST_MAX_HP_ON_EQUIP')
  end
  local called,why=pcall(function()F.snapshotFailure(r,function()return F.R.obtainRelic(r,id)end)end)
  H.onEquip=original;assert(called,tostring(why));assert(reached);F.same(External.snapshot(),beforeEntropy)
 end
end)
assert(failed==0,tostring(failed)..' max HP health groups failed');print('MAX_HP_RELICS_HEALTH_ROLLBACK_PASS '..count)
