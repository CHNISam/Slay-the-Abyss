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
local function validate(data, width, count, source, json)
    assert(type(data)=='table' and data.width==width and data.count==count and #data.rows==count
        and data.sourceSha256==source and data.jsonSha256==json,'unexpected frozen portrait data')
    local r=data.root
    assert(#r==13 and r[1]==0 and r[2]==0 and r[3]==width and r[4]==width and r[5]==.5 and r[6]==.5
        and r[7]==.5 and r[8]==.5 and r[9]==.5 and r[10]==.5 and r[11]==1 and r[12]==1 and r[13]==0,'unexpected portrait ROOT')
end
local function controller(host, data, display, Asset)
    assert(host,'missing dedicated portrait host')
    local self,created={},{}
    local phase,generation,nextIndex='idle',0,1
    local page,group,pageIndex,groupIndex=nil,nil,0,0
    local working,pending,hiding=false,false,false
    local reason,cleanupFailures=nil,0
    local function current(token)return phase=='building' and generation==token and host.alive~=false end
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
        call(token,c,'SetSizeDelta',data.width,data.width);call(token,c,'SetLocalScale',1,1,1)
        call(token,c,'SetLocalRotation',0,0,0);call(token,c,'SetAnchoredPosition',0,0)
    end
    local function create(token,prefab,parent)
        local c=game.InstantiateClientUIControl(prefab,parent)
        if c then created[#created+1]={control=c,parent=parent}end
        check(token);assert(c,'portrait template unavailable');call(token,c,'SetVisible',false)
        return c
    end
    local function image(token,c,r)
        assert(#r==18 and r[1]==100001,'unexpected portrait image row')
        call(token,c,'SetImage',Enum.ImageSource.StaticReference,r[1])
        c.imageType=Enum.ImageType.Stretch;check(token);assert(c.imageType==Enum.ImageType.Stretch,'imageType rejected')
        call(token,c,'SetAnchorMin',r[8],r[9]);call(token,c,'SetAnchorMax',r[10],r[11]);call(token,c,'SetPivot',r[6],r[7])
        call(token,c,'SetSizeDelta',r[4],r[5]);call(token,c,'SetLocalScale',r[12],r[13],1)
        call(token,c,'SetLocalRotation',0,0,r[14]);call(token,c,'SetAnchoredPosition',r[2],r[3])
        c.imageColor=Color.FromRGBA(r[15],r[16],r[17],r[18]);check(token)
        call(token,c,'SetAsLastSibling');call(token,c,'SetActive',true);call(token,c,'SetVisible',true)
    end
    function self.status(_)
        return {phase=phase,generation=generation,nextIndex=nextIndex,owned=#created,
            retained=phase=='release_failed' and #created or 0,reason=reason,cleanupFailures=cleanupFailures}
    end
    function self.begin(_)
        if working or phase=='destroyed' or phase=='failed' or phase=='release_failed'then return false end
        if host.alive==false then self:destroy();return false end
        if phase=='building' or phase=='ready'then return true end
        if not integer(Asset.imagePrefabId) or not integer(Asset.containerPrefabId)
            or Asset.imagePrefabId==100001 or Asset.containerPrefabId==100001 then fail('unbound portrait templateIndex');return false end
        generation=generation+1;phase='building';nextIndex=1;pageIndex=0;groupIndex=0;page=nil;group=nil;reason=nil
        local token=generation;working=true
        local ok,err=pcall(function()
            call(token,host,'SetVisible',false);call(token,host,'SetActive',true)
            call(token,host,'SetAnchorMin',.5,.5);call(token,host,'SetAnchorMax',.5,.5);call(token,host,'SetPivot',.5,.5)
            call(token,host,'SetSizeDelta',data.width,data.width)
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
        if working or phase~='building'then return false end
        local token=generation;working=true
        local ok,err=pcall(function()
            local p=math.floor((nextIndex-1)/3600)+1;local g=math.floor((nextIndex-1)/60)+1
            if pageIndex~=p then
                page=create(token,Asset.containerPrefabId,host);transform(token,page);pageIndex=p
                call(token,page,'SetActive',true);call(token,page,'SetVisible',true)
            elseif groupIndex~=g then
                group=create(token,Asset.containerPrefabId,page);transform(token,group);groupIndex=g
                call(token,group,'SetActive',true);call(token,group,'SetVisible',true)
            else
                local c=create(token,Asset.imagePrefabId,group);image(token,c,data.rows[nextIndex]);nextIndex=nextIndex+1
                if nextIndex>#data.rows then call(token,host,'SetVisible',true);phase='ready'end
            end
        end)
        if not ok and err~=CANCELLED then fail(err)end
        if phase=='destroyed'then created={} elseif pending then cleanup()end
        working=false;return true
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
function M.new(stage,report,flags)
    local selection = type(flags)=='table' and flags.selectionAvatar==true
    local fighting = type(flags)=='table' and flags.battlePortrait==true
    if not selection and not fighting then return nil end
    if owners[stage]then return owners[stage]end
    local Asset = require('abyss_traveler_portrait_assets')
    local avatar,battle,rows=nil,nil,{}
    if selection then
        validate(Asset.avatar96,96,4822,'c30551e1fed1cd7f18c61b67fe0ad0cd6e52c61bfa6ae937ccd9e4c90e7f72bb','93bcf4303d370f7faac2b8289146acfe655bae6dced0abf5257e407d69f748ef')
        local traveler=assert(stage:GetChild('characterPanel'):GetChild('traveler'))
        avatar=controller(traveler:GetChild('officialAvatar'),Asset.avatar96,32,Asset)
        local row={name='avatar',adapter=avatar,fallback={},active=false}
        for _,name in ipairs({'normal','hover','pressed','disabled'})do
            row.fallback[#row.fallback+1]=traveler:GetChild('hit'):GetChild(name):GetChild('bust')
        end
        rows[#rows+1]=row
    end
    if fighting then
        validate(Asset.battle133,133,4315,'ae2161957033d688b1bed1c7ab2ad2891d5f7bf5e34b291f9ecaef7cfa11f880','f8a7af7b079aa5bbb7e16b502b222f1fd7dbfaa2c30f6eef1bf0d76af0a0a248')
        local hero=assert(stage:GetChild('battlePanel'):GetChild('hero'))
        battle=controller(hero:GetChild('officialFigure'),Asset.battle133,400/3,Asset)
        rows[#rows+1]={name='battle',adapter=battle,fallback={hero:GetChild('portrait')},active=false}
    end
    local self,busy,destroyed,painting,epoch={},false,false,false,0
    local function paint()
        if destroyed or painting then return end
        painting=true
        for _,row in ipairs(rows)do
            local s=row.adapter:status();local ready=row.active and s.phase=='ready'
            for _,c in ipairs(row.fallback)do
                if destroyed then painting=false;return end
                if c and c.alive~=false then
                    pcall(c.SetVisible,c,not ready)
                    if destroyed then painting=false;return end
                    -- A native setter may synchronously release. Its old hide must not win.
                    if ready and (not row.active or row.adapter:status().phase~='ready')then pcall(c.SetVisible,c,true)end
                end
            end
            if row.lastPhase~=s.phase then row.lastPhase=s.phase;if report then pcall(report,'ABYSS_PORTRAIT '..row.name..' phase='..s.phase..' owned='..s.owned..' reason='..tostring(s.reason))end end
        end
        painting=false
    end
    function self.status(_)return {avatar=avatar and avatar:status() or {phase='disabled',owned=0},
        battle=battle and battle:status() or {phase='disabled',owned=0},batchSize=64}end
    function self.sync(_,mode,characterOpen,stopped,character)
        if busy or destroyed then return false end
        busy=true;local token=epoch
        local wanted={avatar=not stopped and characterOpen==true,battle=not stopped and mode=='battle' and character=='ironclad'}
        for _,row in ipairs(rows)do
            if wanted[row.name] and not row.active then row.active=true;row.adapter:begin()
            elseif not wanted[row.name] and row.active then row.active=false;row.adapter:release()end
            if epoch~=token or destroyed then busy=false;return false end
        end
        paint();busy=false;return true
    end
    function self.tick(_)
        if busy or destroyed then return end
        busy=true
        for _=1,64 do
            local progressed=false
            for _,row in ipairs(rows)do if row.active and row.adapter:step()then progressed=true;break end end
            if not progressed then break end
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
return M
