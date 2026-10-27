local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function card(s,upgrades)
 for _,c in ipairs(s.hand)do if c.cardId=='searing_blow'and c.upgrades==upgrades then return c end end
 error('missing actual Searing Blow+'..upgrades)
end
local function setup(options)
 options=options or {};local r=Run.new(D,42);local uids={}
 for _,c in ipairs(r.deck)do uids[#uids+1]=c.uid end
 for _,uid in ipairs(uids)do assert(Run.removeCard(r,uid))end
 assert(Run.obtainCard(r,'searing_blow',{upgrades=2}))
 if options.finisher then assert(Run.obtainCard(r,'searing_blow',{upgrades=20}))end
 if options.puzzle~=false then assert(Run.obtainRelic(r,'centennial_puzzle'))end
 if options.rod~=false then assert(Run.obtainRelic(r,'tungsten_rod'))end
 if options.fairy then assert(Run.obtainPotion(r,'fairy_in_a_bottle'))end
 -- Explicit prior-room HP boundary, not a natural route or survival claim.
 if options.hp then r.hp=options.hp end
 r.floor=D.rules.map.bossFloor;assert(Run.startCombat(r,'boss_guardian'));local s=r.combat
 local d=C.cardDefinition(s,card(s,2));eq(d.runNativeABI,true);eq(d.target,'ENEMY')
 assert(Run.play(r,card(s,2).uid,1));eq(s.enemies[1].hp,219)
 assert(Run.endTurn(r));eq(s.enemies[1].block,9)
 assert(Run.play(r,card(s,2).uid,1));assert(Run.endTurn(r));eq(s.enemies[1].statuses.sharp_hide,3)
 return r,s,card(s,options.finisher and 20 or 2)
end
return {Run=Run,C=C,D=D,eq=eq,same=same,setup=setup,card=card}
