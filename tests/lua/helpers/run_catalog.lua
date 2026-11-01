local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local M={Run=Run,C=C,D=D}
function M.new(deck,character)
 local r=Run.new(D,42,character and{character=character,experimental=true}or nil)
 r.deck={};r.relics={}
 for i,id in ipairs(deck)do r.deck[i]={uid=30+i,cardId=id,upgraded=false}end
 assert(Run.startCombat(r,'cultist_solo'));r.combat.energy=20
 return r,r.combat
end
function M.held(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error('missing hand card '..id)
end
function M.play(r,id,target)
 local c=M.held(r.combat,id);local ok,why=Run.play(r,c.uid,target);assert(ok,why);return c
end
function M.arrange(s,piles)
 local all={}
 for _,name in ipairs({'hand','draw','discard','exhaust'})do
  for _,c in ipairs(s[name])do all[#all+1]=c end;s[name]={}
 end
 for _,name in ipairs({'hand','draw','discard','exhaust'})do
  for _,id in ipairs(piles[name]or{})do
   local found;for i,c in ipairs(all)do if c.cardId==id then found=table.remove(all,i);break end end
   s[name][#s[name]+1]=assert(found,'fixture missing '..id)
  end
 end
 assert(#all==0,'fixture must retain every Combat-created instance')
end
return M
