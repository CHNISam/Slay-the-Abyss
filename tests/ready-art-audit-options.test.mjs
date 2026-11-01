import {artFeatureReceipt} from '../scripts/art-features.mjs';
import {portraitInventory,portraitRuntimeInputs} from '../scripts/official-portraits.mjs';
import test from 'node:test';import assert from 'node:assert/strict';
import * as audit from '../scripts/audit-native-candidate.mjs';
test('audit replays the candidate disabled-art mode instead of rebuilding a different UI',()=>{
 assert.equal(typeof audit.auditUiBuildArgs,'function');
 const off=['scripts/build-ui.mjs','--art-cards=false','--art-menu-background=false','--art-selection-avatar=false','--art-battle-portrait=false','--art-monsters=false'];
 assert.deepEqual(audit.auditUiBuildArgs({artFeatures:artFeatureReceipt({})}),off);
 const flags={cards:true,selectionAvatar:false,battlePortrait:false,menuBackground:false};
 const officialPortraits={...portraitInventory(flags),inputs:portraitRuntimeInputs(flags).map(path=>({path,sha256:'d'.repeat(64),bytes:1}))};
 assert.deepEqual(audit.auditUiBuildArgs({artFeatures:artFeatureReceipt(flags),readyCardArt:{enabled:true},officialPortraits}),[off[0],'--art-cards=true',...off.slice(2)]);
 assert.deepEqual(audit.auditUiBuildArgs(undefined),off);
});
