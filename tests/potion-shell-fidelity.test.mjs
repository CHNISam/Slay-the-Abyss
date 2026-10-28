// Engineering regression for existing OFFLINE discSoft semantic model only.
// This is not native texture/device acceptance or user approval of the approximation.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {nativeTheme as theme} from '../scripts/native-ui-theme.mjs';
import {potionSlotVisual} from '../scripts/potion-slot-visual.mjs';
const rgb=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
function reference(file,label){
 const html=readFileSync(new URL(`../docs/design/ui-canvas/${file}.dc.html`,import.meta.url),'utf8');
 const style=html.match(new RegExp(`<button aria-label="药水：${label}" style="([^"]+)"`))[1];
 const d=+style.match(/width: ([\d.]+)px/)[1],b=+style.match(/border: ([\d.]+)px/)[1];
 const [,x,y,light,dark]=style.match(/radial-gradient\(circle at ([\d.]+)% ([\d.]+)%, (#[0-9A-Fa-f]+), (#[0-9A-Fa-f]+)\)/);
 return{d,b,x:+x/100,y:+y/100,light,dark};
}
const diameter=34.667;
const tree=potionSlotVisual(theme,{border:{name:'border',kind:'image',position:[0,0],size:[diameter,diameter]},plate:{name:'plate',kind:'image'},bottleSize:16,ink:'#FFFFFF'});
function evaluate(shell,x,y){
 let out=[0,0,0];
 for(const item of shell.children.filter(c=>c.name!=='rim')){
  const [cx,cy]=item.position,rad=item.size[0]/2;
  const distance=Math.hypot(x-cx,y-cy);
  const alpha=item.image===theme.image.disc?Number(distance<=rad):Math.max(0,1-distance/rad);
  const colour=rgb(item.colour);out=colour.map((v,i)=>v*alpha+out[i]*(1-alpha));
 }
 return out;
}
for(const[label,name]of [['锻造祝福','filledShell'],['火焰药水','fireShell']])test(`${label}: whole-shell reference error, not a bright-centre proxy`,()=>{
 const ref=reference('Map',label);assert.deepEqual(reference('Main',label),ref,'approved sources must agree');
 const scale=diameter/ref.d,R=diameter/2-ref.b*scale;
 const focal=[(ref.x-.5)*diameter,(.5-ref.y)*diameter];
 const radius=Math.hypot(Math.max(ref.x,1-ref.x)*diameter,Math.max(ref.y,1-ref.y)*diameter);
 const light=rgb(ref.light),dark=rgb(ref.dark),shell=tree.find(c=>c.name===name);
 for(const item of shell.children.filter(c=>c.name!=='rim')){
  assert.ok([theme.image.disc,theme.image.discSoft].includes(item.image),'only existing disc textures');
  assert.ok(Math.hypot(...item.position)+item.size[0]/2<=R+.001,'no assumed circular clipping');
 }
 let error=0,n=0,max=0;const regions={top:[],bottom:[],side:[],middle:[]};
 for(let iy=-50;iy<=50;iy++)for(let ix=-50;ix<=50;ix++){
  const x=ix*R/50,y=iy*R/50;if(x*x+y*y>R*R)continue;
  const a=Math.max(0,1-Math.hypot(x-focal[0],y-focal[1])/radius);
  const source=dark.map((v,i)=>v+a*(light[i]-v)),actual=evaluate(shell,x,y);
  const delta=source.map((v,i)=>Math.abs(v-actual[i]));
  error+=delta.reduce((s,v)=>s+v,0);n+=3;max=Math.max(max,...delta);
  const region=y>R*.6?'top':y<-R*.6?'bottom':Math.abs(x)>R*.6?'side':'middle';regions[region].push(...delta);
 }
 assert.ok(error/n<=2,`whole face RGB MAE ${error/n} exceeds provisional offline regression ceiling 2/255`);
 assert.ok(max<=8,`pointwise RGB error ${max} exceeds provisional offline regression ceiling 8/255`);
 for(const[region,e]of Object.entries(regions))assert.ok(e.reduce((s,v)=>s+v,0)/e.length<=3,`${region} cannot remain at the dark endpoint`);
 console.log(JSON.stringify({shell:name,samples:n/3,mae:error/n,max,model:'OFFLINE_NOT_NATIVE'}));
});
