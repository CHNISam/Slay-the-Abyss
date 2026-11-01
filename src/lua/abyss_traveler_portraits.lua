--[=[
MIT License

Copyright (c) 2026 LiuL

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]=]
-- Two frozen Lumine hosts only. No rules, timers, fitting or original OnStart.
-- Property order follows Primitive's MIT runtime, copyright 2026 LiuL.
local M = {}
local owners = setmetatable({}, {__mode='k'})
local CANCELLED = {}
local function integer(n) return type(n)=='number' and n>0 and n<math.huge and n%1==0 end
-- Breakthrough low-poly rows: 20 fields, official primitive/sprite IDs, rotX/rotY squash.
local function lowpoly(data)
    return type(data)=='table' and data.renderProfile=='lowpoly-v1' and integer(data.width) and integer(data.height)
        and integer(data.count) and data.count<=2304 and #data.rows==data.count and type(data.jsonSha256)=='string'
end
local function validate(data, width, count, source, json)
    local compact=data.renderProfile=='compact-v1' or data.renderProfile=='selection-budget-v1'
    local expected=compact and data.count or count
    assert(type(data)=='table' and data.width==width and expected>0 and expected<=(compact and 2304 or count) and #data.rows==expected
        and data.sourceSha256==source and data.jsonSha256==json,'unexpected frozen portrait data')
    local r=data.root
    assert(#r==13 and r[1]==0 and r[2]==0 and r[3]==width and r[4]==width and r[5]==.5 and r[6]==.5
        and r[7]==.5 and r[8]==.5 and r[9]==.5 and r[10]==.5 and r[11]==1 and r[12]==1 and r[13]==0,'unexpected portrait ROOT')
end
local function controller(host, data, display, templates, options)
    local Asset=templates or require('abyss_traveler_portrait_assets')
    local retryFailedOnPause=type(options)=='table' and options.retryFailedOnPause==true
    assert(host,'missing dedicated portrait host')
    local self,created={},{}
    local phase,generation,nextIndex='idle',0,1
    local page,group,pageIndex,groupIndex=nil,nil,0,0
    local revealGroups,revealIndex,revealedPages={},1,{}
    local working,pending,hiding=false,false,false
    local reason,cleanupFailures=nil,0
    local function current(token)return (phase=='building' or phase=='revealing') and generation==token and host.alive~=false end
    local function check(token)if not current(token)then error(CANCELLED,0)end end
    local function hide()
        if phase=='destroyed' or host.alive==false or hiding then return true end
        hiding=true;local ok,result=pcall(host.SetVisible,host,false);hiding=false
        if not ok or result==false then reason=ok and 'host hide rejected' or tostring(result);return false end
        return true
    end
    local function cleanup()
        local old,retained,blocked=created,{},{};created={};cleanupFailures=0
        for i=#old,1,-1 do
            if phase=='destroyed'then created={};return true end
            local node=old[i];local c=node.control
            if c.alive~=false then
                local ok,result=true,true
                if not blocked[c]then ok,result=pcall(game.DestroyClientUIControl,c)end
                if blocked[c] or not ok or result==false then
                    if not blocked[c]then cleanupFailures=cleanupFailures+1;reason=ok and 'destroy rejected' or tostring(result)end
                    if c.alive~=false then retained[#retained+1]=node;blocked[node.parent]=true end
                end
            end
        end
        for i=#retained,1,-1 do created[#created+1]=retained[i]end
        pending=false
        if #created>0 then phase='release_failed';return false end
        return cleanupFailures==0
    end
    local function fail(err)
        if phase=='destroyed'then created={};return end
        phase='failed';generation=generation+1;reason=tostring(err);hide();cleanup()
    end
    local function call(token,c,name,...)
        check(token);assert(type(c[name])=='function','missing native method '..name)
        assert(c[name](c,...)~=false,'native method rejected '..name);check(token)
    end
    local function transform(token,c)
        call(token,c,'SetAnchorMin',.5,.5);call(token,c,'SetAnchorMax',.5,.5);call(token,c,'SetPivot',.5,.5)
        call(token,c,'SetSizeDelta',data.width,data.height or data.width);call(token,c,'SetLocalScale',1,1,1)
        call(token,c,'SetLocalRotation',0,0,0);call(token,c,'SetAnchoredPosition',0,0)
    end
    local function create(token,prefab,parent)
        local c=game.InstantiateClientUIControl(prefab,parent)
        if c then created[#created+1]={control=c,parent=parent}end
        check(token);assert(c,'portrait template unavailable');call(token,c,'SetVisible',false)
        return c
    end
    local function image(token,c,r)
        local tri=data.renderProfile=='lowpoly-v1'
        assert(tri and #r==20 and integer(r[1]) or #r==18 and r[1]==100001,'unexpected portrait image row')
        if data.renderProfile=='compact-v1' or data.rectanglesOnly then
            -- Shared template supplies the white image and identity transforms.
            c.imageType=Enum.ImageType.Stretch;check(token)
            call(token,c,'SetSizeDelta',r[4],r[5]);call(token,c,'SetAnchoredPosition',r[2],r[3])
            c.imageColor=Color.FromRGBA(r[15],r[16],r[17],r[18]);check(token)
            call(token,c,'SetVisible',true);return
        end
        call(token,c,'SetImage',Enum.ImageSource.StaticReference,r[1])
        c.imageType=Enum.ImageType.Stretch;check(token);assert(c.imageType==Enum.ImageType.Stretch,'imageType rejected')
        call(token,c,'SetAnchorMin',r[8],r[9]);call(token,c,'SetAnchorMax',r[10],r[11]);call(token,c,'SetPivot',r[6],r[7])
        call(token,c,'SetSizeDelta',r[4],r[5]);call(token,c,'SetLocalScale',r[12],r[13],1)
        call(token,c,'SetLocalRotation',tri and r[19] or 0,tri and r[20] or 0,r[14]);call(token,c,'SetAnchoredPosition',r[2],r[3])
        c.imageColor=Color.FromRGBA(r[15],r[16],r[17],r[18]);check(token)
        call(token,c,'SetAsLastSibling');call(token,c,'SetActive',true);call(token,c,'SetVisible',true)
    end
    function self.status(_)
        return {phase=phase,generation=generation,nextIndex=nextIndex,total=#data.rows,owned=#created,
            retained=phase=='release_failed' and #created or 0,reason=reason,cleanupFailures=cleanupFailures}
    end
    function self.begin(_)
        if working or phase=='destroyed' or phase=='failed' or phase=='release_failed'then return false end
        if host.alive==false then self:destroy();return false end
        if phase=='building' or phase=='revealing' or phase=='ready'then
            if data.cache or data.renderProfile=='compact-v1' then host:SetActive(true);host:SetVisible(phase~='building')end
            return true
        end
        if not integer(Asset.imagePrefabId) or not integer(Asset.containerPrefabId)
            or Asset.imagePrefabId==100001 or Asset.containerPrefabId==100001 then fail('unbound portrait templateIndex');return false end
        generation=generation+1;phase='building';nextIndex=1;pageIndex=0;groupIndex=0;page=nil;group=nil;reason=nil
        revealGroups={};revealIndex=1;revealedPages={}
        local token=generation;working=true
        local ok,err=pcall(function()
            call(token,host,'SetVisible',false);call(token,host,'SetActive',true)
            call(token,host,'SetAnchorMin',.5,.5);call(token,host,'SetAnchorMax',.5,.5);call(token,host,'SetPivot',.5,.5)
            call(token,host,'SetSizeDelta',data.width,data.height or data.width)
            call(token,host,'SetLocalScale',display/data.width,display/data.width,1);call(token,host,'SetLocalRotation',0,0,0)
            -- Keep the dedicated slot position; never import ROOT offsets into the shared hero/button.
        end)
        if not ok and err~=CANCELLED then fail(err)end
        if pending then cleanup()end;working=false
        return ok and current(token)
    end
    -- Exactly one native creation attempt. The owner shares 64 across BOTH hosts.
    function self.step(_)
        if host.alive==false then self:destroy()end
        if working or (phase~='building' and phase~='revealing')then return false end
        local token=generation;working=true
        if phase=='revealing' then
            local ok,err=pcall(function()
                for _=1,4 do
                    local entry=revealGroups[revealIndex]
                    if not entry then phase='ready';break end
                    if not revealedPages[entry.page] then
                        call(token,entry.page,'SetVisible',true);call(token,entry.page,'SetActive',true);revealedPages[entry.page]=true
                    end
                    call(token,entry.control,'SetVisible',true);call(token,entry.control,'SetActive',true)
                    revealIndex=revealIndex+1
                end
                if revealIndex>#revealGroups then phase='ready'end
            end)
            if not ok and err~=CANCELLED then fail(err)end
            if pending then cleanup()end;working=false;return ok,'reveal'
        end
        local ok,err=pcall(function()
            local p=math.floor((nextIndex-1)/3600)+1;local g=math.floor((nextIndex-1)/60)+1
            if pageIndex~=p then
                page=create(token,Asset.containerPrefabId,host);transform(token,page);pageIndex=p
                call(token,page,'SetActive',not data.runtimeV2);call(token,page,'SetVisible',not data.runtimeV2)
            elseif groupIndex~=g then
                group=create(token,Asset.containerPrefabId,page);transform(token,group);groupIndex=g
                call(token,group,'SetActive',not data.runtimeV2);call(token,group,'SetVisible',not data.runtimeV2)
                if data.runtimeV2 then revealGroups[#revealGroups+1]={control=group,page=page}end
            else
                local c=create(token,Asset.imagePrefabId,group);image(token,c,data.rows[nextIndex]);nextIndex=nextIndex+1
                if nextIndex>#data.rows then call(token,host,'SetVisible',true);phase=data.runtimeV2 and 'revealing' or 'ready'end
            end
        end)
        if not ok and err~=CANCELLED then fail(err)end
        if phase=='destroyed'then created={} elseif pending then cleanup()end
        working=false;return true
    end
    function self.pause(_)
        -- Only the battle portrait opts into scene-boundary failure recovery.
        -- Other cached adapters retain their explicit-release retry policy.
        if retryFailedOnPause and (phase=='failed' or phase=='release_failed')then return self:release()end
        if not data.cache and data.renderProfile~='compact-v1' then return self:release()end
        if phase=='destroyed' or host.alive==false then return false end
        host:SetVisible(false);host:SetActive(false);return true
    end
    function self.release(_)
        if phase=='destroyed'then return true end
        if pending then return true end
        local wasWorking=working;working=true;generation=generation+1;phase='released';pending=true
        local hidden=hide();if wasWorking then return hidden end
        local cleaned=cleanup();working=false;return hidden and cleaned
    end
    function self.pose(_,x,y,sx,sy)
        if host.alive==false then self:destroy();return end
        if working or (phase~='building' and phase~='ready')then return end
        working=true
        local ok,err=pcall(function()
            assert(host:SetAnchoredPosition(x,y)~=false,'portrait pose rejected')
            if host.alive==false then self:destroy();return end
            if phase=='building' or phase=='ready'then assert(host:SetLocalScale(sx*display/data.width,sy*display/data.width,1)~=false,'portrait scale rejected')end
        end)
        if not ok then fail(err)end
        if phase=='destroyed'then created={} elseif pending then cleanup()end
        working=false
    end
    function self.destroy(_)generation=generation+1;phase='destroyed';pending=false;created={}end
    return self
end
local function activeTargets(mode,characterOpen,stopped,character,preloadSelection)
    if stopped then return {}end
    local choosing=characterOpen==true
    local warm=preloadSelection==true and mode=='menu' and not choosing
    local selection=warm or choosing and character=='ironclad'
    return {avatar=choosing or warm,battle=mode=='battle' and character=='ironclad',selection=selection,cardFan=selection,
        selectScene=choosing or warm,battleScene=mode=='battle',menuScene=mode=='menu' and not choosing}
end
-- cardTemplates: ready-card image/container template indices, used when only the cards flag is on.
function M.new(stage,report,flags,cardTemplates)
    local selecting=type(flags)=='table' and flags.selectionAvatar==true
    local fighting=type(flags)=='table' and flags.battlePortrait==true
    local carding=type(flags)=='table' and flags.cards==true
    local landing=type(flags)=='table' and flags.menuBackground==true
    if not selecting and not fighting and not carding and not landing then return nil end
    if owners[stage]then return owners[stage]end
    local Asset=require('abyss_traveler_portrait_assets')
    if carding and not lowpoly(Asset.lowpolyCardFan) then carding=false end
    if landing and not lowpoly(Asset.lowpolyLand) then landing=false end
    if not selecting and not fighting and not carding and not landing then return nil end
    local avatar,battle,selection,details,rows=nil,nil,nil,nil,{}
    local templates=integer(Asset.imagePrefabId) and Asset.imagePrefabId~=100001 and integer(Asset.containerPrefabId) and Asset
        or type(cardTemplates)=='table' and {imagePrefabId=cardTemplates.imageTemplateIndex,containerPrefabId=cardTemplates.containerTemplateIndex}
    if landing and templates then
        -- Bottom-most layout slot (first child): behind every hand/monster/HUD control.
        for _,entry in ipairs({{'selectScene','characterPanel',{'border','face'}},{'battleScene','battlePanel',{}},{'menuScene','menuPanel',{}}})do
            local panel=stage:GetChild(entry[2]);local host=panel and panel:GetChild('lowpolyScene')
            if host then
                local cover={};for _,name in ipairs(entry[3])do cover[#cover+1]=panel:GetChild(name)end
                rows[#rows+1]={name=entry[1],adapter=controller(host,Asset.lowpolyLand,Asset.lowpolyLand.width,templates),fallback=cover,active=false}
            end
        end
    end
    if selecting then
        validate(Asset.avatar96,96,4822,'c30551e1fed1cd7f18c61b67fe0ad0cd6e52c61bfa6ae937ccd9e4c90e7f72bb','93bcf4303d370f7faac2b8289146acfe655bae6dced0abf5257e407d69f748ef')
        local panel=assert(stage:GetChild('characterPanel'))
        local traveler=assert(panel:GetChild('traveler'))
        local bust=assert(traveler:GetChild('hit'):GetChild('normal'):GetChild('bust'))
        avatar=controller(traveler:GetChild('officialAvatar'),Asset.avatar96,assert(bust.sizeDeltaX),Asset)
        details=panel:GetChild('details')
        local host=details and details:GetChild('officialSelectionFigure')
        if host then
            local figure=lowpoly(Asset.lowpolyHero) and Asset.lowpolyHero or Asset.selection133 or Asset.battle133
            if figure.renderProfile~='lowpoly-v1' then
                validate(figure,133,4315,'ae2161957033d688b1bed1c7ab2ad2891d5f7bf5e34b291f9ecaef7cfa11f880','f8a7af7b079aa5bbb7e16b502b222f1fd7dbfaa2c30f6eef1bf0d76af0a0a248')
            end
            selection=controller(host,figure,assert(details:GetChild('portraitFrame').sizeDeltaX),Asset)
            rows[#rows+1]={name='selection',adapter=selection,fallback={details:GetChild('portraits'):GetChild('traveler_ironclad')},active=false}
        end
        local row={name='avatar',adapter=avatar,fallback={},active=false}
        for _,name in ipairs({'normal','hover','pressed','disabled'})do row.fallback[#row.fallback+1]=traveler:GetChild('hit'):GetChild(name):GetChild('bust')end
        rows[#rows+1]=row
    end
    if carding then
        -- Premium frames + low-poly illustrations fanned under the select details, like the breakthrough GIF.
        local panel=stage:GetChild('characterPanel')
        local parent=panel and panel:GetChild('details')
        if templates and parent and integer(templates.containerPrefabId) then
            local host=game.InstantiateClientUIControl(templates.containerPrefabId,parent)
            if host then
                pcall(host.SetVisible,host,false)
                pcall(host.SetAnchoredPosition,host,0,-250)
                local fan=controller(host,Asset.lowpolyCardFan,Asset.lowpolyCardFan.width,templates)
                rows[#rows+1]={name='cardFan',adapter=fan,fallback={},active=false}
            end
        end
    end
    if fighting then
        validate(Asset.battle133,133,4315,'ae2161957033d688b1bed1c7ab2ad2891d5f7bf5e34b291f9ecaef7cfa11f880','f8a7af7b079aa5bbb7e16b502b222f1fd7dbfaa2c30f6eef1bf0d76af0a0a248')
        local hero=assert(stage:GetChild('battlePanel'):GetChild('hero'))
        battle=controller(hero:GetChild('officialFigure'),Asset.battle133,400/3,Asset,{retryFailedOnPause=true})
        -- UnitView deliberately hides the shipped geometric player placeholder.
        -- Publication failure or pause must not override that presentation policy.
        local icon=require('abyss_theme').icon.player
        rows[#rows+1]={name='battle',adapter=battle,fallback={hero:GetChild('portrait')},active=false,
            fallbackVisible=not(type(icon)=='table' and icon.status=='placeholder')}
    end
    if #rows==0 then return nil end
    local timeBudget=selecting and Asset.avatar96.runtimeV2 or fighting and Asset.battle133.runtimeV2 or carding or landing
    local self,busy,destroyed,painting,epoch={},false,false,false,0
    local function paint()
        if destroyed or painting then return end
        painting=true
        for _,row in ipairs(rows)do
            local s=row.adapter:status();local ready=row.active and s.phase=='ready'
            local fallbackVisible=row.name~='selection' and row.fallbackVisible~=false
            for _,c in ipairs((row.name~='selection' or row.active)and row.fallback or {})do
                if destroyed then painting=false;return end
                if c and c.alive~=false then
                    pcall(c.SetVisible,c,not ready and fallbackVisible)
                    if destroyed then painting=false;return end
                    -- A native setter may synchronously release. Its old hide must not win.
                    if ready and (not row.active or row.adapter:status().phase~='ready')then pcall(c.SetVisible,c,fallbackVisible)end
                end
            end
            if row.name=='selection' and ready then
                local note=details:GetChild('portraitNote');note.text=note.text:gsub(' · 肖像待补','')
            end
            if row.lastPhase~=s.phase then row.lastPhase=s.phase;if report then pcall(report,'ABYSS_PORTRAIT '..row.name..' phase='..s.phase..' owned='..s.owned..' reason='..tostring(s.reason))end end
        end
        painting=false
    end
    function self.status(_)return {avatar=avatar and avatar:status() or {phase='disabled',owned=0},
        battle=battle and battle:status() or {phase='disabled',owned=0},selection=selection and selection:status(),batchSize=64}end
    function self.sync(_,mode,characterOpen,stopped,character,preloadSelection)
        if busy or destroyed then return false end
        busy=true;local token=epoch
        local wanted=activeTargets(mode,characterOpen,stopped,character,preloadSelection)
        for _,row in ipairs(rows)do
            if wanted[row.name] and not row.active then row.active=true;row.adapter:begin()
            elseif not wanted[row.name] and row.active then row.active=false;row.adapter:pause()end
            if epoch~=token or destroyed then busy=false;return false end
        end
        paint();busy=false;return true
    end
    -- Prioritize the main selection figure over the small thumbnail.
    local buildOrder=rows
    function self.tick(_)
        if busy or destroyed then return end
        busy=true
        local start=os.clock()
        for i=1,64 do
            local progressed,kind=false,nil
            for _,row in ipairs(buildOrder)do if row.active then
                local advance,phase=row.adapter:step()
                if advance then progressed=true;kind=phase;break end
            end end
            if not progressed or kind=='reveal' or timeBudget and i%8==0 and os.clock()-start>=.008 then break end
        end
        paint();busy=false
    end
    function self.battlePose(_,x,y,sx,sy)
        if busy or destroyed or not battle then return end
        busy=true;battle:pose(x,y,sx,sy);paint();busy=false
    end
    function self.release(_)
        if destroyed then return true end
        epoch=epoch+1;local old=busy;busy=true;local ok=true
        for _,row in ipairs(rows)do row.active=false;if not row.adapter:release()then ok=false end end
        paint();busy=old;return ok
    end
    function self.onEngineDestroy(_)
        epoch=epoch+1;destroyed=true;for _,row in ipairs(rows)do row.active=false;row.adapter:destroy()end
        -- Keep owners[stage] as a weak-key tombstone even before engine alive=false.
    end
    owners[stage]=self;return self
end
M.createController=controller
return M
