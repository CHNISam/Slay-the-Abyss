// Pure, complete-source identity bridge. No live owner read or permission cache.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
export const cardUpgradeCiPlanningProof=Object.freeze({
  "path": "scripts/ci-test-timings.json",
  "beforeSha256": "a5841ddaa53d8bc810f9c16ae342ed2de8cb5479bbcb073562d2c6c921ed1b24",
  "afterSha256": "8178187f25c04399ea9f494116efedb522eda1528ddbe815e36f5e0ce9cf962c",
  "floorKey": "tests/card-upgrade-ownership.test.mjs",
  "floorMs": 28384
});
export function preCardUpgradeCiPlanningSource(path,source){
 const proof=cardUpgradeCiPlanningProof;
 if(path!==proof.path||typeof source!=='string')return source;
 const normalized=source.replaceAll('\r\n','\n');
 if(hash(normalized)!==proof.afterSha256)return source;
 const before=JSON.parse(normalized);
 delete before.jsPlanning.localLowerBounds[proof.floorKey];
 const restored=JSON.stringify(before,null,2)+'\n';
 assert.equal(hash(restored),proof.beforeSha256,'complete prior timings identity');
 return restored;
}

// Current-tree validation is deliberately separate from historical projection:
// an old exact source stays valid history, but is not this current floor epoch.
export function validateCardUpgradeCiPlanningSource(source){
 assert.equal(typeof source,'string','current CardUpgrade timing source must be text');
 assert.equal(hash(source.replaceAll('\r\n','\n')),cardUpgradeCiPlanningProof.afterSha256,'current CardUpgrade timing epoch requires the exact complete floor and unchanged prior values');
 return preCardUpgradeCiPlanningSource(cardUpgradeCiPlanningProof.path,source);
}
