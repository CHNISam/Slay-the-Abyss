local F=dofile('tests/lua/support/toxic_egg_fixture.lua')
local U=dofile('tests/lua/support/game_ui_fixture.lua');local UI=require('abyss_node_ui')
local function spec(list,name)for _,v in ipairs(list)do if v.name==name then return v end;local found=v.children and spec(v.children,name);if found then return found end end end
local function bind(r,m)
 local root=U.control(spec(U.Layout,'nodePanel'));local p=require('abyss_character_presentation').prepare(U.Presentation,r.data)
 local ui=UI.new(root,r,m,p,'click',nil,{cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'},color=function(...)return{...}end,imageSource='static'})
 local function get(path)local v=root;for k in path:gmatch('[^/]+')do v=assert(v:GetChild(k),path)end;return v end
 ui:setVisible(true);return ui,get,p
end
do
 local r=F.Run.new(F.D,42);assert(F.Run.obtainRelic(r,'Toxic Egg 2'));F.Run.gainGold(r,1000);local m=F.enter(r,'shop');local ui,get,p=bind(r,m)
 local c=r.nodeFlow.cards[3];assert(c.upgraded);assert(get('shopView/card3/name').text:find('＋',1,true))
 local def=F.definition(r,c.id);F.eq(get('shopView/card3/cost').text,tostring(def.upgrade.cost or def.cost))
 local body=require('abyss_card_display').permanentText(p[c.id],def,c);F.eq(get('shopView/card3/description').text,body)
 assert(ui.actions['shopView/card3'].enabled);local old=ui.actions['shopView/card3'].handler;ui:render();local before=F.C.copy(r);F.eq(old(),false);F.same(r,before)
end
do
 local r=F.Run.new(F.D,42);assert(F.Run.obtainRelic(r,'Toxic Egg 2'));assert(F.Run.obtainRelic(r,'Dream Catcher'));local m=F.enter(r,'camp');local ui,get=bind(r,m)
 assert(ui:press('campView/rest'));local reward=r.nodeFlow.restReward;local slot
 for i,id in ipairs(reward.cards)do if F.definition(r,id).type=='skill'then slot=i end end;assert(slot)
 assert(get('pickerView/card'..slot..'/name').text:find('＋',1,true));assert(ui:press('pickerView/card'..slot));assert(ui:press('confirm'))
 F.eq(r.deck[#r.deck].upgraded,true)
end
print('TOXIC_EGG_UI_PASS real NodeUI shop/rest titles cost rules, real picker acquire and stale shelf callback')
