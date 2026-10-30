local F=dofile('tests/lua/support/game_ui_fixture.lua')
local h,root=F.fixture()
assert(F.start(h))
local panel=root:GetChild('deckPanel')
local before=F.Combat.copy(h.run)
local function same(a,b)
 if type(a)~='table' or type(b)~='table' then assert(a==b);return end
 for k,v in pairs(a)do assert(b[k]~=nil);same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
for _,setting in ipairs({{}, {value=false}, {value=true}})do
 h.deckUI.browseEnabled=setting.value
 assert(h.deckUI:inspectText(h.run,'Inspector','Original complete detail text'))
 assert(panel:GetChild('title').visible==true)
 assert(panel:GetChild('browseTitle').visible==false and panel:GetChild('sort').visible==false)
 assert(h.deckUI:close())
 same(h.run,before)
end
assert(h:openDeck())
assert(panel:GetChild('browseTitle').visible==true and panel:GetChild('sort').visible==true)
assert(h:closeDeck())
same(h.run,before)
print('DECK_INSPECTOR_VISIBILITY_PASS nil false true and normal browse')
