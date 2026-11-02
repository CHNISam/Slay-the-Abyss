-- Figma App.tsx curve: M ax ay C ax midY, bx midY, bx by.
-- Presentation only: no game RNG, topology generation or gameplay writes.
local M={}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function validate(a,b)
 assert(finite(a.x)and finite(a.y)and finite(b.x)and finite(b.y),'finite curve endpoints required')
 assert(b.y>a.y,'route must ascend')
end
function M.point(a,b,t)
 local u=1-t;local m=(a.y+b.y)/2
 return {x=u*u*u*a.x+3*u*u*t*a.x+3*u*t*t*b.x+t*t*t*b.x,
 y=u*u*u*a.y+3*u*u*t*m+3*u*t*t*m+t*t*t*b.y}
end
function M.sample(a,b,count)
 validate(a,b); assert(type(count)=='number'and count>=1 and count<=128 and count%1==0,'bounded subdivision required')
 local result={};for i=0,count do result[#result+1]=M.point(a,b,i/count) end;return result
end
local function arc(a,b)
 local points=M.sample(a,b,64);local total=0;points[1].distance=0
 for i=2,#points do local p,q=points[i-1],points[i];total=total+math.sqrt((q.x-p.x)^2+(q.y-p.y)^2);q.distance=total end
 return points,total
end
local function at(points,d)
 for i=2,#points do local a,b=points[i-1],points[i]
  if d<=b.distance then local t=(d-a.distance)/(b.distance-a.distance);return {x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t} end
 end
 return points[#points]
end
local function bounds(v)assert(v and finite(v.bottom)and finite(v.top)and v.top>v.bottom,'valid viewport required')end
function M.segments(a,b,viewport,count,r1,r2)
 bounds(viewport);M.sample(a,b,count)
 local points,total=arc(a,b);r1,r2=r1 or 0,r2 or 0
 assert(finite(r1)and finite(r2)and r1>=0 and r2>=0,'nonnegative trim required')
 local result={};if total<=r1+r2 then return result end
 for i=0,count-1 do
  local p=at(points,r1+(total-r1-r2)*i/count)
  local q=at(points,r1+(total-r1-r2)*(i+1)/count)
  if q.y>=viewport.bottom and p.y<=viewport.top then
   local lo=math.max(0,(viewport.bottom-p.y)/(q.y-p.y));local hi=math.min(1,(viewport.top-p.y)/(q.y-p.y))
   local x1,y1=p.x+(q.x-p.x)*lo,p.y+(q.y-p.y)*lo
   local x2,y2=p.x+(q.x-p.x)*hi,p.y+(q.y-p.y)*hi
   local dx,dy=x2-x1,y2-y1;local len=math.sqrt(dx*dx+dy*dy)
   if len>0 then result[#result+1]={x1=x1,y1=y1,x2=x2,y2=y2,x=(x1+x2)/2,y=(y1+y2)/2,length=len,angle=math.atan(dy,dx)*180/math.pi}end
  end
 end
 return result
end
function M.dots(a,b,viewport,spacing,phase,r1,r2,capacity)
 bounds(viewport);assert(finite(spacing)and spacing>0,'positive dot spacing required')
 assert(finite(phase),'finite phase required');assert(capacity>=1 and capacity%1==0,'positive capacity required')
 local points,total=arc(a,b);local result={};local start=(r1 or 0)+phase%spacing;local finish=total-(r2 or 0)
 for d=start,finish,spacing do local p=at(points,d)
  if p.y>=viewport.bottom and p.y<=viewport.top then assert(#result<capacity,'curve dot capacity exceeded');result[#result+1]=p end
 end
 return result
end
return M
