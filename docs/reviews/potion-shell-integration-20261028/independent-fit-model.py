"""Read-only analytic review of Map/Main potion shell; NOT native texture proof.
Masks intentionally use the existing offline renderer's linear radial model.
All RGBs are derived by interpolating the two approved source colors.
"""
import json,math
from pathlib import Path
import numpy as np
from scipy.optimize import lsq_linear, minimize_scalar
OUT=Path(__file__).parent
D=34.667;B=1;R=(D-2*B)/2;F=D*.15
CSS_R=math.hypot(26,33.8)*2/3
# Sample the face uniformly, excluding the one-native-px rim.
x,y=np.meshgrid(np.linspace(-R,R,321),np.linspace(-R,R,321));disk=x*x+y*y<=R*R
x=x[disk];y=y[disk]
want=np.clip(1-np.hypot(x,y-F)/CSS_R,0,1)
def mask(cx,cy,r):return np.clip(1-np.hypot(x-cx,y-cy)/r,0,1)
old=mask(0,F,R-F)
# fixed no-bleed full inner disc + one no-bleed upper disc
full=mask(0,0,R)
def fit_for(cy,third=False):
    upper=mask(0,cy,R-abs(cy))
    masks=[full,upper]
    if third:masks.append(mask(0,-cy,R-abs(cy)))
    # Layer colors are independent 0..1 mixtures of source dark and light.
    # Alpha compositing remains linear in the per-layer color mixtures.
    rem=np.ones_like(want); cols=[]
    for a in reversed(masks):cols.append(a*rem);rem*=1-a
    A=np.column_stack([rem]+list(reversed(cols)))
    # 3 variable unconstrained solution, projected only if needed.
    q=np.linalg.lstsq(A,want,rcond=None)[0]
    if np.any(q<0)or np.any(q>1):q=lsq_linear(A,want,bounds=(0,1),tol=1e-9).x
    pred=A@q
    return float(np.mean((pred-want)**2)),q,pred,masks
result=minimize_scalar(lambda cy:fit_for(cy)[0],bounds=(.05*R,.9*R),method='bounded',options={'xatol':1e-5})
cy=float(result.x);_,q,new,masks=fit_for(cy)
# Native theme uses rounded RGB; re-evaluate exact composition with final RGBs.
def rgb(h):return np.array([int(h[i:i+2],16)for i in(1,3,5)],float)
def metric(pred,source):
    err=pred-source
    return dict(mae=float(np.mean(np.abs(err))),rmse=float(np.sqrt(np.mean(err**2))),maxAbs=float(np.max(np.abs(err))),p95Abs=float(np.quantile(np.abs(err),.95)))
report=dict(model='Existing offline linear-alpha discSoft semantic model only; NOT official texture/native pixel acceptance',
    geometry=dict(diameter=D,border=B,innerDiameter=2*R,focusY=F,sourceFarthestCornerRadius=CSS_R,currentLightDiameter=2*(R-F)),
    averageLightWeight=dict(source=float(np.mean(want)),current=float(np.mean(old))),
    proposal=dict(kind='Two bounded soft discs plus source-derived constant base; one added image per filled/fire group',
        sourceInterpolationWeights=q.tolist(),layers=[dict(name='light',position=[0,0],size=[2*R,2*R]),dict(name='focusLight',position=[0,cy],size=[2*(R-cy),2*(R-cy)])]),
    palettes={})
for name,light,dark in [('normal','#3A2E28','#221A17'),('fire','#4A2C24','#221A17')]:
    L=rgb(light);K=rgb(dark);target=K+want[:,None]*(L-K);previous=K+old[:,None]*(L-K)
    colours=np.round(K[None,:]+q[:,None]*(L-K)[None,:]).astype(int)
    px=np.tile(colours[0],(len(want),1)).astype(float)
    for c,a in zip(colours[1:],masks):px=c[None,:]*a[:,None]+px*(1-a[:,None])
    report['palettes'][name]=dict(colours={n:'#'+''.join(f'{v:02X}'for v in row)for n,row in zip(['base','light','focusLight'],colours)},
        currentRgbError=metric(previous,target),proposedRgbError=metric(px,target))
# Landmark point estimates independent of raster/font/icon.
points={'centre':(0,0),'focal':(0,F),'leftInnerEdge':(-R,0),'topInnerEdge':(0,R),'bottomInnerEdge':(0,-R),'upperQuarter':(0,R/2),'lowerQuarter':(0,-R/2)}
report['landmarks']={}
for label,(xx,yy)in points.items():
    t=max(0,1-math.hypot(xx,yy-F)/CSS_R);o=max(0,1-math.hypot(xx,yy-F)/(R-F))
    a=[max(0,1-math.hypot(xx,yy)/R),max(0,1-math.hypot(xx,yy-cy)/(R-cy))]
    details={}
    for name,light,dark in [('normal','#3A2E28','#221A17'),('fire','#4A2C24','#221A17')]:
        L=rgb(light);K=rgb(dark);cc=np.round(K[None,:]+q[:,None]*(L-K)[None,:]);p=cc[0]
        for c,alpha in zip(cc[1:],a):p=c*alpha+p*(1-alpha)
        details[name]=dict(source=np.round(K+t*(L-K),2).tolist(),current=np.round(K+o*(L-K),2).tolist(),proposal=np.round(p,2).tolist())
    report['landmarks'][label]=details
(OUT/'fit-shell.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
