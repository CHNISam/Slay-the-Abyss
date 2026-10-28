local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 2
local sliceRegistered,sliceExecuted=0,0
package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;'..package.path
local F=require('support.game_ui_fixture')
local X=require('support.experimental_ui_fixture')
local Run=require('abyss_run')
local Combat=require('abyss_combat')
local Profiles=require('abyss_character_profiles')
local Theme=require('abyss_theme')
local Data=require('abyss_data')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 sliceRegistered=sliceRegistered+1
 if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end
 sliceExecuted=sliceExecuted+1
fn();count=count+1;print('ok game_ui_phase_four '..count..' - '..name)end
local cursor={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='enddrag'}
local classIndex={ironclad=1,silent=2,defect=3,watcher=4}
local function control(root,path)
 local c=root;for id in path:gmatch('[^/]+')do c=assert(c:GetChild(id),path)end;return c
end
local function hit(root,path)
 local c=control(root,path)
 return c.listeners and c.listeners.click and c or assert(c:GetChild('hit'),path)
end
local function click(root,path,event)
 local c=hit(root,path);local parent=c
 while parent do assert(parent.visible,'hidden click '..path);parent=parent.parent end
 assert(c.raycastTarget~=false and (c.kind~='presetButton' or c.interactable~=false),'disabled click '..path)
 return assert(c.listeners.click,path)(event)
end
local function pointer(root,path,kind,id)return assert(hit(root,path).listeners[kind],path..kind)({touchId=id})end
local function tap(root,path,id)pointer(root,path,'down',id);pointer(root,path,'up',id);return click(root,path,{touchId=id})end
local function drain(ui)
 for _=1,400 do if not ui.battleUI.busy then return end;assert(ui:update(.05))end
 error('real battle feedback did not finish')
end
local function freeze(state)
 local saved,pending={},{state}
 while #pending>0 do
  local t=table.remove(pending)
  if not saved[t]then
   local values={};saved[t]=values
   for k,v in pairs(t)do values[k]=v;if type(v)=='table'then pending[#pending+1]=v end end
  end
 end
 return function()
  for t,values in pairs(saved)do
   for k,v in pairs(values)do eq(t[k],v)end
   for k,v in pairs(t)do eq(values[k],v)end
  end
 end
end
local function start(character,deck,physical)
 local ui,root=X.new({cursor=physical and cursor})
 assert(ui:start());assert(ui:selectCharacter('traveler'));assert(ui:selectElement(character));assert(ui:confirmCharacter())
 eq(ui.run.character or 'ironclad',character)
 -- Controlled permanent-deck fixture. No natural reward or starter claim.
 ui.run.deck={}
 for i,id in ipairs(deck)do ui.run.deck[i]={uid=i,cardId=type(id)=='table'and id.cardId or id,upgraded=type(id)=='table'and id.upgraded==true or false}end
 ui.run.nextDeckUid=#deck+1
 assert(Run.startCombat(ui.run,'cultist_solo'));ui:refresh()
 return ui,root,ui.run.combat
end
local function find(pile,id)for _,c in ipairs(pile)do if c.cardId==id then return c end end;error('missing '..id)end
local function contains(pile,uid)for _,c in ipairs(pile)do if c.uid==uid then return c end end end
local function play(ui,root,id,target)
 local slot,instance
 for i,c in ipairs(ui.run.combat.hand)do if c.cardId==id then slot=i;instance=c;break end end
 assert(slot,'missing rendered source card '..id)
 click(root,'battlePanel/card'..slot);eq(ui.battleUI.selected,instance.uid)
 local _,reason=Combat.canPlay(ui.run.combat,instance.uid,nil)
 target=target or reason=='invalid_target'
 click(root,target and 'battlePanel/enemy1' or 'battlePanel/playArea')
 drain(ui);return instance
end
test('legacy raw profiles keep66 red and75 per new class without counting auxiliary cards',function()
 local total=0
 for id,want in pairs({ironclad=66,silent=75,defect=75,watcher=75})do
  local d=Profiles.prepare(Data,id);local n=0
  for _,c in ipairs(d.cards.cards)do if c.type~='status'and c.type~='curse'and c.rarity~='special'then n=n+1 end end
  eq(n,want);total=total+n
 end
 eq(total,291)
end)
local choiceSpecs={
 {character='ironclad',card='headbutt',source='discard',destination='draw',count=1,target=true},
 {character='defect',card='hologram',source='discard',destination='hand',count=1},
 {character='defect',card='seek',source='draw',destination='hand',count=2,up=true},
 {character='ironclad',card='exhume',source='exhaust',destination='hand',count=1},
}
local function choice(spec,physical)
 local deck={{cardId=spec.card,upgraded=spec.up==true}}
 for _=1,14 do deck[#deck+1]=spec.character=='defect'and 'defend_blue'or 'defend'end
 local ui,root,s=start(spec.character,deck,physical)
 local all={}
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do all[#all+1]=c end end
 s.hand={};s.draw={};s.discard={};s.exhaust={}
 local used
 -- Reposition genuine initialized instances, preserving all UIDs and costs.
 for _,c in ipairs(all)do
  if c.cardId==spec.card then s.hand[1]=c;used=c else s[spec.source][#s[spec.source]+1]=c end
 end
 assert(used);ui:refresh();play(ui,root,spec.card,spec.target)
 local p=assert(s.pendingPileChoice,'real source card did not pause')
 eq(p.mode,spec.card);eq(p.count,spec.count);eq(#p.candidateUids,14)
 eq(ui.choiceUI.visible,true);eq(ui.battleUI.active,false);eq(#ui.choiceUI.cards,14)
 assert(control(root,'choicePanel/after').visible)
 local label=hit(root,'choicePanel/card1'):GetChild('normal'):GetChild('label').text
 assert(label:find('费用',1,true)and label:find('[\128-\255]'))
 return ui,root,s,p,used
end
for _,spec in ipairs(choiceSpecs)do
 test(spec.card..' real click retrieval shows fourteen candidates and keeps selection across pages',function()
  local ui,root,s,p,used=choice(spec)
  local first=ui.choiceUI.cards[1].uid;local second=ui.choiceUI.cards[11].uid
  if spec.count==2 then assert(click(root,'choicePanel/card1'))end
  assert(click(root,'choicePanel/after'));eq(ui.choiceUI.page,2)
  assert(click(root,'choicePanel/card1'))
  eq(ui.choiceUI.selected[#ui.choiceUI.selected],second)
  assert(click(root,'choicePanel/before'));eq(ui.choiceUI.page,1)
  eq(#ui.choiceUI.selected,spec.count)
  assert(click(root,'choicePanel/confirm'));drain(ui)
  eq(s.pendingPileChoice,nil);eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
  if spec.destination=='draw'then eq(s.draw[#s.draw].uid,second)
  else assert(contains(s.hand,second));if spec.count==2 then eq(s.hand[1].uid,first);eq(s.hand[2].uid,second)end end
  if spec.card=='headbutt'then assert(contains(s.discard,used.uid))
  else assert(contains(s.exhaust,used.uid))end
  eq(ui.choiceUI.visible,false);eq(ui.battleUI.active,true)
 end)
end
test('exit cancel restores the same mandatory pile choice and blocks underlying commands',function()
 local ui,root,s,p=choice(choiceSpecs[3]);assert(click(root,'choicePanel/card1'))
 local unchanged=freeze(s)
 assert(click(root,'exitEntry/open'));eq(ui.exitOpen,true);eq(ui.choiceUI.visible,false)
 assert(ui.menuOpen);assert(click(root,'runMenu/abandon'));eq(ui.menuOpen,false)
 ui.battleUI:endTurn();eq(ui:openDeck(),false);unchanged()
 assert(click(root,'exitPanel/cancel'));eq(s.pendingPileChoice,p);eq(ui.choiceUI.visible,true);unchanged()
 eq(#ui.choiceUI.selected,0)
 assert(click(root,'choicePanel/card1'));assert(click(root,'choicePanel/after'));assert(click(root,'choicePanel/card1'))
 assert(click(root,'choicePanel/confirm'));drain(ui);eq(s.pendingPileChoice,nil)
end)
test('old combat generation is rejected by the real command and selection remains retryable',function()
 local ui,root,s,p=choice(choiceSpecs[1]);local uid=ui.choiceUI.cards[1].uid;local unchanged=freeze(s)
 local ok,why=ui.battleUI:chooseCards('pile',{uid},p.token,ui.run.combatGeneration-1)
 eq(ok,false);eq(why,'stale_combat_generation');eq(s.pendingPileChoice,p);unchanged()
 assert(click(root,'choicePanel/card1'));assert(click(root,'choicePanel/confirm'));drain(ui);eq(s.pendingPileChoice,nil)
end)
test('real core generation refusal preserves selected UID and allows same-view retry',function()
 local ui,root,s,p=choice(choiceSpecs[2]);assert(click(root,'choicePanel/card1'))
 local selected=ui.choiceUI.selected[1];local generation=s.combatGeneration
 -- UI identity/candidates stay valid; only the independent core stamp differs.
 s.combatGeneration=generation+1;local unchanged=freeze(s)
 local ok,why=click(root,'choicePanel/confirm')
 eq(ok,false);eq(why,'stale_pile_choice_generation');eq(ui.battleUI.busy,false)
 eq(s.pendingPileChoice,p);eq(ui.choiceUI.visible,true);eq(ui.choiceUI.selected[1],selected);unchanged()
 assert(control(root,'choicePanel/status').text:find('重新确认',1,true))
 s.combatGeneration=generation;assert(click(root,'choicePanel/confirm'));drain(ui)
 eq(s.pendingPileChoice,nil);assert(contains(s.hand,selected))
end)
test('an old physical confirmation expires after page changes and exit cancel',function()
 for _,mode in ipairs({'page','exit'})do
  local ui,root,s,p=choice(choiceSpecs[3],true)
  assert(tap(root,'choicePanel/card1',1));assert(tap(root,'choicePanel/card2',8))
  pointer(root,'choicePanel/confirm','down',2);pointer(root,'choicePanel/confirm','up',2)
  if mode=='page'then assert(tap(root,'choicePanel/after',3))
  else assert(click(root,'exitEntry/open'));assert(click(root,'exitPanel/cancel'))end
  eq(hit(root,'choicePanel/confirm').listeners.click({touchId=2}),false);eq(s.pendingPileChoice,p)
  if #ui.choiceUI.selected==0 then
   assert(tap(root,'choicePanel/card1',4));assert(tap(root,'choicePanel/after',5));assert(tap(root,'choicePanel/card1',6))
  end
  eq(#ui.choiceUI.selected,2)
  assert(tap(root,'choicePanel/confirm',7));drain(ui);eq(s.pendingPileChoice,nil)
 end
end)
local powerCases={
 {'ironclad','evolve','evolve',1,'状态牌'},
 {'ironclad','fire_breathing','fire_breathing',6,'诅咒'},
 {'ironclad','flame_barrier','flame_barrier',4,'攻击'},
 {'silent','blur','blur',1,'格挡'},
 {'silent','choke','choked',3,'牌',true},
 {'silent','predator','draw_next_turn',2,'抽'},
 {'defect','lock_on','lock_on',2,'球',true},
 {'watcher','battle_hymn','battle_hymn',1,'惩罚'},
 {'watcher','collect','collect',3,'奇迹'},
 {'watcher','fasting','energy_down',1,'能量'},
 {'watcher','like_water','like_water',5,'平静'},
 {'watcher','study','study',1,'洞见'},
 {'watcher','talk_to_the_hand','block_return',2,'格挡',true},
 {'watcher','simmering_fury','wrath_next_turn',1,'愤怒',false,true},
 {'watcher','simmering_fury','draw_card_next_turn',2,'抽'},
 {'watcher','wreath_of_flame','vigor',5,'攻击'},
 {'watcher','pressure_points','mark',8,'生命',true},
}
for _,spec in ipairs(powerCases)do
 test(spec[3]..' actual source play exposes numeric Chinese detail and explicitly mapped icon',function()
  local character,card,id,value,phrase,enemy,marker=table.unpack(spec)
  local deck={};for _=1,12 do deck[#deck+1]=card end
  local ui,root,s=start(character,deck)
  play(ui,root,card,enemy)
  local actor=enemy and s.enemies[1]or s.player;eq(actor.statuses[id],value)
  local entries=Combat.statusView(actor);local index,entry
  for i,e in ipairs(entries)do if e.id==id then index=i;entry=e end end
  assert(index,'new Power absent from real status view '..id)
  local owner='battlePanel/'..(enemy and 'enemy1'or 'hero')
  local row=control(root,owner..'/statusRow');local icon=row:GetChild('icon'..index)
  local expected=Theme.icon.status[id]
  assert(type(expected)=='number'and expected>0,'missing explicit status icon '..id)
  eq(icon.visible,true);eq(icon.imageId,expected);eq(row:GetChild('count'..index).text,tostring(value))
  local unchanged=freeze(s)
  click(root,owner..'/statusRow/hit'..index);local info=control(root,'battlePanel/statusInfo')
  eq(info.visible,true);assert(info:GetChild('name1').text:find(entry.name,1,true))
  local text=info:GetChild('text1').text;local tag=info:GetChild('tag1').text;local note=info:GetChild('note1').text
  assert(text:find('[\128-\255]')and text:find(phrase,1,true),id..': '..text)
  assert(tag==''or tag:find('[\128-\255]'),'numeric-only fallback duration '..id..': '..tag)
  if not marker then assert((text..tag..note):find(tostring(value),1,true),'missing actual amount '..id)end
  eq(info:GetChild('icon1').imageId,expected);unchanged()
  click(root,'battlePanel/statusInfo/hit');eq(info.visible,false);unchanged()
 end)
end
print('GAME_UI_PHASE_FOUR_PASS '..count)

assert(sliceRegistered==26,'all original cases must register')
assert(sliceExecuted==sliceLast-sliceFirst+1,'all selected cases must execute')
print('PR238_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)
