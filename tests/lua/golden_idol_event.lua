local F=dofile('tests/lua/support/golden_idol_fixture.lua')
local fixture,eq,same,Run,Map,Nodes,C,R,P,D=F.fixture,F.eq,F.same,F.Run,F.Map,F.Nodes,F.C,F.R,F.P,F.D
local r,m,id=fixture();local ok,why=Nodes.enter(r,m,id);assert(ok,why)
local function chineseView(run,map)
 local event=Nodes.view(run,map).node.event
 for _,text in ipairs({event.title or '',event.body or ''})do assert(not text:find('[A-Za-z]'),text)end
 for _,option in ipairs(event.options)do
  assert(not option.title:find('[A-Za-z]'),option.title)
  assert(not option.description:find('[A-Za-z]'),option.description)
 end
 return event
end
local intro=chineseView(r,m);assert(intro.body:find('鎏金神像',1,true))
eq(intro.options[1].title,'拿取鎏金神像')
eq(P.contentId['Golden Idol'],'golden_idol');eq(r.nodeFlow.event.stage,'intro');local choices=Nodes.view(r,m).node.event.options;eq(#choices,2);eq(choices[1].choice,'take');eq(choices[2].choice,'leave')
local uid,deck,rng=r.nextDeckUid,C.copy(r.deck),R.snapshot(r.miscRng)
assert(Nodes.chooseEvent(r,'take'));eq(r.relics[#r.relics],'golden_idol');eq(r.nodeFlow.event.stage,'trap');eq(r.hp,80);eq(#Nodes.view(r,m).node.event.options,3)
local trap=chineseView(r,m);eq(trap.options[1].title,'承受旧伤');eq(trap.options[1].description,'获得诅咒牌「旧伤」。')
local b=C.copy(r);eq(Nodes.chooseEvent(r,'leave'),false);eq(Nodes.chooseEvent(r,'take'),false);same(r,b)
assert(Nodes.chooseEvent(r,'injury'));eq(r.deck[#r.deck].cardId,'injury');eq(r.deck[#r.deck].uid,uid);eq(r.nextDeckUid,uid+1);eq(r.nodeFlow.event.stage,'result');eq(r.phase,'node')
eq(chineseView(r,m).body,'你获得了诅咒牌「旧伤」。')
for i,card in ipairs(deck)do same(r.deck[i],card)end;same(R.snapshot(r.miscRng),rng)
assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map')
do
 local repeated,map,node=fixture();assert(Run.obtainRelic(repeated,'golden_idol'));assert(Nodes.enter(repeated,map,node))
 assert(chineseView(repeated,map).options[1].description:find('圆环',1,true))
 assert(Nodes.chooseEvent(repeated,'take'));eq(repeated.relics[#repeated.relics],'circlet');chineseView(repeated,map)
end
do
 local protected,map,node=fixture();assert(Run.obtainRelic(protected,'omamori'));assert(Nodes.enter(protected,map,node))
 local size=#protected.deck;assert(Nodes.chooseEvent(protected,'take'));assert(Nodes.chooseEvent(protected,'injury'))
 eq(#protected.deck,size);eq(chineseView(protected,map).body,'护符阻止了诅咒牌「旧伤」。')
end
for _,choice in ipairs({'leave','damage','max_hp'})do
 local run,map,node=fixture();assert(Nodes.enter(run,map,node))
 if choice~='leave'then assert(Nodes.chooseEvent(run,'take'))end
 assert(Nodes.chooseEvent(run,choice));chineseView(run,map)
end
print('GOLDEN_IDOL_EVENT_PASS actual public obtain before mandatory trap, Injury permanent UID and no body RNG')
