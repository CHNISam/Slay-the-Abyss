local H=dofile('tests/lua/support/gremlin_gang_fixture.lua')
local Run,Map,Nodes,C,R,I,Data=H.Run,H.Map,H.Nodes,H.C,H.R,H.I,H.Data
local eq,same,freeze,test,ids,oracle,vectors,force,direct,nodeSetup,normal,unknown,enter,streamAfter=H.eq,H.same,H.freeze,H.test,H.ids,H.oracle,H.vectors,H.force,H.direct,H.nodeSetup,H.normal,H.unknown,H.enter,H.streamAfter
test('all 1680 selection paths match independent remaining-index oracle without constructing worlds',function()
 local run=direct();local stable=freeze(run);local oldDraw,oldNew=R.randomInt,C.new
 local input,calls,captured,first,unique,total=nil,0,nil,{},{},0
 R.randomInt=function(state,upper)
  calls=calls+1;eq(upper,8-calls);assert(state~=run.miscRng,'must stage the stream');return input[calls]
 end
 C.new=function(_,options) captured=C.copy(options.enemies);return nil,'selection_probe' end
 local ok,why=pcall(function()
  for a=0,7 do for b=0,6 do for c=0,5 do for d=0,4 do
   input={a,b,c,d};calls=0;captured=nil
   local success,reason=Run.startCombat(run,'gremlin_gang');eq(success,false);eq(reason,'selection_probe')
   eq(calls,4);same(captured,oracle(input));eq(#captured,4)
   local caps={mad_gremlin=2,sneaky_gremlin=2,fat_gremlin=2,shield_gremlin=1,wizard_gremlin=1}
   for _,id in ipairs(captured) do caps[id]=caps[id]-1;assert(caps[id]>=0) end
   total=total+1;first[captured[1]]=(first[captured[1]] or 0)+1;unique[table.concat(captured,',')]=true
  end end end end
 end)
 R.randomInt,C.new=oldDraw,oldNew;assert(ok,why);stable();eq(total,1680)
 same(first,{mad_gremlin=420,sneaky_gremlin=420,fat_gremlin=420,shield_gremlin=210,wizard_gremlin=210})
 local n=0;for _ in pairs(unique) do n=n+1 end;eq(n,354)
end)
H.finish(1,'GREMLIN_GANG_SELECTION_PASS')
