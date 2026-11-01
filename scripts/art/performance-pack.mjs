import {readFileSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {inside} from '../evidence-files.mjs';
export const performancePackPath='art/performance/compact-v1.json';
export function loadPerformancePack(root=process.cwd()) {
 const pack=JSON.parse(readFileSync(join(root,performancePackPath),'utf8'));
 const cards=JSON.parse(readFileSync(join(root,'data/cards.json'),'utf8')).cards.filter(c=>!['status','curse'].includes(c.type)).map(c=>c.id);
 const expected=[...cards,'background','avatar96','battle133'].sort();
 if(pack.profile!=='compact-v1'||pack.schemaVersion!==1||JSON.stringify(Object.keys(pack.assets??{}).sort())!==JSON.stringify(expected))throw Error('Compact artwork inventory mismatch');
 for(const [id,a]of Object.entries(pack.assets)) {
  if(!a.source?.startsWith('art/')||!a.source.endsWith('.png')||!Number.isInteger(a.count)||a.count<1||a.count>a.grid[0]*a.grid[1])throw Error('Invalid compact asset '+id);
  const hash=createHash('sha256').update(readFileSync(inside(root,join(root,a.source)))).digest('hex');
  if(hash!==a.sha256)throw Error('Compact artwork source hash mismatch: '+id);
  if(cards.includes(id)) {
   if(JSON.stringify(a.canvas)!=='[144,64]'||a.count>1056||a.rectangles?.length!==a.count*14||!/^[0-9a-f]+$/.test(a.rectangles))throw Error('Invalid compact card '+id);
   const pixels=new Uint8Array(144*64);
   for(let i=0;i<a.count;i++){
    const row=a.rectangles.slice(i*14,i*14+14),[x,y,w,h]=[0,2,4,6].map(j=>parseInt(row.slice(j,j+2),16));
    if(!w||!h||x+w>144||y+h>64)throw Error('Compact card bounds '+id);
    for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)if(pixels[yy*144+xx]++)throw Error('Compact card overlap '+id);
   }
   if(pixels.some(n=>n!==1))throw Error('Compact card coverage '+id);
  }else if(a.rows?.length!==a.count||a.rows.some(r=>r.length!==18||r[0]!==100001||r.some(n=>!Number.isFinite(n))||r[3]<=0||r[4]<=0||r[13]!==0||r.slice(14).some(n=>n<0||n>255)))throw Error('Invalid compact shape '+id);
 }
 return pack;
}
export function performanceInputs(root=process.cwd()) {
 if(!existsSync(join(root,performancePackPath)))return [];
 return [performancePackPath,...Object.values(loadPerformancePack(root).assets).map(a=>a.source)];
}
