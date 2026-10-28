package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C,A,H=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks')
local P,O,F=require('abyss_poison'),require('abyss_orbs'),require('abyss_focus')
local D=require('abyss_data')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function run(character,ids,deck)
 local r=R.new(D,'42',character and {experimental=true,character=character}or nil)
 for _,id in ipairs(ids or {})do assert(R.obtainRelic(r,id))end
 if deck then r.deck={};for i,id in ipairs(deck)do r.deck[i]={uid=i,cardId=id,upgraded=false}end end
 assert(R.startCombat(r,'cultist_solo'));r.combat.enemies[1].hp=10000;r.combat.enemies[1].maxHp=10000
 return r,r.combat
end
local function play(r,id)
 C.draw(r.combat,10)
 for _,card in ipairs(r.combat.hand)do if card.cardId==id then assert(R.play(r,card.uid,1));return end end
 error('missing '..id)
end

test('Snake Skull only transforms player-sourced Poison onto a different target',function()
 local _,s=run();local e=s.enemies[1]
 s.relics={'Snake Skull'}
 A.applyPower(s,e,'poison',3,s.player);eq(e.statuses.poison,4)
 e.statuses.poison=nil;A.applyPower(s,e,'poison',3,nil);eq(e.statuses.poison,3)
 e.statuses.poison=nil;A.applyPower(s,e,'poison',3,e);eq(e.statuses.poison,3)
 A.applyPower(s,s.player,'poison',3,s.player);eq(s.player.statuses.poison,3)
 A.applyPower(s,s.player,'poison',3,e);eq(s.player.statuses.poison,6)
 A.applyPower(s,e,'weak',2,s.player);eq(e.statuses.weak,2)
 e.statuses.poison=nil;A.status(s,e,'poison',3,s.player);eq(e.statuses.poison,3,'raw mutation is not ApplyPower')
 s.relics={};e.statuses.poison=nil;A.applyPower(s,e,'poison',3,s.player);eq(e.statuses.poison,3)
end)
test('Snake Skull precedes Artifact and does not apply to dead targets',function()
 local _,s=run();local e=s.enemies[1];s.relics={'snake_skull'}
 e.statuses.artifact=1;A.applyPower(s,e,'poison',3,s.player);eq(e.statuses.artifact,0);eq(e.statuses.poison,nil)
 A.applyPower(s,e,'poison',0,s.player);eq(e.statuses.poison,1,'zero incoming Power still gains one')
 e.statuses.poison=2147483647;e.statuses.artifact=1
 A.applyPower(s,e,'poison',3,s.player);eq(e.statuses.artifact,0);eq(e.statuses.poison,2147483647,'Artifact precedes stack overflow')
 e.hp=0;A.applyPower(s,e,'poison',3,s.player);eq(e.statuses.poison,2147483647)
end)
test('Snake Skull adds after the new PoisonPower cap and to the uncapped existing stackAmount',function()
 local _,s=run('silent',{'Snake Skull'});local e=s.enemies[1]
 A.addStatus(s.player,'noxious_fumes',20000);assert(P.postDraw(s));eq(e.statuses.poison,10000)
 e.statuses.poison=1;assert(P.postDraw(s));eq(e.statuses.poison,20002)
 e.statuses.poison=10000;assert(P.multiply(s,e,3));eq(e.statuses.poison,30001)
end)
test('real Deadly Poison and Catalyst add exactly one per ApplyPower, not per stack',function()
 local r,s=run('silent',{'snake_skull'},{'deadly_poison','catalyst'})
 play(r,'deadly_poison');eq(s.enemies[1].statuses.poison,6)
 play(r,'catalyst');eq(s.enemies[1].statuses.poison,13)
end)
test('real Bouncing Flask adds one on each bounce and preserves one-target RNG draws',function()
 local r,s=run('silent',{'snake_skull'},{'bouncing_flask'});local n=s.cardRandomRng.counter
 play(r,'bouncing_flask');eq(s.enemies[1].statuses.poison,12);eq(s.cardRandomRng.counter,n+3)
end)
test('Envenom and actual Noxious Fumes turns use the same Snake Skull owner',function()
 local r,s=run('silent',{'snake_skull'},{'envenom','noxious_fumes','strike_green'})
 s.energy=10;play(r,'envenom');play(r,'noxious_fumes');play(r,'strike_green');eq(s.enemies[1].statuses.poison,2)
 assert(R.endTurn(r));eq(s.enemies[1].statuses.poison,4,'one Envenom poison decays, Fumes adds three')
end)
test('DataDisk gives one first-turn Focus before draw and never regrants each turn',function()
 local r,s=run('defect',{'DataDisk'});eq(s.player.statuses.focus,1);eq(s.orbs.focus,1)
 local focusFrame
 for i,event in ipairs(s.events)do
  if event.kind=='status' and event.detail.status=='focus'then focusFrame=event.frame end
 end
 assert(focusFrame and #focusFrame.hand==0 and #s.hand==5,'DataDisk TOP precedes the ordinary draw')
 assert(R.endTurn(r));eq(s.player.statuses.focus,1)
 for _,ids in ipairs({{'data_disk','vajra','oddly_smooth_stone'},{'oddly_smooth_stone','vajra','data_disk'}})do
  local _,mixed=run(nil,ids);local actual={}
  for _,event in ipairs(mixed.events)do if event.kind=='status' and (event.detail.status=='focus'or event.detail.status=='strength'or event.detail.status=='dexterity')then actual[#actual+1]=event.detail.status end end
  eq(table.concat(actual,','),ids[1]=='data_disk'and 'dexterity,strength,focus'or 'focus,strength,dexterity','battle TOP hooks reverse held order')
 end
end)
test('DataDisk reuses Focus lifecycle without replacing or retagging existing orbs',function()
 local _,s=run('defect',{'data_disk'});O.channel(s,'dark',C);O.channel(s,'plasma',C)
 local container,first,second,third=s.orbs,s.orbs.balls[1],s.orbs.balls[2],s.orbs.balls[3]
 local stored=second.stored
 A.applyPower(s,s.player,'bias',1,s.player);F.startTurn(s);eq(s.player.statuses.focus,nil);eq(s.orbs.focus,0)
 eq(s.orbs,container);eq(s.orbs.balls[1],first);eq(s.orbs.balls[2],second);eq(s.orbs.balls[3],third);eq(second.stored,stored)
 F.startTurn(s);eq(s.player.statuses.focus,-1);eq(O.view(s).balls[3].passive,1,'Plasma ignores Focus')
end)
test('DataDisk external obtain on a non-Defect keeps zero orb slots and uses the shared status owner',function()
 local _,s=run('silent',{'data_disk'});eq(s.player.statuses.focus,1);eq(s.orbs.focus,1);eq(s.orbs.slots,0);eq(#s.orbs.balls,0)
 local _,plain=run('defect');eq(plain.player.statuses.focus,nil);eq(plain.orbs.focus,0)
end)
assert(failed==0,tostring(failed)..' class common effect cases failed')
print('CLASS_COMMON_RELIC_EFFECTS_PASS '..count)
