-- Read-only card destinations, driven by committed UID membership snapshots.
-- Ten reusable native mini-cards match the hand limit; overflow waits in Lua.
local Theme=require('abyss_theme')
local M={}
-- Exhaust burn timing (seconds / px); total is the exhaust trail lifetime.
M.burn={lift=30,scale=1.05,hold=0.25,burn=0.9,fly=0.2}
-- 弃牌错峰（秒/张）、旋转角度、终点缩放。
M.discard={stagger=0.05,spin=-120,scale=0.06}
local L,C,T=Theme.layout,Theme.color,Theme.motion
local piles={'hand','draw','discard','exhaust'}
local function locations(frame)
    local found={}
    for _,pile in ipairs(piles)do for index,card in ipairs(frame[pile]or{})do
        found[card.uid]={pile=pile,index=index,card=card,count=#frame[pile]}
    end end
    return found
end
local function handPoint(index,count)
    local w,h=L.card.size[1],L.card.size[2]
    local spacing=count<=1 and 0 or math.max(L.hand.spacingMin,math.min(L.hand.spacingMax,(L.hand.maxWidth-w)/(count-1)))
    local distance=index-1-(count-1)/2
    local radians=math.abs(distance*L.hand.arcDegrees)*math.pi/180
    local halfHeight=(h*math.cos(radians)+w*math.sin(radians))/2
    local floor=-Theme.canvas.base[2]/2+Theme.canvas.safe.y+halfHeight-(L.hand.overhang or 0)
    return {distance*spacing,math.max(floor,L.hand.y-math.abs(distance)*L.hand.arcDrop)}
end
local function point(place)
    if place.pile=='hand'or place.pile=='retain'then return handPoint(place.index,place.count)end
    if place.pile=='draw'then return L.drawPile.position end
    if place.pile=='discard'then return L.discardPile.position end
    if place.pile=='exhaust'then
        local b=L.topBar
        return {b.exhaustIcon[1],b.y}
    end
    return L.player.position
end
function M.new(stage,platform)
    local self={active={},waiting={},inPlay={},moving={}}
    local overlay=stage:GetChild('feedback')
    local function colour(c,alpha)return platform.color(c.r,c.g,c.b,math.floor((c.a or 255)*alpha))end
    local function box(slot)return overlay:GetChild('cardTrail'..slot)end
    function self.reset()
        for slot=1,10 do box(slot):SetVisible(false)end
        self.active,self.waiting,self.inPlay,self.moving={},{},{},{}
    end
    function self.playing(_owner,d,flight)
        self.inPlay[d.uid]={card={uid=d.uid,cardId=d.cardId},pile='play',position={flight.tx,flight.ty}}
    end
    local function enqueue(card,from,to,label)
        local start=from.position or point(from)
        local finish=point(to)
        self.waiting[#self.waiting+1]={uid=card.uid,cardId=card.cardId,from=from.pile,to=to.pile,
            start={start[1],start[2]},finish={finish[1],finish[2]},age=0,label=label,
            order=to.pile=='discard'and #self.waiting or 0}
    end
    function self.sync(_owner,before,after,kind,complete)
        local old,new=locations(before),locations(after)
        for _,pile in ipairs(piles)do for index,card in ipairs(after[pile]or{})do
            local prior=old[card.uid]or self.inPlay[card.uid]
            if prior and prior.pile~=pile then
                -- Newly drawn hand cards use the existing full-card hand interpolation.
                if pile~='hand'then enqueue(card,prior,new[card.uid],kind=='reshuffle'and'洗牌'or nil)end
                self.inPlay[card.uid]=nil
            elseif kind=='enemy_turn'and pile=='hand'and prior then
                enqueue(card,prior,{pile='retain',index=index,count=#after.hand},'保留')
            end
        end end
        if complete then for uid,entry in pairs(self.inPlay)do
            local using=after.cardInUse and after.cardInUse.uid==uid
            local definition=after.catalog.cards[entry.card.cardId]
            if not using and definition.type=='power'then
                enqueue(entry.card,entry,{pile='power'},'能力生效')
                self.inPlay[uid]=nil
            elseif not using then
                -- Purged/autoplay and terminal battle cleanup are not exhaust.
                self.inPlay[uid]=nil
            end
        end end
    end
    -- Exhaust burn: behaviour port of Slay the Spire ExhaustCardEffect (lift + pow2Out
    -- scale, darken-to-transparent) with ExhaustEmber twinkle, rewritten on the existing
    -- trail children so no controls are allocated. Discard keeps the plain shrink-fly.
    local BURN=M.burn
    local ember=C.potionShell.fire.ink
    local function mix(a,b,t)return{r=a.r+(b.r-a.r)*t,g=a.g+(b.g-a.g)*t,b=a.b+(b.b-a.b)*t,a=255}end
    local function burn(card,entry)
        local a=entry.age
        local total=BURN.hold+BURN.burn+BURN.fly
        local s0=0.5
        if a<BURN.hold+BURN.burn then
            local h=math.min(1,a/BURN.hold);local e=1-(1-h)*(1-h) -- pow2Out
            card:SetAnchoredPosition(entry.start[1],entry.start[2]+BURN.lift*e)
            local b=math.max(0,(a-BURN.hold)/BURN.burn)
            local sc=s0*(1+(BURN.scale-1)*e)*(1-0.15*b)
            card:SetLocalScale(sc,sc,1)
            -- Plate chars from curse purple through ember to soot while fading out.
            local plate=b<0.4 and mix(C.debuff,ember,b/0.4)or mix(ember,C.backdrop,(b-0.4)/0.6)
            card:GetChild('plate').imageColor=colour(plate,1-b*b)
            local art=card:GetChild('art')
            if b>0 and not entry.ember then
                entry.ember=true;art:SetImage(platform.imageSource,Theme.image.sparkle)
                card:GetChild('name').text=''
            end
            if b>0 then
                -- ExhaustEmber twinkle: bottom-up drift with flicker.
                local tw=0.75+0.25*math.sin(a*40)
                art.imageColor=colour(ember,(1-b)*tw)
                art:SetAnchoredPosition(math.sin(a*23)*6,Theme.space.xl+b*BURN.lift)
            end
            return false
        end
        local f=math.min(1,(a-BURN.hold-BURN.burn)/BURN.fly)
        local q=f*f*(3-2*f)
        local sx,sy=entry.start[1],entry.start[2]+BURN.lift
        card:SetAnchoredPosition(sx+(entry.finish[1]-sx)*q,sy+(entry.finish[2]-sy)*q)
        local art=card:GetChild('art')
        art.imageColor=colour(ember,1-q*0.5) -- spark streaks to the exhaust pile icon
        card:SetLocalScale(0.3*(1-q)+0.16*q,0.3*(1-q)+0.16*q,1)
        return a>=total
    end
    local function discard(card,entry)
        if entry.age<0 then return false end
        card:SetVisible(true)
        local p=math.min(1,entry.age/T.slow)
        local q=p*p*(3-2*p)
        card:SetAnchoredPosition(entry.start[1]+(entry.finish[1]-entry.start[1])*q,
            entry.start[2]+(entry.finish[2]-entry.start[2])*q+math.sin(p*math.pi)*Theme.space.xxl)
        local scale=0.5+(M.discard.scale-0.5)*p*p
        card:SetLocalScale(scale,scale,1)
        card.localRotationZ=M.discard.spin*q
        return p>=1
    end
    local function show(slot,entry,catalog,presentation)
        local card=box(slot)
        card:GetChild('art').imageColor=colour(C.goldBright,1)
        card:GetChild('art'):SetAnchoredPosition(0,Theme.space.xl)
        local definition=catalog.cards[entry.cardId]
        local display=presentation[entry.cardId]
        local labels={discard='弃牌堆',exhaust='消耗',draw='抽牌堆'}
        card:GetChild('name').text=(entry.label or labels[entry.to]or'')..' · '..(display and display.name or definition.name)
        card:GetChild('plate').imageColor=colour(entry.to=='exhaust'and C.debuff or C.cardType[definition.type]or C.panelRaised,1)
        card:GetChild('art'):SetImage(platform.imageSource,Theme.icon.cardArt[definition.type]or Theme.icon.cardArt.status)
        card:SetAnchoredPosition(entry.start[1],entry.start[2])
        card:SetLocalScale(0.5,0.5,1)
        card.localRotationZ=0
        if entry.to=='discard'then
            -- STS 回合末弃牌：逐张错峰、旋转缩入弃牌堆；小尺寸下文字不可读且会叠在按钮上，隐藏。
            card:GetChild('name').text=''
            entry.age=-M.discard.stagger*(entry.order or 0)
        end
        card:SetVisible(entry.age>=0)
    end
    local function takeNext()
        for index,entry in ipairs(self.waiting)do
            if not self.moving[entry.uid]then
                self.moving[entry.uid]=true
                return table.remove(self.waiting,index)
            end
        end
    end
    function self.update(_owner,dt,catalog,presentation,fast)
        for slot=1,10 do
            local entry=self.active[slot]
            if not entry and #self.waiting>0 then
                entry=takeNext();self.active[slot]=entry
                if entry then show(slot,entry,catalog,presentation)end
            end
            if entry then
                entry.age=entry.age+dt*(fast and 2 or 1)
                local p=math.min(1,entry.age/T.slow)
                local q=p*p*(3-2*p)
                local card=box(slot)
                local done
                if entry.to=='exhaust'then done=burn(card,entry)
                elseif entry.to=='discard'then done=discard(card,entry)else
                local lift=entry.to=='retain'and Theme.space.s or Theme.space.xxl
                card:SetAnchoredPosition(entry.start[1]+(entry.finish[1]-entry.start[1])*q,
                    entry.start[2]+(entry.finish[2]-entry.start[2])*q+math.sin(p*math.pi)*lift)
                local scale=entry.to=='retain'and 0.5 or 0.5-(0.5-0.12/0.75)*q
                card:SetLocalScale(scale,scale,1)
                done=p>=1 end
                -- Keep the card visible at its real endpoint for one update before recycling.
                if entry.arrived and dt>0 then
                    card:SetVisible(false);self.active[slot]=nil;self.moving[entry.uid]=nil
                elseif done then entry.arrived=true end
            end
        end
    end
    function self.busy()return next(self.active)~=nil or #self.waiting>0 end
    return self
end
return M
