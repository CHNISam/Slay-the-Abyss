// Derive observed acquisition/use gaps without promoting implementation to play evidence.
import fs from 'node:fs';import {gunzipSync} from 'node:zlib';
const directory='docs/evidence/m3-normal-campaign-20261031';
const summary=JSON.parse(fs.readFileSync(`${directory}/summary.json`));
const manifest=JSON.parse(fs.readFileSync('data/release/launch-content.json'));
const cards=new Map(manifest.cards.map(c=>[c.id,{id:c.id,acquisitions:[],plays:[]}]));
for(const row of summary.runs){
 const r=JSON.parse(gunzipSync(fs.readFileSync(`${directory}/${row.artifact}`)));
 for(const c of r.initial.deck)cards.get(c.cardId)?.acquisitions.push({seed:r.seed,uid:c.uid,source:'initial_deck',floor:0});
 for(const [index,a]of r.actions.entries())if(a.ok){
  const before=new Set(a.before.deck.map(c=>c.uid));
  for(const c of a.after.deck)if(!before.has(c.uid))cards.get(c.cardId)?.acquisitions.push({seed:r.seed,uid:c.uid,source:a.label,floor:a.after.floor,action:index+1});
  if(a.label==='play'&&a.details?.cardId)cards.get(a.details.cardId)?.plays.push({seed:r.seed,uid:a.details.uid,floor:a.before.floor,action:index+1});
 }
}
const observed=[...cards.values()];
const coverage={kind:'offline-natural-acquisition-and-play-observation',platformVerified:false,
 runs:summary.runs,requiredCards:75,acquired:observed.filter(c=>c.acquisitions.length).length,
 played:observed.filter(c=>c.plays.length).length,
 missingAcquisition:observed.filter(c=>!c.acquisitions.length).map(c=>c.id),
 missingPlay:observed.filter(c=>!c.plays.length).map(c=>c.id),cards:observed};
fs.writeFileSync(`${directory}/card-coverage.json`,JSON.stringify(coverage,null,2)+'\n');
console.log(JSON.stringify({acquired:coverage.acquired,played:coverage.played,required:75}));
