local H=dofile('tests/helpers/act2_event_ui.lua')
local test,eq,same=H.test,H.eq,H.same
local function offer(id,relic,tier)
 local r,m=H.fixture(id);H.front(r,relic,tier);if id=='mausoleum' then H.boolean(r,true)end;return r,m
end
local function choose(id,r,m)
 local ui,get,shown,click=H.setup(r,m)
 H.parity(r,m,id=='mausoleum' and 'open' or 'steal',nil,function()return click('eventView/option'..(id=='mausoleum' and 1 or 2))end)
 return ui,get,shown,click
end

test('old/new Omamori order and old/new Ceramic Fish effects through real UI commands',function()
 for _,id in ipairs({'mausoleum','addict'})do
  for _,variant in ipairs({'old_omamori','new_omamori','old_fish','new_fish','blocked_new_fish'})do
   local target=variant=='new_omamori' and 'Omamori' or (variant=='new_fish' or variant=='blocked_new_fish') and 'CeramicFish' or 'Anchor'
   local tier=target=='Omamori' and 'common' or 'common'
   local r,m=offer(id,target,tier)
   if variant=='old_omamori' or variant=='blocked_new_fish' then assert(H.Run.obtainRelic(r,'Omamori'))end
   if variant=='old_fish' then assert(H.Run.obtainRelic(r,'CeramicFish'))end
   local gold,uid=r.gold,r.nextDeckUid;choose(id,r,m)
   local blocked=variant=='old_omamori' or variant=='blocked_new_fish'
   eq(r.nextDeckUid,uid+(blocked and 0 or 1));eq(r.nodeFlow.event.curseBlocked,blocked)
   if variant=='new_omamori' then eq(r.relicCounters.omamori,2)end
   if blocked then eq(r.relicCounters.omamori,1)end
   eq(r.gold,gold+((variant=='new_fish' or variant=='old_fish') and 9 or 0))
  end
 end
end)
test('old/new Darkstone through actual UI, maxHP before heal; Omamori blocks delayed effect',function()
 for _,id in ipairs({'mausoleum','addict'})do
  for _,variant in ipairs({'old','new','blocked_new'})do
   local r,m=offer(id,variant=='old' and 'Anchor' or 'Darkstone Periapt',variant=='old' and 'common' or 'uncommon')
   if variant=='old' then assert(H.Run.obtainRelic(r,'Darkstone Periapt'))end
   if variant=='blocked_new' then assert(H.Run.obtainRelic(r,'Omamori'))end
   r.hp=1;local max=r.maxHp;choose(id,r,m)
   eq(r.maxHp,max+(variant=='blocked_new' and 0 or 6));eq(r.hp,variant=='blocked_new' and 1 or 7)
  end
 end
end)
test('both simple event source relic misses refuse without queue truncation/reroll, gold/protection/RNG/UID mutation',function()
 for _,id in ipairs({'mausoleum','addict'})do
  local r,m=offer(id,'Bird Faced Urn','rare');assert(H.Run.obtainRelic(r,'Omamori'))
  r.data=H.Copy(r.data)
  for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].sourceId=='Bird Faced Urn'then table.remove(r.data.relics.relics,i)end end
  local ui,get,shown,click=H.setup(r,m);local before=H.snapshot(r)
  local ok,why=H.parity(r,m,id=='mausoleum' and 'open' or 'steal',nil,function()return click('eventView/option'..(id=='mausoleum' and 1 or 2))end)
  eq(ok,false);eq(why,'relic_content_unavailable');same(r,before);eq(r.relicPool.queues.rare[1],'Bird Faced Urn')
  -- A fresh action retries the SAME source selection, not a UI-selected replacement.
  H.unchanged(r,m,function()return click('eventView/option'..(id=='mausoleum' and 1 or 2))end)
 end
end)
test('Beggar failed removal hook never refunds paid transaction; old callback cannot run after fresh recovery render',function()
 local r,m=H.selecting({{uid=7,cardId='parasite'}});r.hp,r.maxHp=80,80
 local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'));local old=ui.actions.confirm.handler
 local original=H.Curses.onRemove
 H.Curses.onRemove=function(staged,card)
  original(staged,card);staged.gold=999;H.Random.randomInt(staged.miscRng,99);error('Act2 UI remove hook witness')
 end
 local before=H.snapshot(r);local ok,why=click('confirm');H.Curses.onRemove=original
 eq(ok,false);eq(why,'transaction_failed');same(r,before);eq(r.gold,25);eq(r.nodeFlow.event.stage,'choose_card')
 H.unchanged(r,m,old);H.parity(r,m,'purge',7,function()return click('confirm')end);eq(r.gold,25);eq(r.maxHp,77)
end)
test('both simple-event equip/card exceptions rollback paid/protection/relic/curse state then fresh gesture recovers',function()
 for _,id in ipairs({'mausoleum','addict'})do
  for _,hook in ipairs({'onEquip','onObtainCard'})do
   local r,m=offer(id,hook=='onEquip' and 'Strawberry' or 'CeramicFish')
   if hook=='onEquip' then r.gold=85;r.hp=1 end
   local ui,get,shown,click=H.setup(r,m)
   local index=id=='mausoleum' and 1 or hook=='onEquip' and 1 or 2
   local choice=id=='mausoleum' and 'open' or hook=='onEquip' and 'buy' or 'steal'
   local key='eventView/option'..index;local old=ui.actions[key].handler
   local original=H.Hooks[hook]
   H.Hooks[hook]=function(staged,...)original(staged,...);error('Act2 UI '..hook..' witness')end
   local before=H.snapshot(r);local ok,why=click(key);H.Hooks[hook]=original
   eq(ok,false);eq(why,'transaction_failed');same(r,before);eq(r.nodeFlow.event.stage,'intro');H.unchanged(r,m,old)
   H.parity(r,m,choice,nil,function()return click(key)end)
  end
 end
end)
test('reentrant hook cannot donate again, remove twice or submit event command while busy',function()
 local r,m=H.selecting({{uid=7,cardId='strike'},{uid=8,cardId='defend'}})
 local ui,get,shown,click=H.setup(r,m);assert(click('pickerView/card1'));local original=H.Run.removeCard;local nested
 H.Run.removeCard=function(staged,uid)nested={ui:press('confirm')};return original(staged,uid)end
 local ok,why=click('confirm');H.Run.removeCard=original
 assert(ok,why);eq(nested[1],false);eq(nested[2],'unavailable_action');eq(r.gold,25);eq(#r.deck,1);eq(r.nodeFlow.event.removedUid,7)
end)
H.finish()
