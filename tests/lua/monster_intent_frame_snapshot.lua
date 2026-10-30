local C=require('abyss_combat')
local Data=require('abyss_data')
local Events=require('abyss_events')
local AI=require('abyss_act2_ai')
local s=C.new(Data,{enemies={'book_of_stabbing','book_of_stabbing'},deck={'strike'},seed=42})
local e=s.enemies[1]
local sibling=s.enemies[2]
local function multi(actor)
 for _,move in ipairs(actor.intents)do if move.id=='multi_stab'then return move end end
 error('missing actual Book move')
end
-- Exercise the actual source-policy setter, not a hand-mutated mock payload.
local function roll()return 50 end
AI.advance(s,e,roll)
local event=Events.emit(s,'intent',{enemy=e.id})
local before=multi(event.frame.enemies[1]).effects[1].times
local liveBefore=e.act2Stabs
local siblingTimes=multi(sibling).effects[1].times
for _=1,4 do AI.advance(s,e,roll)end
assert(e.act2Stabs>liveBefore,'fixture must really select repeated source multi-stab')
assert(multi(event.frame.enemies[1]).effects[1].times==before,'later Book selection rewrote a prior presentation boundary')
assert(event.frame.enemies[1].intents~=e.intents)
assert(multi(sibling).effects[1].times==siblingTimes,'same-definition sibling core must remain independent')
assert(event.frame.enemies[1].intents~=event.frame.enemies[2].intents,'same-definition frame identities must not alias')
assert(multi(event.frame.enemies[1]).effects~=multi(e).effects)
local liveValue=multi(e).effects[1].value
multi(event.frame.enemies[1]).effects[1].value=999
assert(multi(e).effects[1].value==liveValue,'presentation writes must not mutate core move data')
local second=Events.frame(s)
assert(multi(second.enemies[1]).effects[1].times==e.act2Stabs,'new boundary must capture latest selected payload')
local Boss=require('abyss_act1_bosses')
local h=C.new(Data,{enemies={'hexaghost','hexaghost'},deck={'strike'},seed=42})
local function find(actor,id)
 for _,move in ipairs(actor.intents)do if move.id==id then return move end end
 error('missing source move '..id)
end
h.player.hp=60
Boss.beforeAction(h,h.enemies[1],find(h.enemies[1],'activate'))
local hf=Events.frame(h)
assert(find(hf.enemies[1],'divider').effects[1].value==6)
h.player.hp=12
Boss.beforeAction(h,h.enemies[1],find(h.enemies[1],'activate'))
assert(find(h.enemies[1],'divider').effects[1].value==2,'actual HP-based Divider setter must run')
assert(find(hf.enemies[1],'divider').effects[1].value==6,'future HP-based Divider capture cannot rewrite historical damage')
assert(find(h.enemies[2],'divider').effects[1].value==1,'same-definition Hexaghost sibling must remain independent')
local frames={};local start=os.clock()
for i=1,100 do frames[i]=Events.frame(h)end
print('FRAME_COPY_100_TWO_HEXAGHOST_SECONDS '..(os.clock()-start))
assert(#frames==100 and frames[1].enemies[1].intents~=frames[100].enemies[1].intents)
print('MONSTER_INTENT_FRAME_SNAPSHOT_PASS')
