package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Trace=dofile('tests/lua/support/presentation_trace.lua')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function rejects(fn,needle)
 local ok,why=pcall(fn);assert(not ok and tostring(why):find(needle,1,true),tostring(why))
end
local trace=Trace.new()
local cursor=F.control({name='hit',kind='cursorArea'})
trace:attach(cursor,'root/battlePanel/drawIcon/hit')
assert(cursor.unsetField==nil,'function __index must retain its real missing-field behavior')
rejects(function()return cursor.interactable end,'CursorArea')
rejects(function()cursor.interactable=false end,'CursorArea')
rejects(function()return cursor.activeInHierarchy end,'activeInHierarchy')
rejects(function()cursor.activeInHierarchy=false end,'activeInHierarchy')
assert(rawget(cursor,'kind')=='cursorArea','tracing must not remove the strict factory type discriminator')
cursor.raycastTarget=false
local expected=Trace.new();expected:add({'root/battlePanel/drawIcon/hit','interactable',false})
assert(trace.count==expected.count and trace.hash==expected.hash,'only the reviewed pile field has the legacy trace key')

local preset=F.control({name='confirm',kind='presetButton'})
trace:attach(preset,'root/choicePanel/confirm/hit')
preset.interactable=false;preset.raycastTarget=false
expected:add({'root/choicePanel/confirm/hit','interactable',false})
assert(trace.count==expected.count and trace.hash==expected.hash,'mirrored native raycast writes invert only the P0 field addition')
trace:assertNativeInteraction()
preset.raycastTarget=true
rejects(function()trace:assertNativeInteraction()end,'native button gates diverged')
preset.raycastTarget=false;trace:assertNativeInteraction()

local other=F.control({name='hit',kind='cursorArea'})
trace:attach(other,'root/unrelated/hit');other.raycastTarget=false
expected:add({'root/unrelated/hit','raycastTarget',false})
assert(trace.count==expected.count and trace.hash==expected.hash,'unrelated native fields must remain in the original ordered trace')
local legacy=setmetatable({children={}}, {__index={inherited='legacy-table'}})
trace:attach(legacy,'legacy');assert(legacy.inherited=='legacy-table')
cursor.raycastTarget=true
expected:add({'root/battlePanel/drawIcon/hit','interactable',true})
assert(trace.count==expected.count and trace.hash==expected.hash,'later writes cannot bypass the recorder through raw fields')
print('PRESENTATION_TRACE_NATIVE_PASS strict delegation and exact P0 inverse')
