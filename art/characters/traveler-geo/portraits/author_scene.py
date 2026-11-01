"""Two purpose-specific RGBA benchmarks, authored into the existing editor schema.

A bounded colour-region draft, not the rejected 64/256-ellipse Primitive fit.
It preserves alpha, omits only fully transparent cells and never changes UI.
The existing pinned editor remains the only JSON/Lua/PNG exporter.
"""
from pathlib import Path
from PIL import Image
import argparse,hashlib,json
ROOT=Path(__file__).resolve().parent

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--asset',choices=['avatar96','battle133'],required=True);args=parser.parse_args()
    folder=ROOT/args.asset;n={'avatar96':96,'battle133':133}[args.asset]
    source=folder/'source.png';original=Image.open(source).convert('RGBA');fitted=original.copy()
    fitted.thumbnail((n,n),Image.Resampling.LANCZOS)
    raster=Image.new('RGBA',(n,n),(0,0,0,0));offset=((n-fitted.width)//2,(n-fitted.height)//2);raster.alpha_composite(fitted,offset)
    rgb=raster.convert('RGB');alpha=raster.getchannel('A')
    # Hidden RGB cannot influence the visible palette; no nonzero alpha is removed.
    for y in range(n):
        for x in range(n):
            if alpha.getpixel((x,y))==0:rgb.putpixel((x,y),(0,0,0))
    indexed=rgb.quantize(colors=64,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE);palette=indexed.getpalette()
    active,rectangles={},[]
    for y in range(n):
        runs=[];x=0
        while x<n:
            a=alpha.getpixel((x,y))
            if a==0:x+=1;continue
            color=indexed.getpixel((x,y));end=x+1
            while end<n and alpha.getpixel((end,y))==a and indexed.getpixel((end,y))==color:end+=1
            runs.append((x,end,color,a));x=end
        next_active={}
        for key in runs:
            if key in active:rect=active.pop(key);rect[3]+=1
            else:rect=[key[0],y,key[1]-key[0],1,key[2],key[3]]
            next_active[key]=rect
        rectangles.extend(active.values());active=next_active
    rectangles.extend(active.values());rectangles.sort(key=lambda r:(r[1],r[0],r[3],r[2]))
    elements=[]
    for i,(x,y,w,h,color,a) in enumerate(rectangles):
        rgb_value=palette[color*3:color*3+3]
        elements.append(dict(id=f'lumine-v2-region-{i+1:04d}',name=f'rgba region {i+1}',type='rectangle',
            x=x+w/2,y=y+h/2,width=w,height=h,rotation=0,color='#'+''.join(f'{v:02X}' for v in rgb_value),opacity=a/255,zIndex=i))
    scene=dict(canvas=dict(width=n,height=n,background='transparent',mask=dict(enabled=False)),elements=elements,
        meta=dict(sourceType='json',sourceName='lumine-geo-v2-'+args.asset+'-rgba-colour-region-draft'))
    (folder/'editable.scene.json').write_text(json.dumps(scene,ensure_ascii=False,indent=2)+'\n')
    raster.save(folder/'preview-source-1x.png')
    raster.resize((n*4,n*4),Image.Resampling.NEAREST).save(folder/'preview-source-4x.png')
    draft=indexed.convert('RGBA');draft.putalpha(alpha);draft.save(folder/'preview-redraw-draft-1x.png')
    draft.resize((n*4,n*4),Image.Resampling.NEAREST).save(folder/'preview-redraw-draft-4x.png')
    record=dict(schemaVersion=2,purpose='head-only selection avatar' if args.asset=='avatar96' else 'right-facing full-body battle figure',
        sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),sourceSize=list(original.size),sourceMode='RGBA',
        targetSize=[n,n],fit='contain, no crop/stretch',fittedSize=list(fitted.size),offset=list(offset),paletteColors=64,
        alphaPolicy='preserve all resampled alpha values; omit exactly alpha=0 cells only',
        imageControls=len(elements),masks=0,contentBounds='all geometry inside canvas; transparent cells omitted',
        stage='first offline authoring draft, not final native visual approval',pillowVersion=Image.__version__,
        productionEnabled=False,gilDeltaBytes=None,officialUploadDeltaBytes=None)
    (folder/'redraw-recipe.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');print(json.dumps(record))
if __name__=='__main__':main()
