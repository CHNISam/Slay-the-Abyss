local F=dofile('tests/lua/support/act3_winding_fixture.lua')
local fixture,eq,same,Run,Nodes,C,P,R=F.fixture,F.eq,F.same,F.Run,F.Nodes,F.C,F.P,F.R
for _,choice in ipairs({'madness','writhe','max_hp'})do
 local r,m,n=fixture(1);assert(Nodes.enter(r,m,n));local b=C.copy(r);eq(Nodes.chooseEvent(r,choice),false);same(r,b)
 assert(Nodes.chooseEvent(r,'continue'));b=C.copy(r);eq(Nodes.chooseEvent(r,choice,999),false);same(r,b)
 r.maxHp=0;b=C.copy(r);eq(Nodes.chooseEvent(r,choice),false);same(r,b)
end
for _,choice in ipairs({'madness','writhe'})do
 local r,m,n=fixture(1);assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id==(choice=='madness'and'madness'or'writhe')then table.remove(r.data.cards.cards,i)end end
 local b,bm=C.copy(r),C.copy(m);eq(Nodes.chooseEvent(r,choice),false);same(r,b);same(m,bm)
end
do
 local r,m,n=fixture(1);assert(Run.obtainRelic(r,'ceramic_fish'));r.nextDeckUid=9007199254740990.0;assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'))
 local b,bm=C.copy(r),C.copy(m);local ok,why=Nodes.chooseEvent(r,'madness');eq(ok,false);eq(why,'invalid_deck_uid');same(r,b);same(m,bm)
end
for _,mode in ipairs({'return','throw'})do
 local r,m,n=fixture(1);assert(Run.obtainRelic(r,'ceramic_fish'));assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local b,bm=C.copy(r),C.copy(m)
 local original,count=Run.obtainCard,0
 Run.obtainCard=function(owner,id,options)local ok,uid=original(owner,id,options);assert(ok);count=count+1;if count==2 then if mode=='throw'then error('late Winding second-card failure')end;return false,'late_obtain_failure'end;return ok,uid end
 local called,ok=pcall(Nodes.chooseEvent,r,'madness');Run.obtainCard=original;assert(called);eq(count,2);eq(ok,false);same(r,b);same(m,bm)
end
do
 local r,m,n=fixture(1);assert(Run.obtainRelic(r,'omamori'));assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'continue'));local b,bm=C.copy(r),C.copy(m)
 local original=Run.obtainCard;Run.obtainCard=function(owner,id)local ok=original(owner,id);assert(ok);return false,'late_blocked_curse_failure'end
 local called,ok=pcall(Nodes.chooseEvent,r,'writhe');Run.obtainCard=original;assert(called);eq(ok,false);same(r,b);same(m,bm)
end
print('ACT3_WINDING_ROLLBACK_PASS wrong-stage/UID/maxHP, missing definitions after damage/heal, real second-UID overflow, late second obtain and blocked curse rollback before defeat')
