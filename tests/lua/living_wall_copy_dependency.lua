package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local function check(value,message)assert(value,'[LIVING_COPY] '..message)end
check(package.loaded.abyss_combat==nil,'cold VM must start without Combat')
if ABYSS_LIVING_COPY_BLOCK~=false then
    package.preload.abyss_combat=function()error('[LIVING_COPY] pure read loaded Combat',0)end
end
local Wall=require('abyss_living_wall')
local function graph(value,seen)
    if type(value)~='table'then return type(value)..':'..tostring(value)end
    seen=seen or {n=0};if seen[value]then return 'ref:'..seen[value]end
    seen.n=seen.n+1;seen[value]=seen.n
    local keys={};for key in pairs(value)do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
    local rows={};for _,key in ipairs(keys)do rows[#rows+1]=graph(key,seen)..'='..graph(value[key],seen)end
    return '{'..table.concat(rows,';')..'}'
end
local key={name='preserved table key'}
local shared={value=7}
local first={uid=1,cardId='strike',upgraded=false,a=shared,b=shared,keyed={[key]=shared}}
first.self=first
local last={uid=2,cardId='defend',upgraded=true,a=shared}
local run={deck={first},transformContext={cards={local_curse={sourceId='AscendersBane'}}},miscRng={counter=5}}
for i,id in ipairs({'Necronomicurse','CurseOfTheBell','AscendersBane','necronomicurse','curse_of_the_bell','ascenders_bane'})do
    run.deck[#run.deck+1]={uid=100+i,cardId=id}
end
for i,flag in ipairs({'inBottleFlame','inBottleLightning','inBottleTornado'})do
    run.deck[#run.deck+1]={uid=200+i,cardId='strike',[flag]=true}
end
run.deck[#run.deck+1]={uid=300,cardId='local_curse'}
run.deck[#run.deck+1]=last
local before=graph(run)
local rows=Wall.purgeCards(run)
check(#rows==2 and rows[1].uid==1 and rows[2].uid==2,'protection, bottle and source-ID filtering preserve master order')
check(rows[1]~=first and rows[2]~=last,'every eligible instance is detached')
check(rows[1].self==rows[1] and rows[1].a==rows[1].b,'cycles and within-card aliases survive')
check(rows[1].keyed[key]==rows[1].a,'copy preserves table keys and nested value alias')
check(rows[1].a~=shared and rows[2].a~=shared and rows[1].a~=rows[2].a,'independent per-card calls stay independent')
check(graph(run)==before and run.miscRng.counter==5,'query never mutates inputs or spends RNG')
local repeated=Wall.purgeCards(run)
check(repeated[1]~=rows[1] and repeated[1].a~=rows[1].a,'repeated queries make independent graphs')
rows[1].a.value=9
check(shared.value==7 and rows[2].a.value==7 and repeated[1].a.value==7,'returned graph writes stay isolated')
check(#Wall.purgeCards({deck={}})==0,'empty deck remains an empty result')
check(package.loaded.abyss_run==nil,'pure queries do not load Session commands')
if ABYSS_LIVING_COPY_BLOCK~=false then check(package.loaded.abyss_combat==nil,'purgeCards does not load Combat')end
local modules={};for name in pairs(package.loaded)do if type(name)=='string'and name:match('^abyss_')then modules[#modules+1]=name end end
table.sort(modules)
print('LIVING_COPY_COLD '..#modules..' COMBAT '..tostring(package.loaded.abyss_combat~=nil))
print('LIVING_COPY_MODULES '..table.concat(modules,','))
if ABYSS_LIVING_COPY_TRACE then print('LIVING_COPY_TRACE '..graph({run=run,rows=rows,repeated=repeated,key=key,shared=shared}))end
print('LIVING_COPY_PASS protection, order, full copy graphs, cycles, keys, aliases, isolation, RNG and cold loading')
