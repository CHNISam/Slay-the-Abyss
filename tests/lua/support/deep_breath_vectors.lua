local C,A,D,R,I=require('abyss_combat'),require('abyss_card_actions'),require('abyss_data'),require('abyss_sts_random'),require('abyss_inventory')
local U,Shop=require('abyss_uncommon_relics'),require('abyss_shop_relics')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
local function ids(pile)local out={};for _,c in ipairs(pile)do out[#out+1]=c.uid end;return out end
return function(samples)
 for _,sample in ipairs(samples)do
  local q=assert(I.opening(D.relics.relics,{'sundial','the_abacus'},{sundial=2}))
  local s=assert(C.new(D,{deck={},enemies={'jaw_worm'},seed=7,shuffleSeed=sample.seed,
   beforeOpeningDraw=function(owner)return I.applyOpening(owner,q.beforeDraw)end}))
  assert(I.applyOpening(s,q.afterDraw));s.energy=5
  local cards={};for uid=1,7 do cards[uid]=A.fresh(C,s,uid==1 and 'deep_breath'or uid%2==0 and 'strike'or 'defend');assert(cards[uid].uid==uid)end
  if sample.upgraded then assert(C.upgrade(s,cards[1]))end
  s.hand={cards[1]};s.draw={};s.discard={}
  for _,uid in ipairs(sample.drawBefore)do s.draw[#s.draw+1]=cards[uid]end
  for _,uid in ipairs(sample.discardBefore)do s.discard[#s.discard+1]=cards[uid]end
  same(R.snapshot(s.shuffleRng),sample.initial,'initial exact shuffle owner')
  local rawShuffle,rawLong,rawU,rawShop=R.shuffle,R.randomLongHex,U.onShuffle,Shop.onShuffle
  local trace,lastLong,callbacks={},nil,{uncommon=0,shop=0}
  R.randomLongHex=function(owner)local result=rawLong(owner);lastLong=result;return result end
  R.shuffle=function(owner,pile)
   local before,beforeCards=R.snapshot(owner),ids(pile);lastLong=nil;rawShuffle(owner,pile)
   assert(lastLong,'source shuffle consumes one long')
   trace[#trace+1]={before=before,beforeCards=beforeCards,cards=ids(pile),rawHex=lastLong,after=R.snapshot(owner)}
  end
  U.onShuffle=function(owner)
   callbacks.uncommon=callbacks.uncommon+1;same(R.snapshot(owner.shuffleRng),sample.initial,'constructor callback precedes first shuffle')
   return rawU(owner)
  end
  Shop.onShuffle=function(owner)
   callbacks.shop=callbacks.shop+1;same(R.snapshot(owner.shuffleRng),sample.initial,'constructor callback precedes first shuffle')
   return rawShop(owner)
  end
  assert(C.play(s,cards[1].uid))
  same(trace,sample.trace,'Deep Breath independent shuffle sequence')
  same(R.snapshot(s.shuffleRng),sample.after,'Deep Breath complete shuffle owner')
  same(ids(s.hand),sample.hand,'source drawn UID order');same(ids(s.draw),sample.draw,'source remaining UID order');same(ids(s.discard),sample.discard,'source discard UID order')
  assert(callbacks.uncommon==sample.hooks and callbacks.shop==sample.hooks,'onShuffle exactly once only for EmptyDeck action')
  assert(s.relicCounters.sundial==sample.sundial and s.energy==sample.energy and s.player.block==sample.block,'actual Sundial/Abacus effects')
  local seen={};for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do assert(not seen[c.uid] and cards[c.uid]==c,'same actual object once');seen[c.uid]=true end end
  for uid=1,7 do assert(seen[uid],'all actual objects conserved')end
  assert(not s.pendingChoice and not s.cardActions and not s.cardInUse,'fully drained')
  R.shuffle,R.randomLongHex,U.onShuffle,Shop.onShuffle=rawShuffle,rawLong,rawU,rawShop
 end
 print('DEEP_BREATH_SOURCE_PASS '..samples[1].seed..' cases='..#samples)
end
