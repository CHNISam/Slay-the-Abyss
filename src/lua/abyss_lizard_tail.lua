-- Fixed sts@319009d5 Lizard Tail callback component, not a fatal coordinator.
-- Caller orders Mark/Fairy first and owns full transaction rollback and healing.
local M={}
local ids={lizard_tail=true,['Lizard Tail']=true}
local marks={mark_of_bloom=true,['Mark of the Bloom']=true}
local function holds(owner,identities)
 if type(owner)~='table'or type(owner.relics)~='table'then return false end
 for _,id in ipairs(owner.relics)do if identities[id]then return true end end
 return false
end
function M.has(owner)return holds(owner,ids)end
local function counters(owner,create)
 local values=owner.relicCounters
 if values==nil and create then values={};owner.relicCounters=values end
 assert(type(values)=='table'and getmetatable(values)==nil,'Lizard Tail counter table missing/invalid')
 return values
end
local function counter(owner)
 local value=counters(owner,false).lizard_tail
 assert(value==-1 or value==-2,'Lizard Tail counter must be -1 or -2')
 return value
end
function M.onObtain(owner)
 assert(M.has(owner),'Lizard Tail owner required before onObtain')
 counters(owner,true).lizard_tail=-1
 return true
end
function M.bind(owner)
 if not M.has(owner)then return false end
 local values=counters(owner,true)
 if values.lizard_tail==nil then values.lizard_tail=-1 end
 counter(owner)
 return true
end
function M.state(owner)
 if not M.has(owner)then return nil end
 if counter(owner)==-2 then return 'spent' end
 if holds(owner,marks)then return 'blocked_by_mark'end
 return 'available'
end
local function integer(value,low,high)
 return type(value)=='number'and value==value and value%1==0 and value>=low and value<=high
end
function M.tryRevive(owner,actor,healFn)
 if not M.has(owner)then return false end
 assert(type(actor)=='table'and integer(actor.hp,-2147483648,2147483647),'invalid Lizard Tail actor HP')
 if actor.hp>0 or M.state(owner)~='available'then return false end
 assert(integer(actor.maxHp,1,2147483647),'invalid Lizard Tail actor maxHp')
 assert(type(healFn)=='function','Lizard Tail healing callback required')
 local amount=math.max(1,math.floor(actor.maxHp/2))
 actor.hp=0 -- AbstractPlayer.damage explicitly normalizes before onTrigger.
 healFn(amount) -- Source heal is void; only a thrown error rejects this call.
 counters(owner,false).lizard_tail=-2
 return true,amount
end
return M
