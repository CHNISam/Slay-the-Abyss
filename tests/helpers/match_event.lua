local H={}
H.C,H.Run,H.R,H.Hooks=require('abyss_combat'),require('abyss_run'),require('abyss_sts_random'),require('abyss_relic_hooks')
H.Data=require('abyss_data')
local ok,Match=pcall(require,'abyss_match_event')
assert(ok and type(Match.prepare)=='function','production Match sampling and commands must exist')
H.Match=Match
function H.eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
function H.same(a,b,path,seen)
 if a==b then return end;path=path or 'state';H.eq(type(a),type(b))
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 seen=seen or {};if seen[a]then H.eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do H.same(v,b[k],path..'.'..tostring(k),seen)end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local base
function H.fixture(options)
 options=options or {}
 if not base then base=H.Run.new(H.Data,'42',{experimental=true,campaign=true,character='ironclad'})end
 local r=H.C.copy(base,{[base.data]=base.data})
 r.runSeed=options.seed or '42';r.cardRng=H.R.fromSeed(r.runSeed)
 if options.relics then r.relics=H.C.copy(options.relics)end
 r.phase,r.floor,r.act='node',options.floor or 7,options.act or 1;r.roomGeneration=9
 local event={id='match_game'};r.nodeFlow={id='match-room',type='event',floor=r.floor,event=event,complete=false}
 local misc=H.Run.roomStreams(r,r.floor).miscRng
 assert(H.Match.prepare(r,event,misc,r.floor));r.miscRng=misc
 return r
end
function H.view(r)local event=H.C.copy(r.nodeFlow.event);H.Match.view(r,event);return event end
function H.choose(r,choice,token)
 return H.Run.transaction(r,function(s)return H.Match.choose(s,s.nodeFlow,choice,token)end)
end
function H.play(r)assert(H.choose(r,'continue'));assert(H.choose(r,'start'));return r end
function H.flip(r,slot)return H.choose(r,'flip',H.view(r).match.slots[slot].token)end
function H.resolve(r)return H.choose(r,'resolve',H.view(r).match.resolveToken)end
function H.finish(r)return H.choose(r,'finish',H.view(r).match.completionToken)end
function H.pairs(r)
 local out,first={},{}
 for i,c in ipairs(r.nodeFlow.event.board)do
  if first[c.cardId]then out[#out+1]={first[c.cardId],i};first[c.cardId]=nil else first[c.cardId]=i end
 end
 return out
end
function H.reject(r,choice,token,reason)
 local before=H.C.copy(r,{[r.data]=r.data});local flow,deck,event=r.nodeFlow,r.deck,r.nodeFlow.event
 local accepted,why=H.choose(r,choice,token);H.eq(accepted,false);H.eq(why,reason or 'invalid_event_choice')
 H.same(r,before);H.eq(r.nodeFlow,flow);H.eq(r.nodeFlow.event,event);H.eq(r.deck,deck)
end
H.count=0
function H.test(name,fn)fn();H.count=H.count+1;print('PASS Match '..H.count..' '..name)end
return H
