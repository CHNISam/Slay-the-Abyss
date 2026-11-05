local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function near(a,b,label)check(math.abs(a-b)<0.00001,label)end
local nav={}
local c=NewShopController(nil,{onNavigate=function(target,data)nav[#nav+1]={target=target,data=data}end})
local t=c.generation
check(c:signal(t,'cleave','enter'),'enter affordable')
near(c.products.cleave.scale,1,'enter does not teleport')
c:tick(.065)
near(c.products.cleave.scale,1+.14*.8024033876,'default CSS ease halfway')
c:tick(.065);near(c.products.cleave.scale,1.14,'130ms reaches hover endpoint')
check(c:hoveredId()=='cleave','hover selection')
check(c:signal(t,'iron_wave','enter'),'enter another product')
check(not c.products.cleave.hovered and c.products.iron_wave.hovered,'single hover target')
c:tick(.13);near(c.products.cleave.scale,1,'old product restores');near(c.products.iron_wave.scale,1.14,'new product settles')
c:signal(t,'iron_wave','leave');c:tick(.065);local current=c.products.iron_wave.scale
check(current>1 and current<1.14,'shrink in progress')
c:signal(t,'iron_wave','enter');near(c.products.iron_wave.scale,current,'reverse preserves current position')
near(c.products.iron_wave.motion.duration,.13*.8024033876,'CSS reversal shortening factor')
c:tick(.13);near(c.products.iron_wave.scale,1.14,'reversal settles')
check(not c:signal(t,'barricade','enter'),'unaffordable not hovered')
check(not c:signal(t,'barricade','activate') and c.state.gold==150,'insufficient funds unchanged')
check(c:signal(t,'cleave','activate') and c.state.gold==100,'purchase once')
check(c.state.sold.cleave,'sold state')
check(not c:signal(t,'cleave','activate') and c.state.gold==100,'repeat buy inert')
check(c:hoveredId()==nil,'purchase redraw clears transient hover')
for _,p in pairs(c.products)do near(p.scale,1,'all redraw scales reset')end
check(c:signal(t,'leave','enter'),'leave hover accepted');c:tick(.065);near(c.leave.brightness,1+.2*.8024033876,'leave easing');c:tick(.065);near(c.leave.brightness,1.2,'entire leave brightness endpoint')
local old=function()return c:signal(t,'iron_wave','activate')end
check(c:signal(t,'leave','activate'),'leave navigates')
check(#nav==1 and nav[1].target=='map','explicit map callback once')
check(nav[1].data.gold==100 and nav[1].data.sold[1]=='cleave','callback includes snapshot')
check(not c.active and c:hoveredId()==nil,'departed controller inactive and clean')
near(c.leave.brightness,1,'leave resets brightness')
check(not old() and c.state.gold==100,'old purchase callback inert')
check(not c:signal(t,'leave','activate') and #nav==1,'old navigation cannot repeat')
c:enter();check(c.active and c.generation~=t,'reentry new generation')
check(not old(),'old callback remains stale after reentry')
check(c:signal(c.generation,'iron_wave','activate') and c.state.gold==50,'fresh callback buys')
c:signal(c.generation,'leave','enter');c:destroy();near(c.leave.brightness,1,'destroy clears hover');check(not c.active,'destroy deactivates')
local r=NewShopController(nil,{reducedMotion=true});r:signal(r.generation,'cleave','enter');near(r.products.cleave.scale,1.14,'reduced motion snaps');r:signal(r.generation,'cleave','leave');near(r.products.cleave.scale,1,'reduced motion reset')
print('SHOP_CONTROLLER_PASS assertions='..checks..' input_verified=false')
local input={gold=80,hp=35,maxHp=80,sold={'cleave'}}
local injected=NewShopController(nil,{state=input})
check(not injected:available('cleave'),'navigation snapshot sold array accepted')
check(injected:available('iron_wave'),'remaining stock preserved')
check(injected:signal(injected.generation,'iron_wave','activate') and input.gold==80,'controller owns a copy of supplied snapshot')
print('SHOP_SNAPSHOT_PASS assertions='..checks..' input_verified=false')
