package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data')
local data=P.prepare(D,'watcher');local seen={};for _,c in ipairs(data.cards.cards)do seen[c.id]=true end
for _,c in ipairs(D.cards.cards)do if not seen[c.id]then data.cards.cards[#data.cards.cards+1]=C.copy(c)end end
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error(id)end
for _,manual in ipairs({false,true})do for _,up in ipairs({false,true})do for amount=1,2 do
 local deck={{uid=31,cardId='master_reality'},{uid=32,cardId='dual_wield',upgraded=amount==2},
  {uid=33,cardId='searing_blow',upgraded=up,upgrades=up and 1 or nil},{uid=34,cardId=manual and 'strike' or 'defend'}}
 local s=C.new(data,{seed=1,enableStances=true,deck=deck,masterDeck=deck,enemies={'cultist'}});s.energy=20
 assert(C.play(s,held(s,'master_reality').uid));local original=held(s,'searing_blow');local before=original.upgrades or (up and 1 or 0)
 assert(C.play(s,held(s,'dual_wield').uid))
 if manual then local p=assert(s.pendingChoice);assert(C.chooseCard(s,p.token,original.uid))else assert(not s.pendingChoice)end
 assert((original.upgrades or (original.upgraded and 1 or 0))==before,'constructor must receive a stat-equivalent copy, not the chosen original')
 assert(s.masterDeck[3].upgraded==up and s.masterDeck[3].upgrades==(up and 1 or nil),'permanent original remains unchanged')
 local copies,kept=0,false
 for _,c in ipairs(s.hand)do if c.cardId=='searing_blow'then
  if c.uid==original.uid then kept=true
  else copies=copies+1;assert(c.upgrades==before+2 and c.deckUid==nil and c.uuid~=original.uuid)end
 end end
 assert(copies==amount+(manual and 1 or 0) and kept==not manual,'singleton and selected replacement keep their source copy counts')
end end end
print('MASTER_REALITY_DUAL_WIELD_SOURCE singleton/manual x two card versions x two input upgrades preserve originals and upgrade each copy twice passed')
