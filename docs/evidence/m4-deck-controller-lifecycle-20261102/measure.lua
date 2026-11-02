-- Measurement only; the regression and negative control live in tests/.
-- Optional baseline file is populated from the pinned Git object, not edited.
if ABYSS_DECK_BASELINE_PATH then package.loaded.abyss_deck_ui=dofile(ABYSS_DECK_BASELINE_PATH)end
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Controller=require('abyss_controller')
local spec
local function find(entries)
    for _,entry in ipairs(entries)do
        if entry.name=='deckPanel' then spec=entry end
        find(entry.children or {})
    end
end
find(F.Layout)
local panel=F.control(assert(spec))
local manager=Controller.new({events={Confirm='confirm',Cancel='cancel'},
    getFocus=function()return nil end,setFocus=function()end,isController=function()return false end},panel)
local deck=require('abyss_deck_ui').new(panel,F.Presentation,'click',{
    controller=manager,imageSource='static',color=function(...)return {...}end},function()end)
local grid=panel:GetChild('grid');grid.destroyOnRefresh=true
local run={deck={},data=F.Data,relics={}}
for i=1,12 do run.deck[i]={uid=i,cardId='bash',upgraded=false}end
local baseline=#manager.records
print('BASELINE_RECORDS '..baseline)
for cycle=1,20 do
    assert(deck:open(run));deck:update(0);deck:update(0);assert(deck:close())
    manager:sync('map')
    if cycle==1 or cycle==10 or cycle==20 then
        local dead=0
        for _,record in ipairs(manager.records)do if record.control.alive==false then dead=dead+1 end end
        print('CLOSED_CYCLE '..cycle..' RECORDS '..#manager.records..' DEAD '..dead)
    end
end
local visits,eligible=0,manager.eligible
manager.eligible=function(self,record)visits=visits+1;return eligible(self,record)end
for _=1,300 do manager:sync('map')end
print('POINTER_SYNC_300_VISITS '..visits..' BASELINE_EQUIVALENT '..baseline*300)
