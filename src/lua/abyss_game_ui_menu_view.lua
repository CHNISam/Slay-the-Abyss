-- Owns title/result visuals; reads host state and never changes rules or sends commands.
local Theme=require("abyss_theme")
local Narrative=require("abyss_narrative")
local Acts=require("abyss_acts")
local Run=require("abyss_run")
local number=require("abyss_numbers").integer
local M={}
local L,C,T=Theme.layout.nativeMenu,Theme.color,Theme.motion
local R=L.reveal
local function colour(ctx,c) return ctx.platform.color(c.r,c.g,c.b,c.a) end
local function clamp(value) return math.max(0, math.min(1, value)) end
local function easeOut(p) return 1 - (1 - p) ^ 3 end
local function overshoot(p) return 1 + 2.7 * (p - 1) ^ 3 + 1.7 * (p - 1) ^ 2 end
local function clock(seconds)
    seconds = math.floor(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function paintVeil(ctx)
    local m,menu,platform=ctx.owner.motion,ctx.menu,ctx.platform
    if m.deathReveal or not m.shadeHidden then
        local shade = menu:GetChild("deathShade")
        local alpha = m.deathReveal and 1 - easeOut(clamp(m.t / T.slow)) or 0
        shade.imageColor = platform.color(C.backdrop.r, C.backdrop.g, C.backdrop.b, math.floor(255 * alpha))
        shade:SetVisible(alpha > 0)
        if alpha == 0 then m.deathReveal = nil end
        m.shadeHidden = alpha == 0
    end
end
local function paintEntrance(ctx)
    local m,emblem,risers,cards=ctx.owner.motion,ctx.emblem,ctx.risers,ctx.cards
    if not m.entranceDone then
        local p = easeOut(clamp(m.t / T.slow))
        local grow = R.emblemFrom + (1 - R.emblemFrom) * overshoot(clamp(m.t / T.slow))
        emblem:SetLocalScale(grow, grow, 1)
        for _, riser in ipairs(risers) do riser[1]:SetAnchoredPosition(riser[2][1], riser[2][2] - R.rise * (1 - p)) end
        for i, card in ipairs(cards) do
            local q = easeOut(clamp((m.t - i * R.stagger) / T.slow))
            local scale = R.cardFrom + (1 - R.cardFrom) * q
            card:SetLocalScale(scale, scale, 1)
            card:SetAnchoredPosition(L.stats.origin[1] + (i - 1) * L.stats.step, L.stats.origin[2] - R.rise * (1 - q))
        end
        m.entranceDone = m.t >= T.slow + #cards * R.stagger
    end
end
local function paintSettlement(ctx)
    local m,settlement=ctx.owner.motion,ctx.settlement
    local x = m.settleX
    if m.slide then x = m.slide.from + (m.slide.to - m.slide.from) * easeOut(clamp(m.slide.t / T.base)) end
    if m.shake then
        local s = clamp(m.shake / T.shake)
        x = x + T.shakeAmplitude * math.sin(s * math.pi * 4) * (1 - s)
    end
    if m.paintedSettleX ~= x then
        settlement:SetAnchoredPosition(x,L.settle[2])
        m.paintedSettleX = x
    end
end
local function paintVista(ctx)
    local m,vista=ctx.owner.motion,ctx.vista
    if not vista.visible then return end
    -- Title vista: embers drift up past the ruins and the seal breathes; nothing here takes input.
    local V = Theme.layout.vista
    for i, at in ipairs(V.motes) do
        local rise = (m.t * V.drift + i * 53) % 220
        local mote = vista:GetChild("mote" .. i)
        mote:SetAnchoredPosition(at[1] + 10 * math.sin(m.t + i), at[2] + rise)
        mote.imageColor = colour(ctx,{ r = C.goldBright.r, g = C.goldBright.g, b = C.goldBright.b,
            a = math.floor(180 * math.sin(math.pi * rise / 220)) })
    end
    local seal = 1 + 0.03 * math.sin(2 * math.pi * m.t / V.breathe)
    vista:GetChild("seal"):SetLocalScale(seal, seal, 1)
end
local function pose(ctx)
    paintVeil(ctx)
    paintEntrance(ctx)
    local m=ctx.owner.motion
    local breathe=1+R.breatheScale*math.sin(2*math.pi*math.max(0,m.t-T.slow)/R.breathe)
    ctx.emblem:GetChild("glow"):SetLocalScale(breathe,breathe,1)
    paintSettlement(ctx)
    paintVista(ctx)
end
local function endingTitle(run)
    if run.ending=='two_act_complete' then return '双幕挑战完成' end
    if run.ending=='true_victory' then return '真结局 · 深渊已被封印' end
    return '深渊已被封印'
end
local function resultSubtitle(run,mode,victory)
    if victory and run.ending=='two_act_complete' then return '第一幕与第二幕已完成。本局挑战到此结束。' end
    if victory and run.ending=='true_victory' then return '腐化之心已击败。真结局已达成。' end
    return Narrative.flow[mode].full
end
local function finalFloor(ctx,victory)
    local run=ctx.owner.run
    if Acts.isCompetition(run) then return Acts.get(2).last end
    local floors=ctx.data.rules.map.floors
    if victory and run.ending=='true_victory' then return ctx.owner.map.terminalFloor or floors end
    return floors
end
local function settlementStatus(ctx,available)
    local self=ctx.owner
    if self.settlementRequested then return '结算请求已发送，等待平台结算界面',C.positive end
    if self.settlementError then return '结算请求失败，请重试',C.danger end
    if not available then return '平台结算暂不可用，可重新启程',C.textMuted end
    return '「结束并结算」提交本局结果并进入平台结算；「重新启程」不会提交',C.textMuted
end
local function presentStats(ctx,victory,mode,available)
    local self,result,cards=ctx.owner,ctx.result,ctx.cards
    local run=ctx.owner.run
    result:GetChild('subtitle').text=resultSubtitle(run,mode,victory)
    local values={self.map.floor..' / '..finalFloor(ctx,victory),tostring(run.victories),clock(run.elapsedSeconds),tostring(#run.deck)}
    for i,name in ipairs({'抵达层数','战斗胜场','用时','卡组张数'})do
        cards[i]:GetChild('label').text,cards[i]:GetChild('value').text=name,values[i]
    end
    cards[1]:GetChild('value').fontColor=colour(ctx,victory and C.goldBright or C.text)
    local hp=run.phase=='defeat' and 0 or run.hp
    local score=Run.resultScore(run)
    local total=score and '总分 '..number(score.total) or '总分暂不可用'
    result:GetChild('detail').text=total..' · 生命 '..number(hp)..' / '..number(run.maxHp)..' · 金币 '..number(run.gold)..' · 遗物 '..#run.relics..' 件'
    local status,ink=settlementStatus(ctx,available)
    result:GetChild('status').text,result:GetChild('status').fontColor=status,colour(ctx,ink)
end
local function presentTitle(ctx,victory,defeat)
    local emblem,vista,menu=ctx.emblem,ctx.vista,ctx.menu
    local accent=colour(ctx,defeat and C.danger or C.goldBright)
    emblem:GetChild('icon').imageColor=colour(ctx,defeat and C.danger or C.geo)
    emblem:GetChild('glow').imageColor=accent
    vista:GetChild('seal'):GetChild('heart').imageColor=accent
    vista:GetChild('seal'):GetChild('ring').imageColor=colour(ctx,defeat and C.danger or C.gold)
    local title=menu:GetChild('title')
    title.text=victory and endingTitle(ctx.owner.run) or defeat and '旅途在此中断' or '杀戮原塔2'
    title.fontColor=colour(ctx,victory and C.goldBright or defeat and C.text or C.gold)
end
local function presentSettlement(ctx,outcome,available)
    local self,settlement=ctx.owner,ctx.settlement
    settlement:SetVisible(outcome)
    local enabled=outcome and available and not self.settlementRequested and not self.settlementBusy
    settlement:GetChild('normal'):SetVisible(enabled==true)
    settlement:GetChild('disabled'):SetVisible(not enabled and not self.settlementBusy)
    settlement:GetChild('selected'):SetVisible(self.settlementBusy==true)
    settlement:GetChild('border').imageColor=colour(ctx,enabled and C.gold or C.line)
    settlement:GetChild('label').text=self.settlementRequested and '已发送结算请求' or '结束并结算'
    settlement:GetChild('label').fontColor=colour(ctx,enabled and C.gold or C.textDim)
    local m=self.motion
    local targetX=self.settlementRequested and 0 or L.settle[1]
    if targetX~=m.settleX then m.slide,m.settleX={from=m.settleX,to=targetX,t=0},targetX end
end
function M.present(ctx)
    local self,menu,start=ctx.owner,ctx.menu,ctx.start
    local mode,run,m=self.mode,self.run,self.motion
    if mode~='menu' and mode~='defeat' and mode~='victory' then m.mode=nil return end
    local victory,defeat=mode=='victory',mode=='defeat'
    local outcome=victory or defeat
    if m.mode~=mode then
        m.t,m.mode=0,mode
        m.entranceDone,m.shadeHidden,m.paintedSettleX=nil,nil,nil
        m.deathReveal=defeat and self.battleUI.feedback.deaths.player or nil
    end
    presentTitle(ctx,victory,defeat)
    menu:GetChild('tagline'):SetVisible(not outcome)
    menu:GetChild('summary'):SetVisible(false)
    ctx.result:SetVisible(outcome)
    local startFrame=outcome and L.resultRestart or L.start
    start:SetAnchoredPosition(startFrame[1],startFrame[2])
    start:SetVisible(not self.settlementRequested and not self.settlementBusy)
    start:GetChild('label').text=run and '重新启程' or '启程'
    local available=type(ctx.platform.settle)=='function'
    presentSettlement(ctx,outcome,available)
    if outcome then presentStats(ctx,victory,mode,available)
    else menu:GetChild('tagline').text=Narrative.title;menu:GetChild('summary').text='' end
    pose(ctx)
end
function M.animate(ctx, dt)
    local self=ctx.owner
    local m = self.motion
    if not m.mode then return end
    m.t = m.t + dt
    if m.slide then m.slide.t = m.slide.t + dt; if m.slide.t >= T.base then m.slide = nil end end
    if m.shake then m.shake = m.shake + dt; if m.shake >= T.shake then m.shake = nil end end
    pose(ctx)
end

function M.new(owner,menu,data,platform)
    local result=menu:GetChild("result")
    local ctx={owner=owner,menu=menu,data=data,platform=platform,result=result,
        emblem=menu:GetChild("emblem"),start=menu:GetChild("start"),settlement=menu:GetChild("settle"),vista=menu:GetChild("vista")}
    ctx.risers={{menu:GetChild("title"),L.title},{menu:GetChild("tagline"),L.tagline},{result:GetChild("subtitle"),L.subtitle}}
    ctx.cards={}
    for i,key in ipairs({"floor","victories","time","deck"})do ctx.cards[i]=result:GetChild("stat_"..key) end
    owner.motion={t=0,settleX=L.settle[1]}
    return ctx
end
return M
