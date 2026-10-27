-- ChooseOneAction for Stance Potion only. Options are typed stance records,
-- never cards or permanent entities; the owning action queue stays paused.
local Events=require('abyss_events')
local M={}
local MAX=2147483647
local function integer(v,lo)return type(v)=='number'and v%1==0 and v>=lo and v<=MAX end
local options={
 {id='Wrath',name='愤怒',text='进入愤怒：造成和受到的普通攻击伤害均翻倍。已在愤怒时不重复转换。'},
 {id='Calm',name='平静',text='进入平静：离开平静时获得2点能量。已在平静时不重复转换。'},
}
function M.view(state,generation)
 local p=state.pendingPotionChoice;local q=state.actionQueue
 if type(p)~='table'or p.mode~='stance'or p.count~=1 or p.turn~=state.turn or state.phase~='player'or state.player.hp<=0
  or not integer(p.token,1)or p.token~=state.potionChoiceSerial or not integer(generation,0)
  or p.generation~=generation or generation~=state.combatGeneration
  or type(q)~='table'or not q.paused or type(q.current)~='table'or type(q.current.effect)~='table'or q.current.effect.op~='potionStanceChoice'
  or type(p.options)~='table'or #p.options~=2 then return end
 for i,source in ipairs(options)do
  local row=p.options[i]
  if type(row)~='table'or row.id~=source.id or row.name~=source.name or row.text~=source.text then return end
 end
 return p
end
function M.begin(state)
 assert(not state.pendingPotionChoice and not state.pendingPlay and not state.pendingChoice
  and not state.pendingHandChoice and not state.pendingPileChoice and not state.pendingScry and not state.pendingDiscard,'another selection is pending')
 assert(state.player.stance=='Neutral'or state.player.stance=='Wrath'or state.player.stance=='Calm'or state.player.stance=='Divinity','stance mechanics not enabled')
 assert(integer(state.combatGeneration,0)and integer(state.turn,0)and integer(state.potionChoiceSerial or 0,0)
  and (state.potionChoiceSerial or 0)<MAX,'invalid potion choice generation')
 state.potionChoiceSerial=(state.potionChoiceSerial or 0)+1
 local choices={};for i,row in ipairs(options)do choices[i]={id=row.id,name=row.name,text=row.text}end
 state.pendingPotionChoice={mode='stance',count=1,token=state.potionChoiceSerial,turn=state.turn,generation=state.combatGeneration,options=choices}
 Events.emit(state,'potion_stance_choice',{token=state.potionChoiceSerial,generation=state.combatGeneration})
 return 'pause'
end
function M.choose(state,selected,token,generation,queue)
 local p=M.view(state,generation)
 if not p or p.token~=token then return false,'stale_potion_choice'end
 if type(selected)~='table'or getmetatable(selected)~=nil or #selected~=1
  or (selected[1]~='Wrath'and selected[1]~='Calm')then return false,'invalid_potion_choice'end
 for k in pairs(selected)do if k~=1 then return false,'invalid_potion_choice'end end
 -- Choose*.onChoseThisOption appends behind the original potion BOT tail.
 queue.pushBottom(state,{kind='effect',effect={op='changeStance',stance=selected[1]}})
 state.pendingPotionChoice=nil
 Events.emit(state,'potion_stance_selected',{stance=selected[1],token=token})
 return true
end
return M
