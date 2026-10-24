package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run');local C=require('abyss_combat')
local function settle(ui)
 for _=1,500 do ui:update(.05);if not ui.battleUI.busy then break end end
 ui:refresh();ui:update(0)
 if ui.deckUI.visible then local g=ui.deckUI.root:GetChild('grid');g:flush();ui:update(0);g:flush() end
end
local function setup(ids,discard,draw,exhaust)
 local ui,root=F.fixture();ui:start();assert(ui.mapUI:choose(F.Nodes.available(ui.run,ui.map)[1].id));local s=ui.run.combat
 s.hand={};s.draw={};s.discard={};s.exhaust={};s.nextUid=101;s.energy=10
 local function add(p,values) for _,v in ipairs(values or {}) do p[#p+1]={uid=s.nextUid,cardId=type(v)=='table' and v[1] or v,upgraded=type(v)=='table' and v[2] or false};s.nextUid=s.nextUid+1 end end
 add(s.hand,ids);add(s.discard,discard);add(s.draw,draw);add(s.exhaust,exhaust)
 ui:refresh();return ui,root,s
end
local function actualPlay(ui,root,target)
 F.click(root,'battlePanel','card1');F.click(root,'battlePanel',target and 'enemy1' or 'playArea');settle(ui)
end
local function equal(a,b,seen)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 seen=seen or {};if seen[a]==b then return true end;seen[a]=b
 for k,v in pairs(a) do if not equal(v,b[k],seen) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local tests={
 {'armaments',{'armaments','strike','defend'},nil,nil,nil,false,'upgradeHand'},
 {'true_grit+',{{'true_grit',true},'strike','defend'},nil,nil,nil,false,'exhaustChoose'},
 {'burning_pact',{'burning_pact','strike','defend'},nil,{'anger','strike'},nil,false,'exhaustChoose'},
 {'headbutt',{'headbutt'},{'strike','defend'},nil,nil,true,'discardToDraw'},
 {'warcry',{'warcry','defend'},nil,{'strike','anger'},nil,false,'handToDraw'},
 {'dual_wield',{'dual_wield','strike','inflame','defend'},nil,nil,nil,false,'dualWield'},
 {'exhume',{'exhume'},nil,nil,{'strike','defend','exhume'},false,'recoverExhaust'},
}
for _,t in ipairs(tests) do
 local ui,root,s=setup(t[2],t[3],t[4],t[5]);actualPlay(ui,root,t[6]);local p=assert(s.pendingChoice,t[1]..' missing choice')
 assert(p.op==t[7]);assert(ui.deckUI.visible and not ui.battleUI.active)
 local before=C.copy(s)
 for _,bad in ipairs({{}, {token=p.token}, {uid=p.uids[1]}, {token=p.token+1,uid=p.uids[1]}, {token=p.token,uid=99999}, {token='bad',uid=p.uids[1]}, {token=p.token,uid={}}}) do
  local ok,reason=Run.chooseCard(ui.run,bad.token,bad.uid);assert(not ok);assert(equal(s,before),'invalid choice mutated '..t[1]);print('ATOMIC '..t[1]..' '..reason)
 end
 local grid=root:GetChild('deckPanel'):GetChild('grid');local count=grid.itemCount;local uid=p.uids[1]
 grid.items[0].click();settle(ui);assert(not s.pendingChoice and not ui.deckUI.visible and ui.battleUI.active)
 print('PASS_UI '..t[1]..' options='..count..' selected='..uid..' energy='..s.energy)
end
