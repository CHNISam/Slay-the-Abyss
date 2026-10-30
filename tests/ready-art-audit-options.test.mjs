import test from 'node:test';import assert from 'node:assert/strict';
import * as audit from '../scripts/audit-native-candidate.mjs';
test('audit replays the candidate disabled-art mode instead of rebuilding a different UI',()=>{
 assert.equal(typeof audit.auditUiBuildArgs,'function');
 assert.deepEqual(audit.auditUiBuildArgs({readyCardArt:{enabled:false}}),['scripts/build-ui.mjs','--no-ready-card-art']);
 assert.deepEqual(audit.auditUiBuildArgs({readyCardArt:{enabled:true}}),['scripts/build-ui.mjs']);
 assert.deepEqual(audit.auditUiBuildArgs(undefined),['scripts/build-ui.mjs']);
});
