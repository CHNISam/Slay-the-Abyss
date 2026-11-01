package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local counts={runNew=0,startCombat=0,startRoom=0,combatNew=0,copies=0,copyTables=0,copyEntries=0,ticks=0}
local function wrap(t,k,field)
 local fn=t[k];t[k]=function(...) counts[field]=counts[field]+1;return fn(...) end
end
wrap(Run,'new','runNew');wrap(Run,'startCombat','startCombat');wrap(Run,'startRoomCombat','startRoom');wrap(C,'new','combatNew')
local realCopy=C.copy
C.copy=function(value)
 counts.copies=counts.copies+1
 local function visit(v)
  if type(v)~='table' then return end
  counts.copyTables=counts.copyTables+1
  for _,entry in pairs(v) do counts.copyEntries=counts.copyEntries+1;visit(entry) end
 end
 visit(value)
 return realCopy(value)
end
local realPrint=print
print=function(...)
 realPrint(...)
 realPrint(string.format('COUNTS new=%d explicit=%d room=%d combat=%d copies=%d tables=%d entries=%d ticks1000=%d',counts.runNew,counts.startCombat,counts.startRoom,counts.combatNew,counts.copies,counts.copyTables,counts.copyEntries,counts.ticks))
end
debug.sethook(function() counts.ticks=counts.ticks+1 end,'',1000)
dofile(assert(os.getenv('FIXTURE')))
debug.sethook()
