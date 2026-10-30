import assert from 'node:assert/strict';
import {readFileSync,readdirSync,statSync,writeFileSync} from 'node:fs';
const dir='experiments/art-tech-lab/', read=p=>JSON.parse(readFileSync(p));
const select=read(dir+'selection.json'),played=read(dir+'played.json');
assert(select.logs.some(x=>/art-probe-select:/.test(x.text)));
assert(played.logs.some(x=>/art-probe-play:/.test(x.text)));
for(const name of ['sample','selected','played','mobile']){
 const r=JSON.parse(read(dir+name+'.receipt.json')[0].text);assert.deepEqual(r.assetWarnings,[]);
 assert(statSync(dir+name+'.png').size>10000);
}
const pack=read(dir+'export-receipt.json');assert.equal(pack.files.length,2);
for(const name of readdirSync(dir+'import')){
 const bytes=readFileSync(dir+'import/'+name);assert.equal(bytes.readUInt32BE(0),bytes.length-4);assert.equal(bytes.readUInt32BE(bytes.length-4),0x679);
}
const tree=read(dir+'sample.save.json').assets.server.root.children[0];
const count=n=>1+n.children.reduce((s,c)=>s+count(c),0);
const cards=tree.children.filter(n=>/^card\d$/.test(n.name));
const old=read('art/cards/traveler-geo/runtime-candidate/rectangles.json').cards;
const compact=read('art/performance/compact-v1.json').assets;
const report={base:'a5cb4bb6',simulator:'3dff619528b1ad3689e2f96b6bcbb0c0c0e735f2',
 controls:count(tree),controlsPerCard:cards.map(count),
 oldCardRectangles:Object.fromEntries(['strike','defend','bash'].map(id=>[id,old[id].rectangleCount])),
 compactCardRectangles:Object.fromEntries(['strike','defend','bash'].map(id=>[id,compact[id].count])),
 oldBackground:13201,budgetBackground:4500,compactBackground:compact.background.count,
 newArtworkImagesPerCard:1,comparison:'Different artwork. Counts are NOT an equal-quality optimization ratio.',
 verified:['simulator Lua startup','click select','second click hides card','PC and mobile canvas PNG without missing assets','GIA envelope validation'],
 unverified:['official editor import','official ready','actual phone','FPS','cold and warm official loading','same-quality original character portrait','independent review']};
writeFileSync(dir+'verification.json',JSON.stringify(report,null,2));console.log(report);
