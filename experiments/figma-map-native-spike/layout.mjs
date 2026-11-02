// Explicit experiment builder. Does not write production theme or default UI.
import {readFileSync} from 'node:fs';import {resolve} from 'node:path';import {pathToFileURL} from 'node:url';
export const ROOT=process.env.ABYSS_ROOT;
if(!process.env.ABYSS_ROOT)throw Error('Set ABYSS_ROOT to the verified source snapshot');
const {mapLayout,mapGeometry}=await import(pathToFileURL(resolve(ROOT,'scripts/map-ui-layout.mjs')));
export const theme=JSON.parse(readFileSync(resolve(ROOT,'data/presentation/ui_theme.json')));
theme.canvas.base=[1600,900];theme.layout.map.viewportHeight=800;theme.color.backdrop='#0b0606';theme.layout.map.floorGap=100;theme.layout.map.columnGap=100;
export const geometry=mapGeometry(theme);geometry.viewport={left:-450,right:450,bottom:-450,top:374};geometry.firstY=-190;geometry.focusY=-90;geometry.maxScroll=geometry.firstY+16*100-geometry.focusY;export const tree=mapLayout(theme);
const panel=tree.controls[1].children[0];
const image=(name,x,y,w,h,colour,id=100001)=>({name,kind:'image',position:[x,y],size:[w,h],colour,image:id});
const text=(name,x,y,w,h,content='',fontSize=20)=>({name,kind:'text',position:[x,y],size:[w,h],text:{content,fontSize,minFontSize:fontSize,align:'centre',valign:'middle',colour:'#e9c77b'}});
const hit=(name,x,y,w,h)=>({name,kind:'cursorArea',position:[x,y],size:[w,h],focusable:true});
function group(name,children){return {name,kind:'container',size:[1600,900],children}}
const decorations=[image('figmaBackdrop',0,0,1600,900,'#0b0606'),{name:'figmaFog',kind:'container',position:[-50,0],size:[1000,720],children:Array.from({length:14},(_,i)=>({...image('fogLayer'+i,0,0,1000-i*48,720-i*32,'#705439',100002),opacity:.012}))}];
// Source App.tsx ritual SVG: exact radii, dashed 380 ring, 48 ticks, two squares.
const stroke=(name,x1,y1,x2,y2,width,opacity=.1)=>({...image(name,(x1+x2)/2,(y1+y2)/2,Math.hypot(x2-x1,y2-y1)+.2,width,'#c9a15e'),opacity,rotation:Math.atan2(y2-y1,x2-x1)*180/Math.PI});
const ritual=[];
for(const [i,r]of [420,300,210].entries())for(let j=0;j<160;j++){
 const a=j/160*Math.PI*2,b=(j+1)/160*Math.PI*2;
 ritual.push(stroke(`ritualRing${i}Seg${j}`,Math.cos(a)*r,Math.sin(a)*r,Math.cos(b)*r,Math.sin(b)*r,i===2?1.5:1));
}
for(let j=0;j<199;j++){const a=j/199*Math.PI*2;ritual.push({...image('ritualDash'+j,Math.cos(a)*380,Math.sin(a)*380,3,3,'#c9a15e',100002),opacity:.1});}
for(let j=0;j<48;j++){const a=j*Math.PI/24,r=j%4?408:394;ritual.push(stroke('ritualTick'+j,Math.cos(a)*r,Math.sin(a)*r,Math.cos(a)*420,Math.sin(a)*420,1.5));}
for(const [k,size,angle]of [[0,300,Math.PI/4],[1,212,0]]){
 const points=[[-1,-1],[1,-1],[1,1],[-1,1]].map(([x,y])=>[(x*Math.cos(angle)-y*Math.sin(angle))*size/2,(x*Math.sin(angle)+y*Math.cos(angle))*size/2]);
 for(let j=0;j<4;j++)ritual.push(stroke(`ritualSquare${k}Edge${j}`,...points[j],...points[(j+1)%4],k?1:1.5));
}
decorations.push({name:'ritualDisc',kind:'container',position:[0,0],size:[900,900],children:batches('ritualBatch',ritual)});
// Exact 34px CSS meander path; alpha envelope approximates source vertical mask.
const meander=[[5,29],[5,5],[29,5],[29,25],[11,25],[11,11],[23,11],[23,19],[18,19],[18,15],[18,15]];
for(const [side,x]of [['Left',-744],['Right',516]])for(let j=0;j<28;j++){
 const y=450-j*34,alpha=.5*Math.min(1,Math.max(0,(450-Math.abs(y))/200));
 for(let k=0;k<10;k++){const a=meander[k],b=meander[k+1];decorations.push({...stroke(`pillar${side}${j}Seg${k}`,x+a[0],y-a[1],x+b[0],y-b[1],2,alpha),colour:'#6e5a42'});}
}
// Reference 26 ambient embers; deterministic visual phases never touch game RNG.
for(let i=0;i<26;i++)decorations.push({name:'ember'+i,kind:'container',size:[16,16],children:[{...image('emberGlow'+i,0,0,13,13,'#f0bc72',100002),opacity:.045},{...image('emberMid'+i,0,0,7,7,'#f0bc72',100002),opacity:.1},{...image('emberCore'+i,0,0,2+(i*7%25)/10,2+(i*7%25)/10,'#f6c978',100002),opacity:.6}]});
function batches(prefix,children){const r=[];for(let i=0;i<children.length;i+=60)r.push(group(prefix+(i/60+1),children.slice(i,i+60)));return r}
// Existing group names stay unchanged because MapUI resolves their contract.
panel.children.unshift(...batches('figmaBack',decorations));
const glow=[],shapes=[];
for(let i=1;i<=256;i++)glow.push({...image('g'+i,0,0,1,1,'#65502f',106057),visible:false});
for(let i=1;i<=1536;i++)shapes.push({...image('p'+i,0,0,1,1,'#e9c77b'),visible:false});
panel.children.push(...batches('figmaGlow',glow),...batches('figmaShape',shapes));
const front=[{name:'tokenHalo',kind:'container',size:[330,214],children:Array.from({length:40},(_,i)=>({...image('halo'+i,0,0,330-i*7.8,214-i*5,'#e9c77b',100002),opacity:.004}))},{name:'tokenOuter',kind:'container',size:[44,64],scale:[.6875,1],children:[{...image('outerGold',0,0,45.255,45.255,'#e9c77b'),rotation:45}]},{name:'tokenInner',kind:'container',size:[32,48],scale:[.666667,1],children:[{...image('innerInk',0,0,33.941,33.941,'#160e09'),rotation:45}]},image('tokenStar',0,0,18,30,'#f6dfa4',100004),
 image('hudPlate',0,324,1280,72,'#0b0606'),text('figmaTitle',-12,319,180,50,'',24),{...text('floorDenominator',69,315,44,32,'/17',11),text:{...text('',0,0,0,0,'/17',11).text,colour:'#7d6c55'}},text('figmaHP',-545,324,80,40,'',14),text('figmaGold',-385,324,80,36,'',14),text('figmaDeck',520,324,70,36,'',14),
 image('legendBorder',540,0,179,317,'#5c4b36'),image('legendPlate',540,0,177,315,'#17100c'),text('legendTitle',540,137,160,38,'图 例',13)];
front.push({...image('hudDivider',0,284,1100,1,'#6e5a42'),opacity:.35}, {...image('actRuleLeft',-66,345,42,.7,'#6e5a42'),opacity:.5}, {...image('actRuleRight',66,345,42,.7,'#6e5a42'),opacity:.5});
const pills=[];
for(const [key,x,w]of [['HP',-535,145],['Gold',-390,105],['Deck',520,95]]){
 for(const [suffix,dy,h,ink]of [['Border',0,35,'#6e5a42'],['Fill',0,33,'#0d0708']]){
  const width=suffix==='Border'?w:w-2;pills.push(image('pill'+key+suffix,x,324,width-h,h,ink),image('pill'+key+suffix+'L',x-(width-h)/2,324,h,h,ink,100002),image('pill'+key+suffix+'R',x+(width-h)/2,324,h,h,ink,100002));
 }
}
front.splice(5,0,...pills);
front.push(image('hpTrack',-488,324,36,4,'#2a1a16'),image('hpAmount',-488,324,36,4,'#d9574a'));
front.push(image('hudHeart',-583,324,17,17,'#d9574a',102018),image('hudCoin',-422,324,17,17,'#e9c77b',105077),image('hudCards',494,324,19,19,'#e9c77b',105046),text('actTitle',0,345,220,25,'第 一 幕',13));
for(let i=1;i<=3;i++){front.push(image('potionBorder'+i,-300+(i-1)*40,324,32,32,'#6e5a42',100002),image('potionInside'+i,-300+(i-1)*40,324,30,30,'#0d0708',100002),{...image('potion'+i,-300+(i-1)*40,324,17,23,'#ffffff',102002),visible:false});}
for(let f=1;f<=17;f++)front.push({...image('progress'+f,-72+(f-1)*9,292,4.3,4.3,'#4a3b2c'),rotation:45});
for(let f=1;f<=17;f++)front.push({...image('progressHole'+f,-72+(f-1)*9,292,2.5,2.5,'#0b0606'),rotation:45});
const names=['普通战斗','精英','未知事件','商店','营地','宝箱','首领'];const types=['combat','elite','event','shop','camp','treasure','boss'];
const colors=['#e4695a','#b79bea','#8cc4e2','#7fd1b9','#ffa95c','#f6dfa4','#ff5a4a'];
for(let i=0;i<7;i++)front.push(image('legendIcon'+i,482,98-i*36,25,25,colors[i],theme.icon.node[types[i]]),{...text('legendText'+i,547,98-i*36,112,36,names[i],14),text:{...text('',0,0,0,0,names[i],14).text,colour:'#c9c3b6'}},text('legendCount'+i,613,98-i*36,26,36,'',11),hit('legendHit'+i,540,98-i*36,180,36));
for(let f=1;f<=17;f++)front.push({...image('floorMark'+f,-562,-300+(f-1)*35,4,4,'#6e5a42'),rotation:45},text('floorLabel'+f,-539,-300+(f-1)*35,34,40,String(f),12),hit('floorHit'+f,-562,-300+(f-1)*35,36,32));
for(let f=1;f<=17;f++)front.push({...image('floorMarkHole'+f,-562,-300+(f-1)*35,2,2,'#0b0606'),rotation:45},{...image('floorCurrentGlow'+f,-562,-300+(f-1)*35,20,20,'#e9c77b',100002),opacity:.13,visible:false});
front.push(text('figmaStatus',0,-333,900,44,'',18));
for(const c of front){
 const n=c.name;if(n.startsWith('token'))continue;
 if(n.startsWith('legend'))c.position[0]+=151;
 else if(n.startsWith('floor')){if(n!=='floorDenominator'){c.position[0]-=160;c.position[1]*=1.24}else c.position[1]+=90}
 else if(n.startsWith('progress'))c.position[1]+=90;
 else if(n==='figmaStatus')c.position[1]-=85;
 else {c.position[1]+=95;if(c.position[0]<-100)c.position[0]-=160;else if(c.position[0]>100)c.position[0]+=120;}
 if(n==='actTitle'||n.startsWith('actRule'))c.position[1]=430;
 if(n==='figmaTitle')c.position[1]=405;
 if(n==='floorDenominator')c.position[1]=400;
 if(n.startsWith('progress'))c.position[1]=384;
 if(n==='hudPlate'){c.size=[1600,76];c.position[1]=412;}
 if(n==='hudDivider'){c.size=[1460,1];c.position[1]=374;}
}
panel.children.push(...batches('figmaFront',front));
// Preserve native node hit boxes above visual route overlays.
const nodeGroups=panel.children.filter(g=>g.name.startsWith('mapGroup')&&g.children.some(c=>c.name.startsWith('node')));
for(const g of nodeGroups){panel.children.splice(panel.children.indexOf(g),1);panel.children.push(g)}
export const controls=tree;
// Native overlay controls, no separate game/navigation owner.
const label=(name,x,y,w,h,value,size=14,ink='#c9c3b6')=>({...text(name,x,y,w,h,value,size),text:{...text('',0,0,0,0,value,size).text,colour:ink}});
const menuRow=(name,y,value)=>({name:name+'Row',kind:'container',position:[0,y],size:[228,38],children:[label(name+'Label',0,0,210,38,value),hit(name,0,0,228,38)]});
const menuButton=group('menuButton',[image('menuBorder',760,419,40,40,'#6e5a42',100002),image('menuFill',760,419,38,38,'#1a1312',100002),...[-5,0,5].map((y,i)=>image('menuBar'+i,760,419+y,16,1.5,'#e9c77b')),hit('menuHit',760,419,40,40)]);
const tooltip={name:'mapTooltip',kind:'container',position:[0,0],size:[210,116],visible:false,children:[image('tipBorder',0,0,212,118,'#6e5a42'),image('tipPlate',0,0,210,116,'#17100c'),label('tipName',-18,37,140,36,'',16),label('tipFloor',76,37,34,30,'',11,'#9e8c72'),label('tipDescription',0,0,188,46,'',12),label('tipState',0,-35,188,32,'',11,'#bbaa8c')]};
const mapMenu={name:'mapMenu',kind:'container',size:[1600,900],visible:false,children:[hit('menuDismiss',0,0,1600,900),{name:'menuPopup',kind:'container',position:[666,282],size:[228,180],children:[image('menuEdge',0,0,230,182,'#6e5a42'),image('menuPlate',0,0,228,180,'#17100c'),{name:'menuMain',kind:'container',size:[228,180],children:[menuRow('menuContinue',55,'继续冒险'),menuRow('menuLegend',15,'收起图例'),menuRow('menuHelpHit',-25,'操作说明'),label('menuScope',0,-65,214,26,'地图切片 · 未接完整游戏菜单',11,'#7d6c55')]},{name:'menuHelp',kind:'container',size:[228,180],visible:false,children:[label('helpTitle',0,65,208,30,'操作说明',15,'#e9c77b'),label('helpText',0,-5,204,132,'拖拽：上下查看路线\n发亮节点：点击前进\n鼠标悬停：预览信息与路线\n手机点按未达节点：查看信息\n图例：点击锁定类型\n左侧刻度：定位楼层',13)]}]}]};
panel.children.push(menuButton,tooltip,mapMenu);
const pickEffects=[{...image('pickedIcon',0,0,32,32,'#e9c77b',102044),visible:false}];
for(let i=0;i<10;i++)pickEffects.push({name:'pickSpark'+i,kind:'container',size:[16,16],visible:false,children:[{...image('pickSparkGlow'+i,0,0,12,12,'#e9c77b',100002),opacity:.1},image('pickSparkCore'+i,0,0,4,4,'#f6dfa4',100002)]});
panel.children.splice(panel.children.length-3,0,group('pickEffects',pickEffects));
// Immutable baseline anchor inventory for native resize; no CSS screenshots baked in.
geometry.figmaAnchors={};
for(const c of front){if(c.position)geometry.figmaAnchors[c.name]=c.position;}
for(const c of menuButton.children){geometry.figmaAnchors[c.name]=c.position;}
