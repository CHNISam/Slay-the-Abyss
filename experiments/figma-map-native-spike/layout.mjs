// Explicit experiment builder. Does not write production theme or default UI.
import {readFileSync} from 'node:fs';import {resolve} from 'node:path';import {pathToFileURL} from 'node:url';
export const ROOT=process.env.ABYSS_ROOT;
if(!process.env.ABYSS_ROOT)throw Error('Set ABYSS_ROOT to the verified source snapshot');
const {mapLayout,mapGeometry}=await import(pathToFileURL(resolve(ROOT,'scripts/map-ui-layout.mjs')));
export const theme=JSON.parse(readFileSync(resolve(ROOT,'data/presentation/ui_theme.json')));
theme.color.backdrop='#0b0606';theme.layout.map.floorGap=100;theme.layout.map.columnGap=100;
export const geometry=mapGeometry(theme);export const tree=mapLayout(theme);
const panel=tree.controls[1].children[0];
const image=(name,x,y,w,h,colour,id=100001)=>({name,kind:'image',position:[x,y],size:[w,h],colour,image:id});
const text=(name,x,y,w,h,content='',fontSize=20)=>({name,kind:'text',position:[x,y],size:[w,h],text:{content,fontSize,minFontSize:fontSize,align:'centre',valign:'middle',colour:'#e9c77b'}});
const hit=(name,x,y,w,h)=>({name,kind:'cursorArea',position:[x,y],size:[w,h],focusable:true});
function group(name,children){return {name,kind:'container',size:[1280,720],children}}
const decorations=[image('figmaBackdrop',0,0,1280,720,'#0b0606'),{name:'figmaFog',kind:'container',position:[-50,0],size:[1000,720],children:Array.from({length:14},(_,i)=>({...image('fogLayer'+i,0,0,1000-i*48,720-i*32,'#705439',100002),opacity:.012}))}];
for(const [i,r]of [420,380,300,210].entries()){
 const strokes=[];const count=128;
 for(let j=0;j<count;j++){const a=j/count*Math.PI*2,b=(j+1)/count*Math.PI*2,x1=Math.cos(a)*r,y1=Math.sin(a)*r,x2=Math.cos(b)*r,y2=Math.sin(b)*r;
 strokes.push({...image('ringStroke'+j,(x1+x2)/2,(y1+y2)/2,Math.hypot(x2-x1,y2-y1)+.3,i===3?1.2:.8,'#c9a15e'),opacity:.10,rotation:Math.atan2(y2-y1,x2-x1)*180/Math.PI});}
 decorations.push({name:'ritual'+i,kind:'container',position:[-50,0],size:[900,900],children:[0,1,2].map(k=>({name:'ringBatch'+k,kind:'container',size:[900,900],children:strokes.slice(k*50,(k+1)*50)}))});
}
for(let side of [-1,1])for(let j=0;j<10;j++){
 const x=side===-1?-555:445,y=-300+j*68;
 // Small key-pattern pillars: actual vector strokes, not a raster replacement.
 decorations.push(image(`pillar${side}_${j}a`,x,y,24,2,'#392d21'),image(`pillar${side}_${j}b`,x-12,y-12,2,24,'#392d21'),image(`pillar${side}_${j}c`,x+4,y-12,16,2,'#392d21'));
}
function batches(prefix,children){const r=[];for(let i=0;i<children.length;i+=60)r.push(group(prefix+(i/60+1),children.slice(i,i+60)));return r}
// Existing group names stay unchanged because MapUI resolves their contract.
panel.children.unshift(...batches('figmaBack',decorations));
const glow=[],shapes=[];
for(let i=1;i<=256;i++)glow.push({...image('g'+i,0,0,1,1,'#65502f',106057),visible:false});
for(let i=1;i<=1536;i++)shapes.push({...image('p'+i,0,0,1,1,'#e9c77b'),visible:false});
panel.children.push(...batches('figmaGlow',glow),...batches('figmaShape',shapes));
const front=[{name:'tokenHalo',kind:'container',size:[240,170],children:Array.from({length:12},(_,i)=>({...image('halo'+i,0,0,240-i*17,170-i*11,'#c5a15b',100002),opacity:.025}))},{name:'tokenOuter',kind:'container',size:[44,64],scale:[.6875,1],children:[{...image('outerGold',0,0,45.255,45.255,'#e9c77b'),rotation:45}]},{name:'tokenInner',kind:'container',size:[32,48],scale:[.666667,1],children:[{...image('innerInk',0,0,33.941,33.941,'#160e09'),rotation:45}]},image('tokenStar',0,0,18,30,'#f6dfa4',100004),
 image('hudPlate',0,324,1280,72,'#0b0606'),text('figmaTitle',0,313,300,50,'',24),text('figmaHP',-545,324,80,40,'',14),text('figmaGold',-385,324,80,36,'',17),text('figmaDeck',520,324,70,36,'',17),
 image('legendBorder',540,0,179,317,'#5c4b36'),image('legendPlate',540,0,177,315,'#17100c'),text('legendTitle',540,137,160,38,'图 例',14)];
const pills=[];
for(const [key,x,w]of [['HP',-535,145],['Gold',-390,105],['Deck',520,95]]){
 for(const [suffix,dy,h,ink]of [['Border',0,35,'#6e5a42'],['Fill',0,33,'#0d0708']]){
  const width=suffix==='Border'?w:w-2;pills.push(image('pill'+key+suffix,x,324,width-h,h,ink),image('pill'+key+suffix+'L',x-(width-h)/2,324,h,h,ink,100002),image('pill'+key+suffix+'R',x+(width-h)/2,324,h,h,ink,100002));
 }
}
front.splice(5,0,...pills);
front.push(image('hpTrack',-488,324,36,4,'#2a1a16'),image('hpAmount',-488,324,36,4,'#d9574a'));
front.push(image('hudHeart',-583,324,17,17,'#d9574a',102018),image('hudCoin',-422,324,17,17,'#e9c77b',105077),image('hudCards',494,324,19,19,'#e9c77b',105046),text('actTitle',0,344,220,25,'第 一 幕',14));
for(let i=1;i<=3;i++){front.push(image('potionBorder'+i,-300+(i-1)*40,324,32,32,'#6e5a42',100002),image('potionInside'+i,-300+(i-1)*40,324,30,30,'#0d0708',100002),{...image('potion'+i,-300+(i-1)*40,324,17,23,'#ffffff',102002),visible:false});}
for(let f=1;f<=17;f++)front.push(image('progress'+f,-64+(f-1)*8,283,5,5,'#4a3b2c',100004));
const names=['普通战斗','精英','未知事件','商店','营地','宝箱','首领'];const types=['combat','elite','event','shop','camp','treasure','boss'];
const colors=['#e4695a','#b79bea','#8cc4e2','#7fd1b9','#ffa95c','#f6dfa4','#ff5a4a'];
for(let i=0;i<7;i++)front.push(image('legendIcon'+i,482,98-i*36,25,25,colors[i],theme.icon.node[types[i]]),{...text('legendText'+i,547,98-i*36,112,36,names[i],15),text:{...text('',0,0,0,0,names[i],15).text,colour:'#c9c3b6'}},text('legendCount'+i,613,98-i*36,26,36,'',11),hit('legendHit'+i,540,98-i*36,180,36));
for(let f=1;f<=17;f++)front.push(image('floorMark'+f,-586,-300+(f-1)*35,7,7,'#6e5a42',theme.image.diamond),text('floorLabel'+f,-555,-300+(f-1)*35,34,40,String(f),12),hit('floorHit'+f,-586,-300+(f-1)*35,36,32));
front.push(text('figmaStatus',0,-333,900,44,'',18));
panel.children.push(...batches('figmaFront',front));
// Preserve native node hit boxes above visual route overlays.
const nodeGroups=panel.children.filter(g=>g.name.startsWith('mapGroup')&&g.children.some(c=>c.name.startsWith('node')));
for(const g of nodeGroups){panel.children.splice(panel.children.indexOf(g),1);panel.children.push(g)}
export const controls=tree;
