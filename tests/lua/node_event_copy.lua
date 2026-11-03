package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Copy=require('abyss_copy')
local Combat=require('abyss_combat')
assert(Combat.copy==Copy.copy,'legacy public copy API identity')
local names={'abyss_node_ui_camp','abyss_node_ui_rewards','abyss_drug_dealer_event'}
-- Warm real transitive dependencies; observe only each module's own imports.
for _,name in ipairs(names)do require(name)end
local originalRequire=require
local modules={}
for _,name in ipairs(names)do
 local imports={}
 local env=setmetatable({require=function(id)
  imports[id]=true
  assert(id~='abyss_combat','[COPY_DEPENDENCY] '..name..' directly imports combat')
  return originalRequire(id)
 end},{__index=_G})
 modules[name]=assert(loadfile('src/lua/'..name..'.lua','t',env))()
 assert(imports.abyss_copy,'[COPY_DEPENDENCY] pure copy owner required')
end
local shared={value=7}
local card={uid=1,cardId='strike',upgraded=false,a=shared,b=shared}
card.self=card
local function detached(clone)
 assert(clone~=card and clone.self==clone and clone.a==clone.b and clone.a~=shared,'[COPY_GRAPH] aliases/cycles/isolation')
 assert(clone.a.value==7 and card.upgraded==false and shared.value==7,'[COPY_GRAPH] values/source')
end
local drug=modules.abyss_drug_dealer_event
local run={deck={card,{uid=2,cardId='Necronomicurse'}},data={cards={cards={}}},miscRng={counter=9}}
local cards=drug.transformCards(run)
assert(#cards==1 and cards[1].uid==1);detached(cards[1]);assert(run.miscRng.counter==9)
local ctx={self={run=run,selected=1}}
modules.abyss_node_ui_rewards.install(ctx)
ctx.syncDuplicatorPicker({event={copyCards={card}}});detached(ctx.self.removeRows[1])
ctx.syncAct2PurgePicker({event={id='beggar',purgeCards={card}}});detached(ctx.self.removeRows[1])
ctx.syncLibraryPicker({event={offers={card}}});detached(ctx.self.offerRows[1])
ctx.syncNeowPicker({type='event',event={id='neow',stage='neow_choose_card',purgeCards={card}}},true)
detached(ctx.self.removeRows[1]);detached(ctx.self.upgradeRows[1])
assert(ctx.self.removeRows[1]~=ctx.self.upgradeRows[1],'independent copy calls stay independent')
local function control()
 local c={children={}}
 function c:GetChild(name)if not self.children[name]then self.children[name]=control()end;return self.children[name]end
 function c:SetAnchoredPosition(...)end
 function c:SetSizeDelta(...)end
 function c:SetLocalScale(...)end
 return c
end
local owner={run=run,upgradeRows={card},selected=1,visible=true,picker='upgrade'}
local root=control();local preview
local ui={child=function()return root end,show=function()end,state=function()end,action=function()end,
 fillCard=function(_,_,_,look)if look.inspectOnly and look.instance.upgraded then preview=look.instance end end}
local camp=modules.abyss_node_ui_camp.new(owner,ui)
camp:render({upgradeCards={card}})
detached(owner.upgradeRows[1]);detached(preview)
assert(preview.upgraded and preview.upgrades==1 and not card.upgraded,'preview is read only')
assert(Combat.copy==Copy.copy,'legacy API remains unchanged after real callers')
print('NODE_EVENT_COPY_PASS 3 direct owners; graph identity/cycles; camp/pickers/drug; unchanged legacy API')
