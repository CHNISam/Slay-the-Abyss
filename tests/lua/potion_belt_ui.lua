package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,C,Map,Nodes=require('abyss_run'),require('abyss_combat'),require('abyss_map'),require('abyss_nodes')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS potion belt UI '..count..' '..name)end
local function setup(belt)
 local h,r=F.fixture();assert(h:start());if belt then assert(Run.obtainRelic(h.run,'Potion Belt'))end
 h:refresh();return h,r
end
local function counter(r,used,capacity)
 local hit=r:GetChild('potionEntry'):GetChild('open'):GetChild('hit')
 for _,state in ipairs({'normal','hover','pressed','disabled'})do eq(hit:GetChild(state):GetChild('label').text,'药水 '..used..'/'..capacity)end
end
local function hit(r,name)return r:GetChild('potionPanel'):GetChild(name):GetChild('hit')end
local function modal(r,name)return hit(r,name).click()end
local function bottle(panel,slot)return assert(panel:GetChild('potion'..slot) or panel:GetChild('potionHelp'):GetChild('potion'..slot),'missing bottle '..slot)end
local function drain(h)for _=1,400 do if not h.battleUI.busy then return end;h:update(.05)end;assert(not h.battleUI.busy)end
local function fill(h)
 for _,id in ipairs({'fire_potion','block_potion','regen_potion','energy_potion','strength_potion'})do assert(Run.obtainPotion(h.run,id))end
 h:refresh()
end
test('default three hides nonexistent battle bottles, help and management slots',function()
 local h,r=setup(false);counter(r,0,3);assert(h:openPotions())
 for slot=1,5 do eq(r:GetChild('potionPanel'):GetChild('slot'..slot).visible,slot<=3)end
 for slot=4,5 do eq(modal(r,'slot'..slot),false)end
 assert(h:closePotions());assert(Run.startCombat(h.run,'cultist_solo'));h:refresh()
 local panel=r:GetChild('battlePanel')
 for slot=1,5 do
  eq(bottle(panel,slot).visible,slot<=3)
  eq(panel:GetChild('potionHelp'):GetChild('potionHelp'..slot).visible,slot<=3)
 end
end)
test('real Belt exposes five management slots and discard refills exact fourth vacancy',function()
 local h,r=setup(true);fill(h);counter(r,5,5);assert(h:openPotions())
 for slot=1,5 do eq(r:GetChild('potionPanel'):GetChild('slot'..slot).visible,true);eq(hit(r,'slot'..slot).interactable,true)end
 assert(modal(r,'slot4'));assert(r:GetChild('potionPanel'):GetChild('detail').text:find('能量',1,true))
 assert(modal(r,'discard'));eq(h.run.potions[4],nil);eq(h.run.potions[5],'strength_potion');counter(r,4,5)
 local ok,slot=Run.obtainPotion(h.run,'dexterity_potion');eq(ok,true);eq(slot,4);h:refresh();counter(r,5,5)
 assert(modal(r,'slot5'));assert(r:GetChild('potionPanel'):GetChild('detail').text:find('力量',1,true));assert(modal(r,'discard'))
 eq(h.run.potions[5],nil);eq(h.run.potions[4],'dexterity_potion');counter(r,4,5)
end)
test('fourth and fifth native battle buttons use real bottles and expose independent help',function()
 local h,r=setup(true);fill(h);assert(Run.startCombat(h.run,'cultist_solo'));h:refresh()
 local panel=r:GetChild('battlePanel')
 for slot=4,5 do eq(bottle(panel,slot).visible,true);eq(panel:GetChild('potionHelp'):GetChild('potionHelp'..slot).visible,true)end
 local before=C.copy(h.run.potions);local energy=h.run.combat.energy
 for slot=4,5 do
  panel:GetChild('potionHelp'):GetChild('potionHelp'..slot).listeners.click()
  eq(panel:GetChild('statusInfo').visible,true);same(h.run.potions,before);eq(h.run.combat.energy,energy)
  panel:GetChild('statusInfo'):GetChild('hit').listeners.click()
 end
 bottle(panel,4).listeners.click();drain(h);eq(h.run.combat.energy,energy+2);eq(h.run.potions[4],nil)
 bottle(panel,5).listeners.click();drain(h);eq(h.run.combat.player.statuses.strength,2);eq(h.run.potions[5],nil);counter(r,3,5)
end)
test('shop inventory admission and shared counter use actual five-slot capacity',function()
 local h,r=setup(true)
 for _,id in ipairs({'fire_potion','block_potion','regen_potion','energy_potion'})do assert(Run.obtainPotion(h.run,id))end
 local path=dofile('tests/lua/support/map_routes.lua').to(h.map,function(n)return n.type=='shop'end)
 for i=1,#path-1 do assert(Map.choose(h.map,path[i]))end
 assert(Nodes.enter(h.run,h.map,path[#path]));h.run.gold=1000;h:refresh();counter(r,4,5)
 local offer;for _,v in ipairs(h.run.nodeFlow.potions)do if not v.unavailable then offer=v;break end end;assert(offer)
 local gold=h.run.gold;assert(r:GetChild('nodePanel'):GetChild('shopView'):GetChild('potion'..offer.slot):GetChild('hit').click())
 eq(h.run.potions[5],offer.id);eq(h.run.gold,gold-offer.price);counter(r,5,5)
 local nextOffer;for _,v in ipairs(h.run.nodeFlow.potions)do if not v.unavailable and not v.sold then nextOffer=v;break end end;assert(nextOffer)
 local before=C.copy(h.run);local ok,why=Nodes.buyPotion(h.run,nextOffer.slot);eq(ok,false);eq(why,'potion_slots_full');same(h.run,before)
end)
test('full-five real combat reward refuses until management discard frees the fourth slot',function()
 local h,r=setup(false);h.run=Run.new(F.Data,42);h.map=Map.generate(F.Data,42)
 h.battleUI.run,h.nodeUI.run=h.run,h.run
 assert(Run.obtainRelic(h.run,'Potion Belt'));fill(h);assert(Run.startCombat(h.run,'cultist_solo'))
 for _,enemy in ipairs(h.run.combat.enemies)do enemy.hp=0 end
 assert(Run.finishCombat(h.run));h:refresh();counter(r,5,5)
 local offered=assert(h.run.rewards.potion);local before=C.copy(h.run)
 local claim=r:GetChild('battlePanel'):GetChild('claimPotion')
 eq(claim.listeners.click(),false);same(h.run,before);eq(offered.resolved,nil)
 assert(h:openPotions());assert(modal(r,'slot4'));assert(modal(r,'discard'));assert(h:closePotions());counter(r,4,5)
 local ok,why=claim.listeners.click();assert(ok,tostring(why)..' reward='..tostring(offered.id)..' unavailable='..tostring(offered.unavailable))
 eq(h.run.potions[4],offered.id);eq(h.run.potions[5],'strength_potion');counter(r,5,5)
end)
print('POTION_BELT_UI '..count..' passed')
