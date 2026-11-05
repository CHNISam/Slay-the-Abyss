local checks=0
local function check(v,label) checks=checks+1;assert(v,label)end
local function near(a,b,label)check(math.abs(a-b)<.00001,label)end
local c=NewMenuController(nil,'menu')
local t=c.generation
check(c:signal(t,'play','enter'),'enter accepted');near(c.buttons.play.alpha,.9,'enter immediately glows');near(c.buttons.play.x,0,'enter does not teleport')
c:tick(1/60);near(c.buttons.play.x,2.5,'source 9x recurrence')
check(c:signal(t,'play','down'),'down accepted');near(c.buttons.play.alpha,.9,'no extra pressed tint');check(c.buttons.play.down,'semantic press retained')
c:signal(t,'play','up');check(not c.buttons.play.down,'release clears press');near(c.buttons.play.alpha,.9,'release leaves hover intact')
c:signal(t,'play','leave');c:tick(1/60);near(c.buttons.play.alpha,.72,'leave 12x decay');near(c.buttons.play.x,2.125,'reverse from current x')
c:signal(t,'play','enter');c:tick(1/60);near(c.buttons.play.x,4.30625,'reenter reverses without restart');near(c.buttons.play.alpha,.9,'reenter immediate glow')
c:signal(t,'play','down');c:signal(t,'play','cancel');check(not c.buttons.play.down and not c.buttons.play.hovered,'cancel clears hover and press');check(c.page=='menu','cancel does not activate')
for i=1,60 do c:tick(1/60)end;near(c.buttons.play.x,0,'exit snaps x');near(c.buttons.play.alpha,0,'exit snaps alpha')
for _,id in ipairs({'collection','history'})do check(not c:signal(t,id,'enter'),'disabled rejects enter');check(not c:signal(t,id,'activate'),'disabled rejects activation');near(c.buttons[id].x,0,'disabled immobile');near(c.buttons[id].alpha,0,'disabled unlit')end
c:signal(t,'play','enter');c:tick(.1);near(c.buttons.play.x,10,'dt clamped to 1/15')
check(c:signal(t,'play','activate'),'play advances');check(c.page=='character','character visible');near(c.buttons.play.x,0,'departure resets old x');near(c.buttons.play.alpha,0,'departure resets glow');check(not c:signal(t,'play','activate'),'old generation inert')
local ct=c.generation;c:signal(ct,'back','enter');check(c.buttons.back.brightness==1.18,'banner hover brightness');c:signal(ct,'back','down');check(c.buttons.back.brightness==.92,'banner active brightness');c:signal(ct,'back','up');check(c.buttons.back.brightness==1.18,'banner release hover');c:signal(ct,'back','cancel');check(c.buttons.back.brightness==1,'banner cancel normal')
check(c:signal(ct,'selected','enter') and c.buttons.selected.hovered,'selected hover accepted');check(c:signal(ct,'selected','leave') and not c.buttons.selected.hovered,'selected hover cleared');c:signal(ct,'embark','enter');c:signal(ct,'embark','down');check(c.buttons.embark.brightness==.92,'start banner active brightness');c:signal(ct,'embark','cancel');check(c.buttons.embark.brightness==1 and c.page=='character','start cancel stays character');
check(c:signal(ct,'back','activate') and c.page=='menu','return menu');check(not c:signal(ct,'back','activate'),'old back generation inert')
for i=1,5 do local e=c.generation;c:signal(e,'play','enter');c:signal(e,'play','down');c:signal(e,'play','activate');c:signal(c.generation,'back','activate');near(c.buttons.play.x,0,'repeat route resets x');check(not c.buttons.play.down and not c.buttons.back.hovered,'repeat route resets transient state')end
check(c:signal(c.generation,'quit','activate') and c.page=='exit','quit opens confirmation');local et=c.generation;check(not c:signal(et,'play','activate'),'modal blocks background');check(c:signal(et,'cancelExit','activate') and c.page=='menu','exit cancel restores menu');check(not c.exitAttempted,'cancel did not exit')
c:signal(c.generation,'quit','activate');c:signal(c.generation,'confirmExit','activate');check(c.page=='exit' and c.exitAttempted,'unsupported close remains explicit, never silently returns menu')
c:signal(c.generation,'cancelExit','activate');c:signal(c.generation,'play','activate');c:signal(c.generation,'embark','activate');check(c.page=='scope','embark reaches declared slice boundary');c:signal(c.generation,'backToCharacter','activate');check(c.page=='character','scope return')
c:show('menu');c.reducedMotion=true;c:signal(c.generation,'play','enter');near(c.buttons.play.x,50/3,'reduced motion snaps');c:signal(c.generation,'play','leave');near(c.buttons.play.x,0,'reduced motion leaves immediately');near(c.buttons.play.alpha,0,'reduced motion clears alpha')
c:signal(c.generation,'play','focus');c:signal(c.generation,'play','leave');near(c.buttons.play.alpha,.9,'focus retains glow after leave');c:signal(c.generation,'play','blur');near(c.buttons.play.alpha,0,'blur clears focus glow')
print('MENU_SEMANTIC_PASS assertions='..checks..' input_verified=false')
