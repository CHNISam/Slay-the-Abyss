// Candidate-only instrumentation. Refuse changed anchors rather than silently
// patching a different production card lifecycle.
export function instrumentCardTween(source){
 source=source.replaceAll('\r\n','\n');
 const once=(needle,replacement)=>{if(source.split(needle).length!==2)throw Error('Card Tween integration anchor changed: '+needle);source=source.replace(needle,replacement);};
 once('local M = {}',"local TweenLab=require('abyss_3d_card_tween')\nlocal M = {}");
 once('local function writeHandValues(box,hit,v)','local function writeHandValues(box,hit,v)\n    TweenLab.recordPaint(box)');
 once('    local handGeometryOwner={}',`    local handGeometryOwner={}
    local tweenLab=TweenLab.attach(view,{entries=function()return handPoses end,
        paint=function(entry)handGeometry[entry.box]=nil;applyHandPose(entry,handGeometryOwner)end})`);
 once('            openingHand=current~=handBattle and current~=nil',"            tweenLab:cancel('battle_or_resize')\n            openingHand=current~=handBattle and current~=nil");
 once('    local function handPose(box,instance,count,index,hot)',`    local function handPose(box,instance,count,index,hot)
        local owned=handPoses[instance.uid]
        if tweenLab:holdRender(owned,box,count,index,hot) then
            owned.visible=true
            return {owned.current.x,owned.current.y}
        end`);
 once('        entry.box,entry.target,entry.visible=box,target,true',`        entry.box,entry.target,entry.visible=box,target,true
        entry.labUid=instance.uid
        entry.labLayout={count=count,index=index,hot=hot}`);
 once('for uid,entry in pairs(handPoses) do if not entry.visible then handPoses[uid]=nil end end',"for uid,entry in pairs(handPoses) do if not entry.visible then tweenLab:removed(entry);handPoses[uid]=nil end end");
 once('    local function placeDraggedCard(box, g, aiming)',"    local function placeDraggedCard(box, g, aiming)\n        tweenLab:cancel('drag')");
 once(`            if not (held and held.moving and held.uid==uid) then
                advancePose(entry,dt,view.fastMode==true)
                applyHandPose(entry,handGeometryOwner)
                view.cardPositions[uid]={entry.current.x,entry.current.y}
            end`, `            local nativeOwned=tweenLab:before(entry,dt,held)
            if not nativeOwned and not (held and held.moving and held.uid==uid) then
                advancePose(entry,dt,view.fastMode==true)
                applyHandPose(entry,handGeometryOwner)
            end
            view.cardPositions[uid]={entry.current.x,entry.current.y}
            tweenLab:after(entry)`);
 return source;
}
