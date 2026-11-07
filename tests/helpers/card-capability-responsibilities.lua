package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Capability=require('abyss_card_capability')
local Copy=require('abyss_copy').copy
local Effects,Curses=require('abyss_effects'),require('abyss_curses')
local group=ABYSS_CAPABILITY_GROUP
local count=0
local function eq(a,b,label)assert(a==b,'[CAPABILITY_RESPONSIBILITY] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function check(card,expected,assertExpected,extra)
    local loads={};local old=require
    require=function(name)loads[#loads+1]=name;return old(name)end
    local result=table.pack(pcall(Capability.isImplemented,card))
    require=old
    if assertExpected then eq(result[1],true,'call returns normally');eq(result.n,2,'return arity');eq(result[2],expected,'capability result')end
    ABYSS_CAPABILITY_GRAPH_WRITE({card=card,result=result,loads=loads,extra=extra},'capability',false)
    count=count+1;return result
end
if group=='catalog'then
    local Data=require('abyss_data')
    local function catalog(data)
        for _,card in ipairs(data.cards.cards)do
            check(card,nil,false)
            if card.upgrade then
                local upgraded=Copy(card);for key,value in pairs(upgraded.upgrade)do upgraded[key]=value end
                check(upgraded,nil,false)
            end
        end
    end
    catalog(Data)
    for _,id in ipairs({'ironclad','silent','defect','watcher'})do catalog(require('abyss_character_profiles').prepare(Data,id))end
    local originals=0
    for _,id in ipairs({'hutao','arlecchino','furina','raiden'})do
        local data=require('abyss_original_v4_profiles').prepare(Data,id)
        for _,card in ipairs(data.cards.cards)do if card.originalV4 then
            check(card,true,true);local upgraded=Copy(card);for key,value in pairs(upgraded.upgrade)do upgraded[key]=value end
            check(upgraded,true,true);originals=originals+2
        end end
    end
    eq(originals,600,'all frozen original base/upgrade definitions')
elseif group=='boundaries'then
    check(nil,false,true);for _,value in ipairs({false,true,0,1,'attack'})do check(value,false,true)end
    local valid={
      {id='wound',type='status',cost=-2,effects={}},
      {id='dazed',type='status',cost=-2,ethereal=true,effects={}},
      {id='void',type='status',cost=-2,ethereal=true,effects={}},
      {id='burn',type='status',cost=-2,effects={}},
      {id='burn',type='status',cost=-2,burnDamage=2,effects={},upgrade={burnDamage=4}},
      {id='burn',type='status',cost=-2,burnDamage=4,effects={},upgrade={}},
      {id='slimed',type='status',cost=1,exhaust=true,effects={}},
    }
    for _,card in ipairs(valid)do check(card,true,true)end
    local changes={{'cost',0},{'effects',{{op='energy',value=1}}},{'id','unknown_status'}}
    for _,card in ipairs(valid)do for _,change in ipairs(changes)do
      local changed=Copy(card);changed[change[1]]=change[2];check(changed,false,true)
    end end
    for _,id in ipairs({'wound','burn','slimed'})do for _,flag in ipairs({true,0,'truthy',{}})do
      local card=Copy(id=='wound'and valid[1]or id=='burn'and valid[4]or valid[7]);card.ethereal=flag;check(card,false,true)
    end end
    for _,id in ipairs({'dazed','void'})do
      local card=Copy(id=='dazed'and valid[2]or valid[3]);card.upgrade={arbitrary=true};card.exhaust=true;check(card,true,true)
      for _,flag in ipairs({false,0,'truthy'})do card.ethereal=flag;check(card,false,true)end
    end
    for _,damage in ipairs({false,0,1,3,5,'2'})do local card=Copy(valid[4]);card.burnDamage=damage;check(card,false,true)end
    local implicit=Copy(valid[4]);implicit.upgrade={};check(implicit,false,true)
    for _,id in ipairs({'tactician','reflex','deus_ex_machina','unknown'})do
      for _,kind in ipairs({'attack','skill','power','status'})do
        for _,onDraw in ipairs({false,true,0,'hook'})do
          local card={id=id,type=kind,cost=-2,effects={},onDrawFinal=onDraw}
          check(card,kind=='skill'and id~='unknown',true)
        end
        local card={id=id,type=kind,cost=-2,effects={}}
        check(card,kind=='skill'and(id=='tactician'or id=='reflex'),true)
      end
    end
    for _,condition in ipairs({false,'only_attacks_in_hand','draw_pile_empty','unknown'})do
      for _,mode in ipairs({false,'all_energy','unknown'})do
        for _,experimental in ipairs({false,true,0})do for _,cost in ipairs({-1,0,1})do
          local card={id='test',type='skill',condition=condition,costMode=mode,experimental=experimental,cost=cost,effects={{op='energy',value=1}}}
          local expected=condition~='unknown'and mode~='unknown'and(condition~='draw_pile_empty'or experimental==true)
            and not(experimental==true and mode and cost~=-1)
          check(card,expected,true)
        end end
      end
    end
    for _,bad in ipairs({false,0,'effects',{},{{op='unknown',value=1}}})do check({id='bad',type='skill',cost=1,effects=bad},nil,false)end
elseif group=='dynamic'then
    local Watcher,V4=require('abyss_watcher_final_cards'),require('abyss_original_v4')
    local hooks={Effects.supported,Curses.isImplemented,Watcher.supported,V4.supported}
    local calls={};local marker={identity='supported'};local errorObject={identity='fault',nested={}}
    local function install(e,c,w,v)
      calls={}
      Effects.supported=function(value)calls[#calls+1]={api='Effects',value=value};return e end
      Curses.isImplemented=function(value)calls[#calls+1]={api='Curses',value=value};return c end
      Watcher.supported=function(value)calls[#calls+1]={api='Watcher',value=value};return w end
      V4.supported=function(value)calls[#calls+1]={api='V4',value=value};return v end
    end
    for _,value in ipairs({false,true,0,'supported',marker})do
      install(value,value,value,value)
      local effects={};check({id='ordinary',type='skill',cost=1,effects=effects},value==true,true,calls)
      check({id='dynamic',type='curse',cost=-2,effects={}},value,true,calls)
      local raw={id='raw'};local card={id='raw',type='attack',originalV4=raw,effects={{op='originalV4',raw=raw}},condition='unknown'}
      check(card,value,true,calls)
      local watcher={id='watcher',type='skill',watcherFinal=true,cost=1,effects={}}
      check(watcher,value~=false and value==true,true,calls)
    end
    install(true,true,true,true)
    check({id='wanted',type='skill',originalV4={},effects={{op='originalV4',raw={id='other'}}}},false,true,calls)
    check({id='wanted',type='skill',originalV4={},effects={{op='originalV4'}}},nil,true,calls)
    check({id='wanted',type='skill',originalV4={},effects={{op='unknown',raw={id='wanted'}}}},false,true,calls)
    check({id='wanted',type='power',originalV4={},effects={{op='originalV4',raw={id='wanted'}}}},false,true,calls)
    install(nil,nil,nil,nil)
    check({type='skill',watcherFinal=true,effects={}},false,true,calls)
    check({type='curse'},nil,true,calls)
    local raw={id='raw'};local card={id='raw',type='skill',originalV4=raw,effects={{op='originalV4',raw=raw}}}
    check(card,nil,true,calls)
    card.effects[1].raw=nil;check(card,nil,true,calls)
    card.effects[1]=false;check(card,false,true,calls)
    card.effects={};check(card,false,true,calls)
    card.effects=false;check(card,false,true,calls)
    install(true,true,true,true)
    for _,name in ipairs({'Effects','Curses','Watcher','V4'})do
      local module,key=Effects,'supported'
      if name=='Curses'then module,key=Curses,'isImplemented' elseif name=='Watcher'then module=Watcher elseif name=='V4'then module=V4 end
      local old=module[key];module[key]=function(value)value.touched=errorObject;error(errorObject,0)end
      local probe={id='ordinary',type='skill',effects={}}
      if name=='Curses'then probe.type='curse' elseif name=='Watcher'then probe.watcherFinal=true elseif name=='V4'then
        probe.originalV4={id='ordinary'};probe.effects={{op='originalV4',raw=probe.originalV4}}
      end
      local result=check(probe,nil,false,{fault=errorObject});eq(result[1],false,'thrown callback');eq(result[2],errorObject,'original error object')
      module[key]=old
    end
    local priorCurse=Curses.isImplemented
    Curses.isImplemented=function()return nil,false,marker,nil end
    local packed=check({type='curse'},nil,false,{marker=marker})
    eq(packed.n,5,'curse tail preserves nil-hole return arity');eq(packed[1],true);eq(packed[2],nil);eq(packed[3],false);eq(packed[4],marker);eq(packed[5],nil)
    Curses.isImplemented=priorCurse
    for _,id in ipairs({'wound','dazed','void','burn','slimed','ordinary'})do
      local reads={};local fields={id=id,type=id=='ordinary'and'skill'or'status',cost=id=='slimed'and 1 or -2,effects={},ethereal=id=='dazed'or id=='void',exhaust=id=='slimed'}
      local card=setmetatable({},{__index=function(_,key)reads[#reads+1]=key;return fields[key]end})
      check(card,nil,false,{reads=reads,fields=fields})
    end
    local reads={};local changed={type='status',cost=-2,effects={},ethereal=true};local n=0
    local card=setmetatable({},{__index=function(_,key)reads[#reads+1]=key;if key=='id'then n=n+1;return n==1 and 'not_wound'or'dazed'end;return changed[key]end})
    check(card,true,true,{reads=reads,fields=changed})
    eq(n,2,'ID must be reread at the original decision points')
    Effects.supported,Curses.isImplemented,Watcher.supported,V4.supported=table.unpack(hooks)
else error('unknown capability group')end
local expected={catalog=1439,boundaries=254,dynamic=43}
eq(count,expected[group],'complete registered scenario count')
ABYSS_CAPABILITY_GRAPH_WRITE({group=group,count=count},'complete',false)
