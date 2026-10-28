package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,I=require('abyss_combat'),require('abyss_inventory')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function battle(ids,counters,deck,enemies)
 local q=assert(I.opening(data.relics.relics,ids,counters))
 local s=assert(C.new(data,{seed=42,deck=deck or {'strike','strike','defend'},enemies=enemies or {'cultist'},
 beforeOpeningDraw=function(s)return I.applyOpening(s,q.beforeDraw)end}))
 assert(I.applyOpening(s,q.afterDraw))
 for _,e in ipairs(s.enemies)do e.hp=300;e.maxHp=300 end
 return s
end
local function play(s,id,target)
 for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid,target or 1));return end end;error('missing '..id)
end
test('Boot raises post-block NORMAL player damage from one through four to five only',function()
 local s=battle({'boot'});local e=s.enemies[1];e.block=5;play(s,'strike');assert(e.hp==295 and e.block==0)
 e.block=6;play(s,'strike');assert(e.hp==295 and e.block==0)
 C.damage(s,s.player,e,1,true);assert(e.hp==294,'fixed potion damage incorrectly raised')
end)
test('Akabeko vigor applies eight to each hit of first attack, consumed only by attacks',function()
 local s=battle({'akabeko'},nil,{'defend','twin_strike','strike'});local e=s.enemies[1]
 play(s,'defend');assert(s.player.statuses.vigor==8)
 play(s,'twin_strike');assert(e.hp==274 and (s.player.statuses.vigor or 0)==0)
 s.energy=3;play(s,'strike');assert(e.hp==268)
end)
test('PenNib doubles tenth attack and preserves source priority with Vigor Weak and Vulnerable',function()
 local s=battle({'akabeko','pen_nib'},{pen_nib=9});local e=s.enemies[1]
 C.addStatus(s.player,'strength',1);C.addStatus(s.player,'weak',1);C.addStatus(e,'vulnerable',1)
 assert(C.attackAmount(s,s.player,e,6)==33)
 play(s,'strike');assert(e.hp==267 and s.relicCounters.pen_nib==0)
 assert((s.player.statuses.pen_nib or 0)==0 and (s.player.statuses.vigor or 0)==0)
end)
test('ninth attack enables PenNib for next card instead of doubling itself',function()
 local s=battle({'pen_nib'},{pen_nib=8});local e=s.enemies[1]
 play(s,'strike');assert(e.hp==294 and s.player.statuses.pen_nib==1)
 play(s,'strike');assert(e.hp==282 and s.relicCounters.pen_nib==0 and s.player.statuses.pen_nib==0)
end)
test('Nunchaku tenth attack grants one energy after resolution; counter persists and skills do not count',function()
 local s=battle({'nunchaku'},{nunchaku=9});play(s,'defend');assert(s.relicCounters.nunchaku==9)
 local before=s.energy;play(s,'strike');assert(s.energy==before and s.relicCounters.nunchaku==0)
end)
test('failed attack restores counts powers and temporary attack hook state',function()
 local s=battle({'pen_nib','nunchaku','akabeko'},{pen_nib=9,nunchaku=9});local old=C.damage
 C.damage=function()error('AFTER_RELIC_COUNTERS')end
 local uid=s.hand[1].uid;local ok=pcall(C.play,s,uid,1);C.damage=old
 assert(not ok and s.relicCounters.pen_nib==9 and s.relicCounters.nunchaku==9)
 assert(s.player.statuses.vigor==8 and s.player.statuses.pen_nib==1)
end)
print('LUA_COMMON_RELIC_ATTACKS_PASS '..n)
