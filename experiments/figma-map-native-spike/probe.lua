-- curve.lua is bundled ahead of this script. No gameplay owner is created here.
local time=0;local groups={};local a,b={x=-85,y=-130},{x=85,y=130}
local function draw(k,phase)
 local g=groups[k+1];local v=k==3 and {bottom=-60,top=60}or{bottom=-190,top=190}
 local solid=k==0 or k==3
 local values=solid and Curve.segments(a,b,v,16,25,25)or Curve.dots(a,b,v,11,phase,25,25,32)
 for i=1,32 do local c=g:GetChild('shape'):GetChild('p'..i);local p=values[i];c:SetVisible(p~=nil)
  if p then c:SetAnchoredPosition(p.x,p.y);c:SetSizeDelta(solid and p.length+0.5 or 3,solid and 3.2 or 3);c.localRotationZ=solid and p.angle or 0 end
 end
 for i=1,16 do local c=g:GetChild('glow'):GetChild('g'..i);local p=solid and values[i];c:SetVisible(p~=nil)
  if p then c:SetAnchoredPosition(p.x,p.y);c:SetImage(Enum.ImageSource.StaticReference,100001);c.imageColor=Color(233,199,123,38);c:SetSizeDelta(p.length+.5,9);c.localRotationZ=p.angle end
 end
end
function OnStart()
 script.object.showCursor=true
 for k=0,3 do groups[k+1]=script.object:GetChild('probe'..k);draw(k,0)end
 script:EnableUpdate(true);print('CURVE_PROBE_READY segments=16 dotCapacity=32 probes=4')
end
function OnUpdate(dt)
 time=time+math.max(0,math.min(dt or 0,.1));draw(2,time*14/1.1)
end
