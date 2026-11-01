// Validated compact rectangle data from the existing offline conversion recipe.
import {readFileSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {inside} from '../evidence-files.mjs';
export const convertedCardPath='art/cards/traveler-geo/runtime-candidate/rectangles.json';
const precise=new Set(['armaments','cleave','heavy_blade']);
const hash=b=>createHash('sha256').update(b).digest('hex');
export function validateConvertedCardPack(pack,expectedIds) {
 if(pack?.schemaVersion!==1||JSON.stringify(pack.canvas)!=='[144,64]'||pack.encoding!=='xywh-rgb24-hex14'
   ||JSON.stringify(Object.keys(pack.cards??{}).sort())!==JSON.stringify([...expectedIds].sort()))throw Error('Converted artwork ID inventory mismatch');
 for(const [id,a] of Object.entries(pack.cards)) {
  if(!Number.isInteger(a.rectangleCount)||a.rectangleCount<1||a.rectangleCount>2657
    ||typeof a.rectangles!=='string'||a.rectangles.length!==a.rectangleCount*14||!/^[0-9a-f]+$/i.test(a.rectangles))throw Error('Invalid compact rectangle identity/count: '+id);
  if(!a.sourcePreviewPath?.startsWith(`art/cards/traveler-geo/${id}/preview-`)||!/^art\/cards\/traveler-geo\/[a-z_]+\/preview-[a-z0-9x-]+\.png$/.test(a.sourcePreviewPath)
    ||!/^[a-f0-9]{64}$/.test(a.sourcePreviewSha256??'')||!Number.isInteger(a.std)||a.std<3||a.std>10
    ||!Number.isFinite(a.mae)||a.mae<0||a.mae>255||!Number.isInteger(a.maxError)||a.maxError<0||a.maxError>255)throw Error('Invalid converted source provenance: '+id);
  const coverage=new Uint8Array(144*64);
  for(let i=0;i<a.rectangleCount;i++) {
   const row=a.rectangles.slice(i*14,i*14+14),[x,y,w,h]=[0,2,4,6].map(j=>parseInt(row.slice(j,j+2),16));
   if(!w||!h||x+w>144||y+h>64)throw Error('Converted rectangle outside canvas: '+id);
   for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)if(coverage[yy*144+xx]++)throw Error('Converted rectangle overlap: '+id);
  }
  if(coverage.some(value=>value!==1))throw Error('Converted rectangle missing pixels: '+id);
 }
 return pack;
}
export function loadConvertedCardPack(root=process.cwd()) {
 const ids=JSON.parse(readFileSync(join(root,'data/cards.json'))).cards.filter(c=>!['status','curse'].includes(c.type)).map(c=>c.id).filter(id=>!precise.has(id));
 if(ids.length!==72)throw Error('Expected the 72 unconverted profession cards');
 const pack=validateConvertedCardPack(JSON.parse(readFileSync(join(root,convertedCardPath))),ids);
 for(const [id,row]of Object.entries(pack.cards)) {
  const bytes=readFileSync(inside(root,join(root,row.sourcePreviewPath)));
  if(hash(bytes)!==row.sourcePreviewSha256||bytes.length<24||bytes.toString('hex',0,8)!=='89504e470d0a1a0a'
    ||bytes.readUInt32BE(16)!==144||bytes.readUInt32BE(20)!==64)throw Error('Converted artwork source hash/size mismatch: '+id);
 }
 return pack;
}
export function convertedArtInputs(root=process.cwd()) {
 if(!existsSync(join(root,convertedCardPath)))return [];
 return [convertedCardPath,...Object.values(loadConvertedCardPack(root).cards).map(row=>row.sourcePreviewPath)];
}
