local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local N=require('abyss_relic_names');local D=H.F.Data;local count=0
local function same(a,b,seen)
 if a==b then return end;assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 seen=seen or {};if seen[a]then assert(seen[a]==b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local ids={}
for _,catalog in ipairs({D.relicSource,D.classRelicSources.silent,D.classRelicSources.defect,D.classRelicSources.watcher})do
 for _,pool in pairs(catalog.queues)do for _,id in ipairs(pool)do ids[id]=true end end
end
local before=H.F.Combat.copy(D)
for id in pairs(ids)do
 local known,missing=N.get(D,id),N.get(nil,id)
 assert(known~='未知遗物','unmapped catalog relic '..id)
 assert(known~='' and known:find('[\228-\233]') and not known:find('[A-Za-z]'),'non-Chinese source '..id)
 assert(known==missing,'known and unavailable identities must retain the same display name '..id)
 count=count+1
end
assert(count==156);same(before,D)
assert(N.get(nil,'SacredBark')=='神圣树皮' and N.get(D,'Darkstone Periapt')=='黑石护符')
assert(N.get(D,'darkstone_periapt')=='黑石护符' and N.get(nil,'???')=='未知遗物' and N.get(D,nil)=='未知遗物')
local h,u,p=H.setup({'defend'})
for _,e in ipairs(h.run.combat.enemies)do e.hp=0 end
assert(H.Run.finishCombat(h.run))
h.run.rewards.relics={{sourceId='SacredBark',id='SacredBark',unavailable=true}}
local runBefore=H.F.Combat.copy(h.run);local pool=h.run.relicPool
h:refresh()
local box=p:GetChild('potionHelp'):GetChild('relicReward1')
assert(box:GetChild('normal'):GetChild('label').text=='神圣树皮 · 尚不可领取')
assert(not box.interactable);same(runBefore,h.run);assert(h.run.relicPool==pool)
print('RELIC_CHINESE_NAMES_PASS 156')
