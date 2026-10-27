local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Narrative=require('abyss_narrative')
local Snapshot=dofile('tests/lua/support/ui_readability_snapshot.lua')
local original=Narrative.releaseNotes
local count=0
local function test(name,fn)fn();count=count+1;print('ok release notes '..count..' - '..name)end
local function notes(history,current,dirty)
    -- Fake source identity and notices exist ONLY in this test fixture; no fixture
    -- is a claim that a production version was actually published.
    Narrative.releaseNotes={schemaVersion=1,build={version='v0.1.0',sourceCommit=string.rep('a',40),sourceDirty=dirty==true,workKey='fixture-only'},history=history or {},currentNotice=current}
end
local function hit(root,name)
    return root:GetChild('releaseNotesPanel'):GetChild(name):GetChild('hit')
end
local function text(root,name)return root:GetChild('releaseNotesPanel'):GetChild(name).text end
local function entry(root)return root:GetChild('menuPanel'):GetChild('releaseNotes'):GetChild('hit')end
local function page(root)
    local out={};for i=1,F.Theme.layout.releaseNotes.rows do local value=text(root,'row'..i);if value~='' then out[#out+1]=value end end
    return out
end
local function same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for key,value in pairs(a)do if not same(value,b[key])then return false end end
    for key in pairs(b)do if a[key]==nil then return false end end
    return true
end
local function fake(version,date,added,improved,fixed)
    return {version=version,publishedDate=date,sourceCommit=string.rep('b',40),added=added or {},improved=improved or {},fixed=fixed or {}}
end
local pointer={CursorDown='down',CursorUp='up',CursorEndDrag='end',CursorExit='exit'}
local function tap(control,id)
    local event=id and {touchId=id} or nil
    control.listeners.down(event);control.listeners.up(event);return control.click(event)
end

test('empty baseline is honest, manual-only, ownerless and has no gameplay state',function()
    notes()
    local ui,root=F.fixture()
    assert(ui.mode=='menu' and not ui.releaseNotesUI.visible and ui.run==nil)
    assert(root:GetChild('menuPanel'):GetChild('releaseNotes').visible)
    assert(root:GetChild('menuPanel'):GetChild('codeVersion').text=='代码版本 v0.1.0 · 来源 aaaaaaa')
    ui:update(10);ui:refresh();assert(not ui.releaseNotesUI.visible,'no automatic popup')
    assert(entry(root).click() and ui.releaseNotesUI.visible and ui.run==nil)
    assert(text(root,'row1')=='暂无已确认的发布记录')
    assert(text(root,'row2')=='当前为代码基线，暂无随附版本说明')
    assert(text(root,'date')=='' and text(root,'page')=='第 1 / 1 页')
    Snapshot.capture('notice-empty',root,F.Layout)
    assert(not root:GetChild('releaseNotesPanel'):GetChild('current').visible)
    assert(not ui:start() and not ui:openExit() and not ui:openDeck() and not ui:openPotions())
    assert(not root:GetChild('exitEntry').visible,'shared exit must not sit above notice')
    assert(root:GetChild('releaseNotesPanel'):GetChild('blocker').click())
    assert(hit(root,'close').click() and ui.mode=='menu' and ui.run==nil)
    assert(not ui.releaseNotesUI.visible and root:GetChild('menuPanel'):GetChild('releaseNotes').visible)
    assert(ui:start() and ui.mode=='map' and not ui.releaseNotesUI:open())
    assert(not root:GetChild('menuPanel'):GetChild('releaseNotes').visible)
    assert(not root:GetChild('menuPanel'):GetChild('codeVersion').visible)
    local run,map=F.Combat.copy(ui.run),F.Combat.copy(ui.map)
    entry(root).click();hit(root,'next').click();hit(root,'close').click()
    assert(same(run,ui.run) and same(map,ui.map),'unavailable notice actions cannot change rules or RNG')
    ui.run.phase='defeat';ui:refresh()
    assert(not root:GetChild('menuPanel'):GetChild('releaseNotes').visible and not ui.releaseNotesUI:open(),'no result-page entry')
    ui.run.phase='victory';ui.run.nodeFlow={complete=true,result='boss_treasure_complete'};ui:refresh()
    assert(not root:GetChild('menuPanel'):GetChild('releaseNotes').visible and not ui.releaseNotesUI:open())
    Narrative.releaseNotes={build={version='v0.1.0'},history={}}
    local unknown,unknownRoot=F.fixture()
    assert(unknownRoot:GetChild('menuPanel'):GetChild('codeVersion').text=='代码版本 v0.1.0 · 来源 未知')
    assert(unknown.releaseNotesUI:open() and text(unknownRoot,'build')=='代码版本 v0.1.0 · 来源 未知')
end)

test('latest confirmed history is default and version navigation resets complete content pages',function()
    local many={};for i=1,16 do many[i]='测试虚构新增条目'..i end
    local recent=fake('v9.9.2','2099-12-31',many,{'测试虚构优化'}, {'测试虚构修复'})
    local older=fake('v9.9.1','2099-12-30',{}, {'测试虚构旧版优化'})
    notes({recent,older},{version='v0.1.0',notesDate='2099-12-31',added={'测试虚构候选内容'},improved={},fixed={}})
    local ui,root=F.fixture()
    assert(entry(root).click() and text(root,'version')=='v9.9.2')
    assert(text(root,'date')=='发布日期 2099-12-31 · 发布记录 1 / 2')
    Snapshot.capture('notice-history',root,F.Layout)
    assert(not hit(root,'newer').interactable and hit(root,'older').interactable)
    local actual=page(root)
    while hit(root,'next').interactable do
        assert(hit(root,'next').click());for _,line in ipairs(page(root))do actual[#actual+1]=line end
    end
    assert(#actual==18 and text(root,'page')=='第 3 / 3 页')
    for i=1,16 do assert(actual[i]=='新增 · '..many[i])end
    assert(actual[17]=='优化 · 测试虚构优化' and actual[18]=='修复 · 测试虚构修复')
    assert(not hit(root,'next').click(),'end of content must not wrap')
    assert(hit(root,'older').click() and text(root,'version')=='v9.9.1' and text(root,'page')=='第 1 / 1 页')
    assert(text(root,'row1')=='优化 · 测试虚构旧版优化' and text(root,'row2')=='','empty sections omitted')
    assert(hit(root,'newer').click() and text(root,'row1')=='新增 · '..many[1])
    assert(hit(root,'next').click() and hit(root,'previous').click())
    assert(hit(root,'close').click() and entry(root).click())
    assert(text(root,'version')=='v9.9.2' and text(root,'page')=='第 1 / 3 页','reopen resets to actual latest')
end)

test('prepared current notice is separate, never published history, with honest date and dirty source',function()
    local current={version='v0.1.0',notesDate='2099-12-31',added={'测试虚构候选内容'},improved={},fixed={}}
    notes({},current,true)
    local ui,root=F.fixture()
    assert(entry(root).click() and ui.releaseNotesUI.view=='current' and text(root,'version')=='v0.1.0')
    assert(not hit(root,'current').click(),'already selected current notice is not a second action')
    assert(text(root,'date')=='说明日期 2099-12-31 · 本次版本说明，不代表已发布')
    assert(text(root,'row1')=='新增 · 测试虚构候选内容')
    Snapshot.capture('notice-current',root,F.Layout)
    assert(text(root,'build')=='代码版本 v0.1.0 · 来源 aaaaaaa · 本地修改')
    assert(not root:GetChild('releaseNotesPanel'):GetChild('older').visible)
    assert(hit(root,'history').click() and text(root,'row1')=='暂无已确认的发布记录')
    assert(hit(root,'close').click() and entry(root).click() and ui.releaseNotesUI.view=='current','without any published history reopen defaults to the clearly labeled bundle notes')
end)

test('pointer ownership expires across pages, versions, resize, close/reopen and foreign touch',function()
    notes({fake('v9.9.2','2099-12-31',{'测试1','测试2','测试3','测试4','测试5','测试6','测试7','测试8'}),fake('v9.9.1','2099-12-30',{'测试旧版'})})
    local ui,root=F.fixture(nil,nil,nil,pointer)
    assert(not entry(root).click(),'pointer-capable entry requires fresh Down/Up even for ownerless mouse Click')
    assert(tap(entry(root),11))
    local next=hit(root,'next')
    next.listeners.down({touchId=11});next.listeners.up({touchId=22});assert(not next.click({touchId=22}))
    next.listeners.up({touchId=11});assert(next.click({touchId=11}) and ui.releaseNotesUI.page==2)
    assert(not next.click({touchId=11}),'duplicate release cannot turn twice')
    local close=hit(root,'close')
    close.listeners.down();close.listeners.up();assert(tap(hit(root,'previous')))
    assert(not close.click(),'page change expires a previously released close')
    close.listeners.down();ui:resize(1920,1080);close.listeners.up();assert(not close.click())
    assert(tap(close) and tap(entry(root)))
    next.listeners.down();next.listeners.up();assert(tap(hit(root,'older')))
    assert(not next.click() and text(root,'version')=='v9.9.1','version change expires released page action')
    close.listeners.down();assert(ui.releaseNotesUI:close());assert(tap(entry(root)))
    close.listeners.up();assert(not close.click() and ui.releaseNotesUI.visible)
    close.listeners.down({touchId=11});close.listeners.exit({touchId=22});close.listeners.up({touchId=11})
    assert(close.click({touchId=11}),'foreign exit must not cancel owner')
end)

test('notice seals source menu gestures and cannot reopen underneath exit or character overlays',function()
    notes()
    local ui,root=F.fixture(nil,nil,nil,pointer)
    local start=root:GetChild('menuPanel'):GetChild('start'):GetChild('hit')
    start.listeners.down();start.listeners.up();assert(tap(entry(root)))
    assert(not start.click() and not ui.run)
    assert(tap(hit(root,'close')))
    assert(not start.click() and not ui.run,'old source-menu release retired')
    assert(not start.click(),'ownerless source-menu fallback cannot revive after the modal')
    assert(tap(start) and ui.run and ui.mode=='map')
    local ui2,root2=F.fixture(nil,nil,nil,pointer)
    local start2=root2:GetChild('menuPanel'):GetChild('start'):GetChild('hit')
    assert(ui2.releaseNotesUI:open() and ui2.releaseNotesUI:close())
    assert(not start2.click() and not ui2.run,'even an unobserved source control is sealed')
    assert(ui2:openExit() and not root2:GetChild('menuPanel'):GetChild('releaseNotes').visible)
    assert(not tap(entry(root2)) and not ui2.releaseNotesUI.visible)
    assert(ui2:closeExit() and tap(entry(root2)))
    ui2:disable();assert(not ui2.releaseNotesUI.visible and not tap(entry(root2)))
    local canvas=F.control({children=F.Layout})
    local root3=F.Viewport.apply(canvas,1280,720)
    local ui3=F.GameUI.new(root3,F.Data,F.Presentation,'click',{seed=1,imageSource='static',
        color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,cursorEvents=pointer,prologue=false,originalCharacters=true})
    assert(ui3:start() and ui3.characterOpen)
    assert(not root3:GetChild('menuPanel'):GetChild('releaseNotes').visible and not tap(entry(root3)))
    assert(ui3:closeCharacters() and tap(entry(root3)))
    assert(not ui3:start('traveler') and not ui3.characterOpen,'notice blocks direct character selection too')
end)

test('long Unicode prose wraps and paginates without losing any codepoint',function()
    local long=string.rep('测试中文🪨版本说明',80)..'收尾'
    notes({fake('v9.9.1','2099-12-30',{long})})
    local ui,root=F.fixture()
    assert(entry(root).click())
    local chunks={}
    Snapshot.capture('notice-long',root,F.Layout)
    repeat
        for _,line in ipairs(page(root))do
            assert(utf8.len(line)<=F.Theme.layout.releaseNotes.rowCharacters)
            chunks[#chunks+1]=line:gsub('^新增 · ',''):gsub('^　','')
        end
        if not hit(root,'next').interactable then break end
        assert(hit(root,'next').click())
    until false
    assert(#chunks>F.Theme.layout.releaseNotes.rows and table.concat(chunks)==long,'every original Unicode codepoint must survive pagination')
end)

test('controller isolates focus, cancels to the originating menu entry and rejects synthetic Click',function()
    notes({fake('v9.9.1','2099-12-30',{'测试虚构历史'})},{version='v0.1.0',notesDate='2099-12-31',added={'测试虚构候选'},improved={},fixed={}})
    local focus
    local api={events={Confirm='confirm',Cancel='cancel'},directions={Left='left',Right='right'},modes={Specified='specified'},
        getFocus=function()return focus end,setFocus=function(value)focus=value end,isController=function()return true end}
    local ui,root=F.fixture(nil,nil,nil,pointer,false,nil,nil,api)
    assert(focus==root:GetChild('menuPanel'):GetChild('start'):GetChild('hit'))
    focus=entry(root);ui:update(0);assert(focus.navigationListeners.confirm())
    assert(ui.controller.scope=='releaseNotes' and focus==hit(root,'close'))
    assert(not entry(root).canControllerFocus and not root:GetChild('menuPanel'):GetChild('start'):GetChild('hit').canControllerFocus)
    assert(not root:GetChild('exitEntry'):GetChild('open'):GetChild('hit').canControllerFocus)
    assert(not hit(root,'close').click(),'native synthetic click after Confirm cannot close immediately')
    ui:update(0);focus=hit(root,'current');assert(focus.navigationListeners.confirm())
    assert(ui.releaseNotesUI.view=='current')
    ui:update(0);assert(focus.navigationListeners.cancel())
    assert(not ui.releaseNotesUI.visible and ui.controller.scope=='menu' and focus==entry(root))
end)
Narrative.releaseNotes=original
print('LUA_GAME_UI_RELEASE_NOTES_PASS '..count)
