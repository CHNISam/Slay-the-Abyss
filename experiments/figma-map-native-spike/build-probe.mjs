import {readFileSync,writeFileSync} from 'node:fs';import {resolve} from 'node:path';
const repo=process.env.ABYSS_ROOT;
if(!process.env.ABYSS_ROOT)throw Error('Set ABYSS_ROOT to the verified source snapshot');
const save=JSON.parse(readFileSync(resolve(repo,'experiments/art-tech-lab/seed.save.json')));
const root=save.assets.server.root.children[0];const samples=Object.fromEntries(root.children.map(n=>[n.kind,structuredClone(n)]));
const container=structuredClone(root);root.children=[];root.name='FigmaCurveProbe';let seq=100;
const color=h=>parseInt('ff'+h.replace('#',''),16);
function node(parent,kind,name,x,y,w,h,hex,extra={}){
 const n=structuredClone(kind==='container'?container:samples[kind]);n.children=[];n.name=name;n.id='probe'+(++seq);n.guid=1073750000+seq;n.scriptMappingIds=[];
 for(const t of Object.values(n.transformByPlatform)){t.offset={x,y};t.size={x:w,y:h};t.scale={x:1,y:1,z:1};t.anchorMin={x:.5,y:.5};t.anchorMax={x:.5,y:.5}}
 if(kind==='image')Object.assign(n,{imageId:100001,imageColor:color(hex)});
 if(kind==='textbox')Object.assign(n,{text:name,fontSize:20,minimumFontSize:20,fontColor:color(hex),bgColor:0,enableOutline:false,horizontalAlignment:'Middle',verticalAlignment:'Middle'});
 Object.assign(n,extra);parent.children.push(n);return n;
}
node(root,'image','background',0,0,1280,720,'0b0606');
node(root,'image','ambient',0,0,1000,700,'38281b',{imageId:106056});
node(root,'textbox','原生曲线 / 官方图库光晕探针',0,310,800,50,'e9c77b');
for(let k=0;k<4;k++){
 const parent=node(root,'container','probe'+k,-465+k*310,0,280,500,'',{isRootContainer:false});
 const shape=node(parent,'container','shape',0,0,280,500,'',{isRootContainer:false});
 const glow=node(parent,'container','glow',0,0,280,500,'',{isRootContainer:false});
 for(let i=1;i<=32;i++){node(shape,'image','p'+i,0,0,2,2,'f6dfa4');if(i<=16)node(glow,'image','g'+i,0,0,2,2,'6c5433',{imageId:106057});}
 node(parent,'image','start',-85,-130,36,36,'e9c77b',{imageId:102044});
 node(parent,'image','end',85,130,36,36,'ffa95c',{imageId:102002});
 node(parent,'textbox',['已走曲线','未来点线','可选流光','裁剪边界'][k],0,-240,260,45,'bbaa8c');
}
const source='local Curve=(function()\n'+readFileSync('curve.lua','utf8')+'\nend)()\n'+readFileSync('probe.lua','utf8');
writeFileSync('probe.generated.lua',source);save.assets.scripts=[{id:'probeScript',guid:1073760001,path:'probe.generated.lua',source,controlId:root.id,controlAsset:'server-control-template'}];root.scriptMappingIds=[1073760001];save.meta.name='Figma native curve probe';
function reverse(n){n.children.forEach(reverse);n.children.reverse()}reverse(root);
writeFileSync('sample.save.json',JSON.stringify(save));console.log('PROBE_SAVE_READY');
