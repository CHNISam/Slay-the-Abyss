package.path='./?.lua;'..package.path
local ok,P=pcall(require,'presentation');assert(ok,'native presentation adapter required')
local calls=0
local map={}
local owner={map=map,choose=function(_,id)calls=calls+1;return id=='legal'end}
local p=P.contract(owner)
assert(p:choose('legal')==true and calls==1)
assert(p:choose('illegal')==false and calls==2)
assert(owner.map==map,'adapter must preserve game owner')
assert(P.MAX_SHAPES==1536 and P.MAX_GLOWS==256 and P.ANIMATED_WRITES<=256)
local state=P.state({id='other',visited=false},'here',{other=true})
assert(state=='available','real availability wins over graph preview classification')
print('PRESENTATION_CONTRACT_PASS delegates authority and bounds pools')
assert(P.state({id='blocked'},'here',{}, {here=true})=='sealed','unreachable graph must not look like future')
assert(P.state({id='boot'},'here',{boot=true}, {here=true})=='available','Winged Boots legality beats visual reach')
assert(P.state({id='old',visited=true},'here',{}, {})=='visited')
local reach=P.reachable({{id='a',nextIds={'b'}},{id='b',nextIds={'a','c'}},{id='c',nextIds={}},{id='x',nextIds={}}},'a')
assert(reach.a and reach.b and reach.c and not reach.x,'reach traversal handles cycles without changing input')
assert(P.ease(0,.45,.05,.25,1)==0 and P.ease(1,.45,.05,.25,1)==1)
assert(P.fade(240,-308,242)<.1 and P.fade(0,-308,242)==1,'native mask must fade near viewport boundaries')
local alternative=P.reachable({{id='a',nextIds={}},{id='boot',nextIds={'later'}},{id='later',nextIds={}}},'a',{boot=true})
assert(alternative.later,'legally reachable alternative branch descendants must not be sealed')
local wide=P.viewport(1560,720);assert(wide.scale==1 and wide.header==76 and not wide.compact,'landscape must keep source CSS pixel sizes');assert(wide.top==284 and wide.bottom==-360)
local compact=P.viewport(800,720);assert(compact.compact and compact.legendWidth==46)
local phone=P.viewport(393,852);assert(phone.phone and phone.header==96 and phone.legendWidth==46)

for budget=0,256 do local count,writes=P.sparkBudget(budget);assert(count>=0 and count<=10 and writes<=budget,'optional sparks must fit remaining writes')end
local denseIcons=48;local critical=96+denseIcons*2+8+1+2;local count,writes=P.sparkBudget(256-critical);assert(critical+writes<=256 and count<10,'48-icon transition must shed decorative spark writes, not block route')
