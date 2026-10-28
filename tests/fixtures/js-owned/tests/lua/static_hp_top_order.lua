-- Fixed-source onAttacked TOP Channel precedes later wasHPLost TOP Draw in
-- construction, so Draw executes first. Controlled Powers/HP isolate callbacks.
local Run,C,D,A,O,Q,R=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_actor'),require('abyss_orbs'),require('abyss_card_actions'),require('abyss_sts_random')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function setup(options)
 options=options or {};local r=Run.new(D,'42',{experimental=true,character='defect'})
 if options.puzzle~=false then assert(Run.obtainRelic(r,'centennial_puzzle'))end
 if options.rod then assert(Run.obtainRelic(r,'tungsten_rod'))end
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat
 if options.thornsFirst then A.applyPower(s,s.player,'thorns',1,s.player)end
 if options.static~=false then A.applyPower(s,s.player,'static_discharge',options.amount or 1,s.player)end
 if options.thornsLast then A.applyPower(s,s.player,'thorns',1,s.player)end
 while #s.orbs.balls<3 do O.channel(s,'lightning',C)end
 s.enemies[1].hp=options.enemyHp or 1000;s.enemies[1].block=0
 return r,s,s.enemies[1]
end
local function trace(s,fn)
 local out={};local draw,channel,retaliate,block=C.draw,O.channel,C.retaliate,C.block
 C.draw=function(state,n,...)if state==s then out[#out+1]='D'..n end;return draw(state,n,...)end
 O.channel=function(state,kind,...)if state==s then out[#out+1]='C'end;return channel(state,kind,...)end
 C.retaliate=function(state,source,...)if state==s and source==s.player then out[#out+1]='T'end;return retaliate(state,source,...)end
 C.block=function(state,owner,n,...)if state==s and owner==s.player and n==2 then out[#out+1]='B'end;return block(state,owner,n,...)end
 local ok,why=pcall(fn);C.draw,O.channel,C.retaliate,C.block=draw,channel,retaliate,block;assert(ok,why)
 return table.concat(out,',')
end
test('standalone real damage draws Puzzle before Static can kill the last monster',function()
 local _,s,e=setup({enemyHp=8});local hand=#s.hand
 eq(trace(s,function()C.damage(s,e,s.player,1)end),'D3,C')
 eq(#s.hand,hand+3);eq(C.outcome(s),'victory');eq(s.relicCombat.centennialUsed,true)
end)
test('Puzzle precedes lethal Thorns with no Static Discharge Power',function()
 local _,s,e=setup({static=false,thornsFirst=true,enemyHp=1});local hand=#s.hand
 eq(trace(s,function()C.damage(s,e,s.player,1)end),'D3,T')
 eq(#s.hand,hand+3);eq(C.outcome(s),'victory');eq(s.relicCombat.centennialUsed,true)
end)
test('existing shared action owner uses the same TOP order without a second manager',function()
 local _,s,e=setup({enemyHp=8});local hand=#s.hand;local apply=C.applyEffects;local hit=false
 C.applyEffects=function(state,...)
  if state==s and state.actionQueue and not hit then hit=true;C.damage(s,e,s.player,1)end
  return apply(state,...)
 end
 local ok,result=pcall(trace,s,function()C.resolvePotionActions(s,{{op='block',value=0,fixed=true}})end)
 C.applyEffects=apply;assert(ok,result);eq(result,'D3,C');eq(#s.hand,hand+3);eq(C.outcome(s),'victory');eq(s.actionQueue,nil)
end)
test('public Run.endTurn native enemy action preserves Puzzle before the lethal evoke',function()
 local r,s,e=setup({enemyHp=17})
 for i,intent in ipairs(e.intents)do if intent.kind=='attack'then e.intentIndex=i end end
 eq(trace(s,function()assert(Run.endTurn(r))end),'D3,C')
 eq(r.phase,'reward');eq(#s.hand,3);eq(e.hp,0);eq(s.cardActions,nil)
end)
test('each Static layer creates one queued channel and retains exact target RNG calls',function()
 local _,s,e=setup({puzzle=false,amount=2});local expected=R.cloneState(s.cardRandomRng)
 R.randomInt(expected,0);R.randomInt(expected,0)
 eq(trace(s,function()C.damage(s,e,s.player,1)end),'C,C');same(R.snapshot(s.cardRandomRng),R.snapshot(expected))
end)
test('Buffer prevents positive attacked damage so neither Static nor Puzzle triggers',function()
 local _,s,e=setup();A.applyPower(s,s.player,'buffer',1,s.player);local hp=s.player.hp;local rng=R.snapshot(s.cardRandomRng)
 eq(trace(s,function()C.damage(s,e,s.player,1)end),'');eq(s.player.hp,hp);eq(s.relicCombat.centennialUsed,nil)
 same(R.snapshot(s.cardRandomRng),rng);eq(s.player.statuses.buffer,nil)
end)
test('Tungsten prevents HP loss after Static dispatch but cannot trigger Puzzle',function()
 local _,s,e=setup({rod=true});local hp=s.player.hp
 eq(trace(s,function()C.damage(s,e,s.player,1)end),'C');eq(s.player.hp,hp);eq(s.relicCombat.centennialUsed,nil)
end)
test('Fairy revives after actual HP callbacks then Puzzle precedes Static',function()
 local _,s,e=setup();s.player.hp=1;s.potionInventory={[1]='fairy_in_a_bottle'}
 eq(trace(s,function()C.damage(s,e,s.player,2)end),'D3,C');assert(s.player.hp>0);eq(s.potionInventory[1],nil)
 eq(s.relicCombat.centennialUsed,true)
end)
test('fatal damage without Fairy clears queued draws and channels',function()
 local _,s,e=setup();s.player.hp=1;local rng=R.snapshot(s.cardRandomRng)
 eq(trace(s,function()C.damage(s,e,s.player,2)end),'');eq(C.outcome(s),'defeat');eq(s.relicCombat.centennialUsed,true)
 same(R.snapshot(s.cardRandomRng),rng)
end)
for _,order in ipairs({'thornsFirst','thornsLast'})do
 test('same-priority '..order..' keeps reverse TOP execution after Puzzle',function()
  local _,s,e=setup({[order]=true})
  eq(trace(s,function()C.damage(s,e,s.player,1)end),order=='thornsFirst'and 'D3,C,T'or 'D3,T,C')
 end)
end
test('BlockReturn TOP block follows later Puzzle and precedes earlier Static',function()
 local _,s,e=setup();A.applyPower(s,s.player,'block_return',2,e)
 eq(trace(s,function()C.damage(s,e,s.player,1)end),'D3,B,C');eq(s.player.block,2)
end)
test('late Static channel fault rolls back public enemy turn references RNG and Puzzle use',function()
 local r,s,e=setup();for i,intent in ipairs(e.intents)do if intent.kind=='attack'then e.intentIndex=i end end
 local before=C.copy(r);local hand,orbs,balls,rng=s.hand,s.orbs,s.orbs.balls,s.cardRandomRng
 local channel=O.channel;O.channel=function(state,...)
  local result=channel(state,...);if state==s then error('late Static channel fault')end;return result
 end
 local ok=pcall(Run.endTurn,r);O.channel=channel;eq(ok,false);same(r,before)
 eq(r.combat,s);eq(s.hand,hand);eq(s.orbs,orbs);eq(s.orbs.balls,balls);eq(s.cardRandomRng,rng)
 assert(Run.endTurn(r));eq(s.relicCombat.centennialUsed,true)
end)
print('STATIC_HP_TOP_ORDER '..count..' groups; '..failed..' failed');assert(failed==0,'Static HP callback order regression')
