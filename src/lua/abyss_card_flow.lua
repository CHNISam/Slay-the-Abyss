-- Read-only card destinations, driven by committed UID membership snapshots.
-- Ten reusable native mini-cards match the hand limit; overflow waits in Lua.
local Theme=require('abyss_theme')
local M={}
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
    local floor=-Theme.canvas.base[2]/2+Theme.canvas.safe.y+halfHeight
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
    local self={active={},waiting={},inPlay={}}
    local overlay=stage:GetChild('feedback')
    local function colour(c,alpha)return platform.color(c.r,c.g,c.b,math.floor((c.a or 255)*alpha))end
    local function box(slot)return overlay:GetChild('cardTrail'..slot)end
    function self:reset()
        for slot=1,10 do box(slot):SetVisible(false)end
        self.active,self.waiting,self.inPlay={},{},{}
    end
    function self:playing(d,flight)
        self.inPlay[d.uid]={card={uid=d.uid,cardId=d.cardId},pile='play',position={flight.tx,flight.ty}}
    end
    local function enqueue(card,from,to,label)
        local start=from.position or point(from)
        local finish=point(to)
        self.waiting[#self.waiting+1]={uid=card.uid,cardId=card.cardId,from=from.pile,to=to.pile,
            start={start[1],start[2]},finish={finish[1],finish[2]},age=0,label=label}
    end
    function self:sync(before,after,kind,complete)
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
    local function show(slot,entry,catalog,presentation)
        local card=box(slot)
        local definition=catalog.cards[entry.cardId]
        local display=presentation[entry.cardId]
        local labels={discard='弃牌堆',exhaust='消耗',draw='抽牌堆'}
        card:GetChild('name').text=(entry.label or labels[entry.to]or'')..' · '..(display and display.name or definition.name)
        card:GetChild('plate').imageColor=colour(entry.to=='exhaust'and C.debuff or C.cardType[definition.type]or C.panelRaised,1)
        card:GetChild('art'):SetImage(platform.imageSource,Theme.icon.cardArt[definition.type]or Theme.icon.cardArt.status)
        card:SetAnchoredPosition(entry.start[1],entry.start[2])
        card:SetLocalScale(0.5,0.5,1)
        card:SetVisible(true)
    end
    function self:update(dt,catalog,presentation,fast)
        for slot=1,10 do
            local entry=self.active[slot]
            if not entry and #self.waiting>0 then
                entry=table.remove(self.waiting,1);self.active[slot]=entry
                show(slot,entry,catalog,presentation)
            end
            if entry then
                entry.age=entry.age+dt*(fast and 2 or 1)
                local p=math.min(1,entry.age/T.slow)
                local q=p*p*(3-2*p)
                local card=box(slot)
                local lift=entry.to=='retain'and Theme.space.s or Theme.space.xxl
                card:SetAnchoredPosition(entry.start[1]+(entry.finish[1]-entry.start[1])*q,
                    entry.start[2]+(entry.finish[2]-entry.start[2])*q+math.sin(p*math.pi)*lift)
                local scale=entry.to=='retain'and 0.5 or 0.5-(0.5-0.12/0.75)*q
                card:SetLocalScale(scale,scale,1)
                -- Keep the card visible at its real endpoint for one update before recycling.
                if entry.arrived and dt>0 then card:SetVisible(false);self.active[slot]=nil
                elseif p>=1 then entry.arrived=true end
            end
        end
    end
    function self:busy()return next(self.active)~=nil or #self.waiting>0 end
    return self
end
return M
