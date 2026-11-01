// Read-only identity coverage, not a proof that every defined effect executes.
// Run from the repository root: node /tmp/mobile_relic_coverage.mjs <verified-HEAD-SHA>
import fs from 'node:fs';
const definitionsPath='data/relics.json';
const queuesPath='data/catalogs/sts1-relic-queues.json';
const definitions=JSON.parse(fs.readFileSync(definitionsPath,'utf8')).relics;
const catalog=JSON.parse(fs.readFileSync(queuesPath,'utf8'));
// Legacy source identities used by abyss_relic_rewards.lua/abyss_treasure.lua.
const legacy={burning_blood:'Burning Blood',anchor:'Anchor',vajra:'Vajra',bag_of_preparation:'Bag of Preparation',lantern:'Lantern',oddly_smooth_stone:'Oddly Smooth Stone',bronze_scales:'Bronze Scales',membership_card:'Membership Card',courier:'The Courier',smiling_mask:'Smiling Mask',black_blood:'Black Blood',slavers_collar:'SlaversCollar',sozu:'Sozu',black_star:'Black Star',circlet:'Circlet'};
const ids=new Set(definitions.map(r=>r.sourceId??legacy[r.id]??r.id));
const queues=Object.fromEntries(Object.entries(catalog.queues).map(([tier,sourceIds])=>{
 const defined=sourceIds.filter(id=>ids.has(id));const missing=sourceIds.filter(id=>!ids.has(id));
 return [tier,{total:sourceIds.length,definedCount:defined.length,missingCount:missing.length,defined,missing}];
}));
console.log(JSON.stringify({baseline:process.argv[2]??null,scope:'Static definition/source identity coverage for Ironclad queues; no draw probability or gameplay-effect claim',files:[definitionsPath,queuesPath],definitionCount:definitions.length,whiteBeastDefined:ids.has('White Beast Statue'),queues},null,2));
