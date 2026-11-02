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
