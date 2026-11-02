package.path = './?.lua;' .. package.path
local ok, Curve = pcall(require, 'curve')
assert(ok, 'native curve implementation is required')
local a,b={x=-140,y=-90},{x=120,y=110}
local p=Curve.point(a,b,0); assert(p.x==a.x and p.y==a.y)
p=Curve.point(a,b,1); assert(p.x==b.x and p.y==b.y)
p=Curve.point(a,b,.5); assert(math.abs(p.x+10)<.00001 and math.abs(p.y-10)<.00001)
local samples=Curve.sample(a,b,16)
assert(#samples==17)
for i=2,#samples do assert(samples[i].y>samples[i-1].y) end
local segments=Curve.segments(a,b,{bottom=-40,top=60},16,12,18)
assert(#segments>0 and #segments<=16)
for _,s in ipairs(segments)do assert(s.y1>=-40 and s.y2<=60 and s.length>0) end
assert(#Curve.segments(a,b,{bottom=200,top=300},16,12,18)==0)
local straight=Curve.segments({x=0,y=0},{x=0,y=100},{bottom=-10,top=110},16,12,18)
assert(math.abs(straight[1].y1-12)<.001)
assert(math.abs(straight[#straight].y2-82)<.001)
local dots=Curve.dots(a,b,{bottom=-40,top=60},8,0,12,18,64)
assert(#dots>0 and #dots<=64)
for _,d in ipairs(dots)do assert(d.y>=-40 and d.y<=60) end
assert(not pcall(Curve.dots,a,b,{bottom=-100,top=200},1,0,0,0,1),'capacity must fail, not silently drop route')
assert(not pcall(Curve.sample,a,b,0))
print('CURVE_PASS endpoints clipping radius trim bounded pool invalid limits')
local first=Curve.dots({x=0,y=0},{x=100,y=100},{bottom=-1,top=101},8,0,0,0,128)
for offset=-500,500,100 do local shifted=Curve.dots({x=37,y=offset},{x=137,y=offset+100},{bottom=offset-1,top=offset+101},8,0,0,0,128);assert(#shifted==#first);for i,p in ipairs(first)do assert(math.abs(shifted[i].x-p.x-37)<1e-8 and math.abs(shifted[i].y-p.y-offset)<1e-8,'translated arcs must preserve points')end end
local originalSample,builds=Curve.sample,0
Curve.sample=function(...)builds=builds+1;return originalSample(...)end
for offset=0,100 do Curve.dots({x=offset,y=offset},{x=offset+123,y=offset+197},{bottom=offset-1,top=offset+198},8,0,0,0,128)end
Curve.sample=originalSample
assert(builds==1,'uniform scrolling must reuse one normalized arc sample, not rebuild each frame')
