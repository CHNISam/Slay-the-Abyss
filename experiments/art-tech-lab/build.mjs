import {readFileSync,writeFileSync} from 'node:fs';
const dir='experiments/art-tech-lab/';
const save=JSON.parse(readFileSync(dir+'seed.save.json'));
const root=save.assets.server.root.children[0], samples=Object.fromEntries(root.children.map(n=>[n.kind,n]));
root.transformByPlatform.TOUCHSCREEN.scale={x:.8,y:.8,z:1};
root.transformByPlatform.CONTROLLER_MOBILE.scale={x:.8,y:.8,z:1};
let seq=100;root.children=[];root.name='ArtLab'; root.scriptMappingIds=[];
const rgba=h=>{h=h.replace('#','');return 0xff000000+parseInt(h,16)};
function node(kind,name,x,y,w,h,color,extra={},parent=root){
 const n=structuredClone(kind==='container'?root:samples[kind]);n.children=[];n.id='lab'+(++seq);n.guid=1073750000+seq;n.name=name;n.scriptMappingIds=[];
 for(const t of Object.values(n.transformByPlatform)){t.offset={x,y};t.size={x:w,y:h};t.anchorMin={x:.5,y:.5};t.anchorMax={x:.5,y:.5};t.scale={x:1,y:1,z:1}}
 if(kind==='image'){n.imageId=100001;n.imageColor=rgba(color)}
 if(kind==='textbox'){Object.assign(n,{text:name,fontSize:20,fontColor:rgba(color),bgColor:0,enableOutline:false,horizontalAlignment:'Middle',verticalAlignment:'Middle'})}
 Object.assign(n,extra);parent.children.push(n);return n;
}
const img=(name,x,y,w,h,c,id=100001,parent=root)=>node('image',name,x,y,w,h,c,{imageId:id},parent);
const text=(name,x,y,w,h,size,c,parent=root)=>node('textbox',name,x,y,w,h,c,{fontSize:size,minimumFontSize:size},parent);
img('sky',0,0,1600,900,'111e30');
img('moon-halo',330,180,480,480,'233b50',100002);
img('moon',330,180,210,210,'dec68c',100002);
img('moon-shadow',302,204,204,204,'233b50',100002);
// Camera-oriented scenery, purpose-designed silhouettes rather than raster reduction.
for(let i=0;i<11;i++){const x=-780+i*160;const h=230+(i*83%210);img('distant-mountain'+i,x,-40,310,h,'243a49',100003)}
for(let i=0;i<8;i++){const x=-850+i*240;const h=170+(i*67%200);img('near-mountain'+i,x,-130,390,h,'172d3b',100003)}
img('ground',0,-345,1600,270,'0d1a27');
for(let i=0;i<4;i++){img('pillar'+i,-670+i*445,-115,40,360,'32424a');img('capital'+i,-670+i*445,60,64,15,'8b8061');img('pillar-edge'+i,-685+i*445,-115,3,335,'8d8060')}
img('horizon',0,-210,1600,2,'8b7956');
text('杀 戮 原 塔 Ⅱ',-510,365,400,60,30,'e9d4a4');
text('璃月 · 月下试炼',490,365,380,45,18,'a9b7c0');
text('第 1 回合',0,320,240,45,18,'c4b28b');
img('title-rule',0,290,240,2,'826e45');
// Official creature portrait. Each is one static-reference image, not a mesh.
img('enemy-disc',470,30,225,225,'1d3442',100002);
img('enemy',470,45,190,190,'ffffff',112003);
text('水史莱姆',470,-91,260,40,20,'c7d8e0');
img('hp-back',470,-122,210,6,'344a56');img('hp',470,-122,210,6,'76b7c2');
text('18 / 18',470,-148,210,40,16,'a5bcc9');
text('攻击  ·  6',470,198,200,40,20,'e1b076');
img('sigil',-470,35,155,155,'c8a36a',102050);
text('旅行者 · 岩',-470,-91,260,40,22,'e9d4a4');
text('80 / 80',-470,-135,240,40,18,'b4c4ce');
const cards=JSON.parse(readFileSync('data/cards.json')).cards;
for(let i=0;i<3;i++){
 const data=cards.find(c=>c.id===['strike','defend','bash'][i]);
 const card=node('container','card'+(i+1),-230+i*230,-263,206,290,'',{isRootContainer:false});
 img('edge',0,0,206,290,'b29559',100001,card);img('paper',0,0,200,284,'192638',100001,card);
 img('ornament',0,0,196,280,'dabd82',107003,card);
 img('artwell',0,42,176,152,'243a4b',100001,card);
 img('artdisc',0,43,124,124,'334958',100002,card);
 img('art',0,46,108,108,'ebd9b0',[102050,102014,111075][i],card);
 img('spark',59,89,22,22,'f8db93',104001,card);
 img('line',0,-39,168,1,'9e865c',100001,card);
 text(data.name,0,121,160,40,22,'f0dfb8',card);
 text(data.type==='attack'?'攻 击':'技 能',0,-57,160,40,13,'c7a971',card);
 text(data.text,0,-99,164,54,16,'d9dfe1',card);
 img('cost-disc',-84,128,43,43,'b58d4a',100002,card);img('cost-inset',-84,128,37,37,'17283a',100002,card);
 text(String(data.cost),-84,128,40,40,22,'ffe1a1',card);
 node('cursor','hit',0,0,206,290,'',{},card);
}
text('能量  3 / 3',-535,-345,260,45,22,'e6c684');
text('点选卡牌放大 · 再次点选出牌',0,-430,700,40,16,'97aab8');
text('结束回合',535,-345,220,50,22,'dfc594');
save.assets.server.selectedId=root.id;save.meta.name='杀戮原塔2 · 原生低成本美术实验';
save.assets.scripts=[{id:'s1',guid:1073760001,path:dir+'interaction.lua',source:readFileSync(dir+'interaction.lua','utf8'),controlId:root.id,controlAsset:'server-control-template'}];
root.scriptMappingIds=[1073760001];
// Authoring tree stores front-to-back; build declarations above are back-to-front.
function reverseLayers(n){for(const c of n.children)reverseLayers(c);n.children.reverse()};reverseLayers(root);
writeFileSync(dir+'sample.save.json',JSON.stringify(save,null,2));
let count=0;function walk(n){count++;for(const c of n.children)walk(c)}walk(root);
writeFileSync(dir+'inventory.json',JSON.stringify({controls:count,background:'intentional layered geometry; not original landscape reconstruction',cardIds:['strike','defend','bash'],officialVerified:false},null,2));
console.log({controls:count});
