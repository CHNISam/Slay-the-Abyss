local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
return function(sample,pool)
 local run=Run.new(D,sample.seed,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
 local old=C.copy(run.deck);for _,c in ipairs(old)do assert(Run.removeCard(run,c.uid))end
 for _,id in ipairs({'defend','bash','anger','whirlwind','inflame','impervious','strike'})do assert(Run.obtainCard(run,id))end
 for _,id in ipairs({'mummified_hand','strange_spoon','dead_branch'})do assert(Run.obtainRelic(run,id))end
 assert(Run.obtainPotion(run,'distilled_chaos'));assert(Run.obtainPotion(run,'elixir'))
 run.floor=4;assert(Run.startCombat(run,'medium_slimes'));local s=run.combat;assert(#s.enemies==2)
 -- Explicit pile-order fixture uses only the actual combat copies of the seven
 -- publicly obtained permanent cards. No fake card identity or effect hook.
 local cards={};for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do cards[c.cardId]=c end end
 s.hand={cards.defend,cards.bash,cards.anger,cards.whirlwind}
 s.draw={cards.strike,cards.impervious,cards.inflame};s.discard={};s.exhaust={}
 assert(Run.usePotion(run,2));local token=assert(s.pendingChoice).token
 assert(Run.chooseCard(run,token,0));assert(not s.pendingChoice)
 same(R.snapshot(s.cardRandomRng),sample.initial,'initial source stream')
 local function unrelated()
  local out={}
  for _,key in ipairs({'shuffleRng','aiRng','miscRng','monsterHpRng','potionRng','cardRng'})do if s[key]then out[key]=R.snapshot(s[key])end end
  out.permanent=C.copy({card=run.cardRng,misc=run.miscRng,event=run.eventRng,shop=run.shopRng,relic=run.relicPool,treasure=run.treasureRng})
  return out
 end
 local untouched=unrelated();local deck=C.copy(run.deck);local hp={s.enemies[1].hp,s.enemies[2].hp}
 local function source(id)return assert(s.catalog.cards[id].sourceId)end
 local actualPool={};for _,id in ipairs(require('abyss_potion_discovery').pool(s))do actualPool[#actualPool+1]=source(id)end
 same(actualPool,pool,'full ordered Dead Branch source pool')
 local trace,plans={},{};local rawInt,rawBool,rawTop=R.randomInt,R.randomBoolean,C.autoplayTop
 C.autoplayTop=function(owner,target,...)
  plans[#plans+1]={target=target,stream=R.snapshot(owner.cardRandomRng)}
  return rawTop(owner,target,...)
 end
 R.randomInt=function(owner,maximum,...)
  local before=R.snapshot(owner);local result=rawInt(owner,maximum,...)
  trace[#trace+1]={maximum=maximum,boolean=false,value=result,before=before,after=R.snapshot(owner)};return result
 end
 R.randomBoolean=function(owner,...)
  local before=R.snapshot(owner);local result=rawBool(owner,...)
  trace[#trace+1]={boolean=true,value=result,before=before,after=R.snapshot(owner)};return result
 end
 local start=#s.events;local freshUid=s.nextUid
 assert(Run.usePotion(run,1));assert(run.combat==s and run.phase=='combat')
 local expected={};for _,row in ipairs(sample.trace)do local e=C.copy(row);e.purpose=nil;expected[#expected+1]=e end
 same(trace,expected,'every Chaos shared stream draw')
 same(R.snapshot(s.cardRandomRng),sample.after,'Chaos complete source stream')
 assert(#plans==3)
 for i,p in ipairs(plans)do
  assert(p.target==sample.targets[i],'each target was independently preplanned')
  same(p.stream,sample.afterTargets,'all target draws precede every queued autoplay consumer')
 end
 local played,targets={},{};for i=start+1,#s.events do local e=s.events[i];if e.kind=='play'then played[#played+1]=e.detail.uid;targets[#targets+1]=e.detail.target end end
 same(played,{cards.inflame.uid,cards.impervious.uid,cards.strike.uid},'actual autoplay FIFO')
 same(targets,sample.targets,'each real play retains its preplanned target')
 local zeroed={};for _,c in ipairs(s.hand)do if c.costForTurn==0 then zeroed[#zeroed+1]=source(c.cardId)end end
 same(zeroed,{sample.zeroed},'Mummified Hand actual source identity')
 assert(s.player.statuses.strength==2 and s.player.block==30 and s.energy==3,'real free card effects')
 for i,e in ipairs(s.enemies)do assert(e.hp==hp[i]-(sample.targets[3]==i and 8 or 0),'preplanned target receives source damage')end
 assert(#s.draw==0 and not s.cardActions and not s.queuedCards and not s.pendingChoice,'queue fully drained')
 if sample.spoonProc then
  assert(#s.discard==2 and #s.exhaust==0 and #s.hand==4 and s.nextUid==freshUid)
  assert(s.discard[1].uid==cards.impervious.uid and s.discard[2].uid==cards.strike.uid)
 else
  assert(#s.discard==1 and s.discard[1].uid==cards.strike.uid and #s.exhaust==1 and s.exhaust[1].uid==cards.impervious.uid)
  assert(#s.hand==5 and s.hand[5].uid==freshUid and source(s.hand[5].cardId)==sample.generated)
  assert(s.nextUid==freshUid+1,'one fresh temporary Branch card')
 end
 same(run.deck,deck,'permanent deck unchanged');same(unrelated(),untouched,'unrelated RNG owners unchanged')
 local saved=C.copy(run);local consumed=#trace
 assert(not Run.usePotion(run,1));same(run,saved,'consumed potion replay atomic')
 assert(not Run.chooseCard(run,token,0));same(run,saved,'actual old selection token replay atomic')
 assert(not Run.play(run,cards.strike.uid,sample.targets[3]));same(run,saved,'autoplay disposed UID replay atomic')
 assert(#trace==consumed,'rejected replay consumed shared stream')
 R.randomInt,R.randomBoolean,C.autoplayTop=rawInt,rawBool,rawTop
 print('CHAOS_SHARED_CHAIN_PASS '..sample.seed..' draws='..#trace)
end
