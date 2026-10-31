// One-off provenance extractor: breakthrough pack (feat/art-breakthrough-experiment 72f13f2,
// .artifacts/art-breakthrough/pack/sta_art_scene.lua) -> select-lowpoly.json.
// Keeps hero triangles and card frame+illustration rows; drops baked placeholder text rows ("T").
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const [src,out='select-lowpoly.json']=process.argv.slice(2);
const lua=readFileSync(src,'utf8');
const group=name=>{const m=new RegExp(`\\n  ${name} = \\{\\n([\\s\\S]*?)\\n  \\}`).exec(lua);if(!m)throw Error('missing '+name);
 return m[1].split('\n').map(l=>l.trim().replace(/,$/,'')).filter(l=>l.startsWith('{')&&!l.startsWith('{"T"'))
  .map(l=>JSON.parse('['+l.slice(1,-1)+']'));};
const round=v=>Math.round(v*100)/100;
const hero=group('hero');
const xs=hero.flatMap(r=>[r[1]-r[3]/2,r[1]+r[3]/2]),ys=hero.flatMap(r=>[r[2]-r[4]/2,r[2]+r[4]/2]);
const cx=(Math.min(...xs)+Math.max(...xs))/2,cy=(Math.min(...ys)+Math.max(...ys))/2;
const heroW=Math.ceil(Math.max(...xs)-Math.min(...xs)),heroH=Math.ceil(Math.max(...ys)-Math.min(...ys));
// Fan exactly like the GIF rest pose: offset*128 px, base scale .62, no tilt (tilt would need
// per-card containers; uniform scale is exact for squashed triangles).
const S=.62,fan=[];
for(let i=1;i<=5;i++){const off=i-3,dx=off*128,dy=-Math.abs(off)*10;
 for(const r of group('card'+i))fan.push([r[0],round(r[1]*S+dx),round(r[2]*S+dy),round(r[3]*S),round(r[4]*S),r[5],r[6],r[7],r[8],r[9],r[10],r[11]]);}
const data={source:'feat/art-breakthrough-experiment@72f13f2 .artifacts/art-breakthrough/pack/sta_art_scene.lua',
 sourceSha256:createHash('sha256').update(lua).digest('hex'),rowFormat:'[imageId,x,y,w,h,rotX,rotY,rotZ,r,g,b,a]',
 hero:{width:heroW,height:heroH,rows:hero.map(r=>[r[0],round(r[1]-cx),round(r[2]-cy),...r.slice(3)])},
 cardFan:{width:Math.ceil(4*128+226*S),height:Math.ceil(310*S+20),rows:fan}};
writeFileSync(out,JSON.stringify(data)+'\n');
console.log('hero',data.hero.rows.length,heroW,heroH,'cardFan',fan.length);
