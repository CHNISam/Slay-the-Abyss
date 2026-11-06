import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const save=JSON.parse(fs.readFileSync(path.join(dir,'seed.save.json')));
const root=save.assets.server.root.children[0];
const samples=Object.fromEntries(root.children.map(n=>[n.kind,n]));
root.children=[]; root.name='TravelerIdleLab'; root.scriptMappingIds=[1073788891];
let seq=0;
function node(kind,name,x,y,w,h,color,parent=root,extra={}) {
 const n=structuredClone(kind==='container'?root:samples[kind]);
 Object.assign(n,{id:'idle'+(++seq),guid:1074300000+seq,name,children:[],scriptMappingIds:[]});
 if(kind==='container')n.isRootContainer=false;
 for(const t of Object.values(n.transformByPlatform))Object.assign(t,{offset:{x,y},size:{x:w,y:h},scale:{x:1,y:1,z:1},rotation:{x:0,y:0,z:0}});
 if(kind==='image')Object.assign(n,{imageId:100001,imageColor:parseInt(color,16)>>>0});
 Object.assign(n,extra);parent.children.push(n);return n;
}
const group=(name,x,y,p=root)=>node('container',name,x,y,0,0,'',p);
function shape(name,x,y,w,h,c,id,p=root,rot=0){const n=node('image',name,x,y,w,h,c,p,{imageId:id});for(const t of Object.values(n.transformByPlatform))t.rotation.z=rot;return n;}
const rect=(n,x,y,w,h,c,p,r=0)=>shape(n,x,y,w,h,c,100001,p,r);
const oval=(n,x,y,w,h,c,p)=>shape(n,x,y,w,h,c,100002,p);
const tri=(n,x,y,w,h,c,p,r=0)=>shape(n,x,y,w,h,c,100003,p,r);
const diamond=(n,x,y,w,h,c,p,r=0)=>shape(n,x,y,w,h,c,100004,p,r);
const C={ink:'ff20232c',gold:'ffc69b48',light:'fff3db91',white:'fff1e8d7',shade:'ffc9bca6',skin:'ffeac5a1',brown:'ff40362e',teal:'ff6c9e86',rock:'ff49594c'};
rect('background',0,0,1600,900,'ff14212b');
rect('ground',0,-222,1600,3,'ff586155');
// Original primitive redraw of Aether's recognizable gold braid / white cape / dark outfit.
const a=group('traveler',-350,0);oval('shadow',0,-222,185,20,'55303838',a);
const cape=group('cape',-25,78,a);
tri('cape-outline',-18,-142,174,294,C.ink,cape,180);tri('cape-cloth',-18,-140,158,280,C.white,cape,180);
tri('cape-shade',-57,-150,63,245,C.shade,cape,180);rect('cape-edge',-81,-160,6,190,C.gold,cape,-12);
diamond('cape-star',-39,-137,35,50,C.gold,cape);
const legs=group('feet',0,0,a);
for(const [x,r]of[[-31,-5],[29,6]]){rect('leg-outline'+x,x,-143,39,113,C.ink,legs,r);rect('leg'+x,x,-143,29,106,C.brown,legs,r);rect('boot-gold'+x,x,-166,30,9,C.gold,legs,r);oval('boot'+x,x+4,-208,52,25,C.ink,legs);rect('boot-trim'+x,x+4,-213,45,4,C.gold,legs);}
const body=group('body',0,0,a);
oval('torso-outline',0,-8,103,151,C.ink,body);oval('torso',0,-8,93,143,C.brown,body);
rect('waist',0,-66,91,33,C.ink,body);rect('belt',0,-65,96,9,C.gold,body);
tri('white-vest-left',-26,3,43,106,C.white,body,180);tri('white-vest-right',29,8,43,106,C.white,body,180);
diamond('geo-emblem',1,-16,37,47,C.gold,body);diamond('geo-inlay',1,-16,20,26,C.light,body);
tri('coat-left',-30,-89,65,66,C.white,body,180);tri('coat-right',28,-87,52,62,C.white,body,180);
rect('neck',0,70,27,38,C.skin,body);rect('collar',0,58,48,13,C.gold,body);
const arm=group('offhand',-60,31,a);oval('shoulder',0,0,43,43,C.white,arm);rect('upper-arm',-7,-38,25,57,C.skin,arm,-13);rect('bracer',-13,-73,29,33,C.brown,arm,-13);rect('bracer-gold',-13,-61,30,6,C.gold,arm,-13);oval('hand',-17,-93,23,25,C.skin,arm);
const weapon=group('weapon',60,27,a);oval('shoulder',0,0,42,42,C.white,weapon);rect('upper-arm',11,-31,24,54,C.skin,weapon,22);rect('bracer',24,-57,29,33,C.brown,weapon,22);oval('hand',31,-69,25,24,C.skin,weapon);
const sword=group('sword',32,-69,weapon);for(const t of Object.values(sword.transformByPlatform))t.rotation.z=17;rect('blade-outline',0,-65,15,135,C.ink,sword);rect('blade',0,-65,9,134,'ffc7d7d9',sword);tri('tip',0,-142,15,24,'ffc7d7d9',sword,180);rect('guard',0,2,52,9,C.gold,sword);rect('grip',0,18,10,27,C.brown,sword);oval('pommel',0,34,13,13,C.gold,sword);
const head=group('head',0,111,a);const braid=group('braid',-45,0,head);
for(let i=0;i<5;i++){oval('braid-segment'+i,-i*3,-28-i*19,21,28,i%2?C.gold:C.light,braid);}tri('braid-tail',-17,-136,27,38,C.gold,braid,180);rect('tie',-13,-111,24,8,C.white,braid);
oval('hair-back',-5,8,105,121,C.gold,head);oval('face-outline',7,-7,88,100,C.ink,head);oval('face',7,-7,80,92,C.skin,head);oval('face-light',18,-3,53,77,'fff3d4b1',head);
oval('hair-crown',-5,43,104,61,C.gold,head);tri('hair-left',-34,24,43,80,C.light,head,165);tri('hair-middle',-9,38,49,71,C.light,head,190);tri('hair-right',32,28,42,70,C.gold,head,203);tri('hair-lock',-52,8,27,65,C.gold,head,160);tri('ahoge',-8,91,19,42,C.light,head,27);
const eyes=group('eyes',13,-7,head);for(const x of[-17,20]){oval('eye'+x,x,0,8,14,C.gold,eyes);oval('pupil'+x,x+1,0,4,11,C.ink,eyes);oval('light'+x,x-1,4,3,3,C.white,eyes);}rect('brow-left',-6,5,17,3,C.brown,head,-5);rect('brow-right',33,5,15,3,C.brown,head,5);rect('mouth',20,-32,11,2,C.brown,head);
// Original rooted stone creature. Cultist waving is the motion reference, not copied art.
const m=group('monster',350,0);oval('shadow',0,-222,240,25,'55303838',m);
const roots=group('feet',0,0,m);for(const [i,x]of[-70,-30,20,65].entries()){tri('root'+i,x,-192,64,65,C.rock,roots,180);oval('root-toe'+i,x,-214,71,22,C.ink,roots);}
const mb=group('body',0,-60,m);oval('body-outline',0,0,195,244,C.ink,mb);oval('body-stone',0,0,178,228,C.rock,mb);oval('belly',15,-31,130,145,'ff75876b',mb);tri('chest-facet',-39,32,95,139,'ff61765c',mb,15);diamond('chest-rune',19,-20,30,45,'ffd0d896',mb);
const mh=group('head',0,72,m);oval('head-outline',0,0,151,122,C.ink,mh);oval('head-stone',0,0,138,110,'ff71836a',mh);tri('horn-left',-55,61,35,81,C.rock,mh,-26);tri('horn-right',56,53,31,68,C.rock,mh,28);oval('brow',0,7,140,36,C.rock,mh);
const me=group('eyes',0,0,mh);for(const x of[-32,31]){oval('socket'+x,x,0,28,22,C.ink,me);oval('glow'+x,x,-2,15,10,'ffe8c36e',me);}rect('mouth',0,-33,45,7,C.ink,mh);tri('tooth',-13,-34,10,15,C.shade,mh,180);
for(const [name,x,sign]of[['left',-106,-1],['right',106,1]]){const p=group(name,x,-34,m);oval('upper-outline',0,-7,56,96,C.ink,p);oval('upper',0,-7,47,86,C.rock,p);oval('forearm',sign*9,-66,61,72,'ff64795b',p);oval('knuckle',sign*10,-101,67,37,C.ink,p);for(let i=0;i<3;i++)tri('claw'+i,sign*10-20+i*20,-120,13,30,C.shade,p,180);tri('moss',0,45,48,43,C.teal,p,10*sign);}
// Fixed overlay controls are reused for every hit, never allocated during playback.
for(const [actor,x] of [[a,0],[m,0]]) {
 const fx=group('impact',x,0,actor);
 for(let i=0;i<4;i++)rect('spark'+i,0,0,100-i*13,5,C.light,fx,i*45);
 fx.visible=false;
}
function label(name,text,x,y,w,size=22){return node('textbox',name,x,y,w,60,'',root,{text,fontSize:size,fontColor:0xffeee5cf,bgColor:0,enableOutline:false,horizontalAlignment:'Middle',verticalAlignment:'Middle'});}
label('title','旅行者 × 岩苔怪 · 分层待机实验',0,350,1400,34);
label('subtitle','StS1 Ironclad / Cultist waving 动作机制参照 · 原生图元重绘',0,295,1400,21);
label('traveler-label','旅行者 · 固定脚底 / 呼吸 / 发辫 / 披风',-350,-275,650,21);
label('monster-label','原创岩苔怪 · 扎根 / 上身 / 双臂错相',350,-275,650,21);
for(const [name,title,x]of[['attack','旅行者出招',-460],['counter','怪物出招',-150],['auto','自动演示 开/关',160],['reset','重置为待机',470]]){
 rect(name+'-bg',x,-360,280,52,'ff34473d');label(name+'-label',title,x,-360,270,22);node('cursor',name,x,-360,280,52,'',root,{raycastTarget:true});
}
label('status','点击出招；默认只待机。Simulator 不是官方真机验收。',0,-415,1480,19);
function reverse(n){n.children.reverse();for(const c of n.children)reverse(c)}reverse(root);
save.assets.scripts=[{id:'traveler-idle-script',guid:1073788891,path:'idle.lua',source:fs.readFileSync(path.join(dir,'idle.lua'),'utf8'),controlId:root.id,controlAsset:'server-control-template'}];
save.meta.name='Traveler and Stonebloom Idle Lab';
fs.writeFileSync(path.join(dir,'sample.save.json'),JSON.stringify(save));
const count=(n,k)=>Number(n.kind===k)+n.children.reduce((s,c)=>s+count(c,k),0);
fs.writeFileSync(path.join(dir,'inventory.json'),JSON.stringify({images:count(root,'image'),containers:count(root,'container'),controls:seq+1,travelerImages:count(a,'image'),monsterImages:count(m,'image'),externalTextures:0,scriptGuid:1073788891},null,2));
console.log('Built',seq+1,'controls');
