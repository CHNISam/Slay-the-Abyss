-- Explicit controlled hand/HP/noDraw inputs; all effects dispatch real Run APIs.
local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
return function(fixture,fullPool,attackPool)
 local run=Run.new(D,fixture.seed,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
 for _,id in ipairs({'Strange Spoon','Dead Branch','Mummified Hand'})do assert(Run.obtainRelic(run,id))end
 for _,id in ipairs({'attack_potion','elixir','snecko_oil'})do assert(Run.obtainPotion(run,id))end
 assert(Run.startCombat(run,'cultist_solo'))
 local s=run.combat
 same(R.snapshot(s.cardRandomRng),fixture.initial,'initial source stream')
 local function otherCombatStreams()
  local out={};for _,key in ipairs({'shuffleRng','aiRng','miscRng','monsterHpRng','potionRng','cardRng'})do if s[key]then out[key]=R.snapshot(s[key])end end;return out
 end
 local untouchedCombat=otherCombatStreams()
 local untouched={card=R.snapshot(run.cardRng),misc=R.snapshot(run.miscRng),event=R.snapshot(run.eventRng),shop=run.shopRng and C.copy(run.shopRng) or false}
 local trace={};local rawInt,rawBool=R.randomInt,R.randomBoolean
 R.randomInt=function(owner,maximum,...)
  local before=R.snapshot(owner);local result=rawInt(owner,maximum,...)
  trace[#trace+1]={maximum=maximum,boolean=false,value=result,before=before,after=R.snapshot(owner)}
  return result
 end
 R.randomBoolean=function(owner,...)
  local before=R.snapshot(owner);local result=rawBool(owner,...)
  trace[#trace+1]={boolean=true,value=result,before=before,after=R.snapshot(owner)}
  return result
 end
 local function source(id)return assert(s.catalog.cards[id].sourceId)end
 local function ids(cards)local out={};for _,card in ipairs(cards)do out[#out+1]=source(card.cardId)end;return out end
 local function state(i)same(R.snapshot(s.cardRandomRng),fixture.steps[i].after,fixture.steps[i].label..' complete stream')end
 local function card(uid)for _,pile in ipairs({s.hand,s.exhaust,s.discard})do for _,c in ipairs(pile)do if c.uid==uid then return c end end end end
 same((function()local p=require('abyss_potion_discovery').pool(s);local out={};for _,id in ipairs(p)do out[#out+1]=source(id)end;return out end)(),fullPool,'complete source pool')
 same((function()local p=require('abyss_potion_discovery').pool(s,'attack');local out={};for _,id in ipairs(p)do out[#out+1]=source(id)end;return out end)(),attackPool,'complete attack source pool')
 s.enemies[1].hp,s.enemies[1].maxHp=500,500;s.energy=30
 s.hand={{uid=1000,cardId='inflame'},{uid=1001,cardId='defend'},{uid=1002,cardId='bash'},
  {uid=1003,cardId='impervious'},{uid=1004,cardId='burn'},{uid=1005,cardId='whirlwind'},{uid=1006,cardId='anger'}}
 assert(Run.play(run,1000,1));state(1)
 local zeroed={};for _,uid in ipairs({1001,1002,1003})do if card(uid).costForTurn==0 then zeroed[#zeroed+1]=source(card(uid).cardId)end end
 same(zeroed,{fixture.steps[1].zeroed},'mummified selected source identity')
 local nextUid=s.nextUid;assert(Run.play(run,1003,1));state(2)
 local proc=fixture.steps[2].spoonProc
 local found=false;for _,c in ipairs(proc and s.discard or s.exhaust)do if c.uid==1003 then found=true end end;assert(found,'Spoon real destination')
 if not proc then same(source(card(nextUid).cardId),fixture.steps[2].generated,'Dead Branch identity')end
 assert(Run.usePotion(run,1));state(3)
 same(ids(s.pendingChoice.cards),fixture.steps[3].offers,'Discovery visible identities')
 local saved=C.copy(s);local token=s.pendingChoice.token
 assert(not Run.chooseCard(run,token,999));same(s,saved,'invalid selection atomic no random consumption')
 assert(Run.chooseCard(run,token,2));state(4)
 local selectionUid=s.hand[#s.hand].uid;assert(s.hand[#s.hand].costForTurn==0)
 local saved=C.copy(s);assert(not Run.chooseCard(run,token,2));same(s,saved,'stale selection atomic')
 assert(Run.usePotion(run,2));local p=s.pendingChoice
 assert(Run.chooseCard(run,p.token,1001));assert(Run.chooseCard(run,p.token,0));state(5)
 same(source(s.hand[#s.hand].cardId),fixture.steps[5].generated,'Elixir Dead Branch identity')
 -- Spooning applies only at played-card disposal; selected Elixir exhaust draws
 -- a branch card but does not spend an additional Spoon boolean.
 s.player.noDraw=true
 assert(Run.usePotion(run,3));state(6)
 local hand={};for _,c in ipairs(s.hand)do hand[#hand+1]={sourceId=source(c.cardId),cost=C.cardDefinition(s,c).cost}end
 same(hand,fixture.steps[6].hand,'Snecko exact hand identities and costs')
 local expected={};for _,t in ipairs(fixture.trace)do local copy=C.copy(t);copy.purpose=nil;expected[#expected+1]=copy end
 same(trace,expected,'every source wrapper draw and full before/after owner')
 assert(card(selectionUid),'Discovery result remains a combat instance')
 same({card=R.snapshot(run.cardRng),misc=R.snapshot(run.miscRng),event=R.snapshot(run.eventRng),shop=run.shopRng and C.copy(run.shopRng) or false},untouched,'unrelated permanent streams untouched')
 same(otherCombatStreams(),untouchedCombat,'unrelated combat streams untouched')
 R.randomInt,R.randomBoolean=rawInt,rawBool
 print('CARD_RANDOM_CHAIN_PASS '..fixture.seed..' draws='..#trace)
end
