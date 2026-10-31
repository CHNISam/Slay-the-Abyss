import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
export const fixture=JSON.parse(readFileSync('tests/fixtures/sts1-merchant-chain.json'));
const ordinaryQueues=JSON.parse(readFileSync('tests/fixtures/sts1-relic-pool-vectors.json')).cases[0].queues;
const membershipQueues=JSON.parse(readFileSync('tests/fixtures/economy-relic-seeds.json')).membership.queues;
export function execute(caseId,prelude=''){
 const sample=fixture.cases.find(c=>c.caseId===caseId);assert.ok(sample);
 const queues=sample.membershipPurchase?membershipQueues:ordinaryQueues;
 const dir=mkdtempSync(join(tmpdir(),'merchant-chain-'));
 try{const path=join(dir,'case.lua');writeFileSync(path,`${prelude}\ndofile('tests/lua/support/merchant_chain.lua')(${toLua(sample)},${toLua(queues)},${toLua(['e8b4b3b1c77c4573','14fc879e54fc55f0'])})`);return runLua(path);}
 finally{rmSync(dir,{recursive:true,force:true});}
}
export function verify(caseId){const r=execute(caseId);assert.equal(r.status,0,r.stdout+r.stderr);assert.ok(r.stdout.includes(`MERCHANT_CHAIN_PASS ${caseId}`));}
