import test from 'node:test';
import assert from 'node:assert/strict';

test('delivery accepts exact merge parents and rejects stale reviews, attempts and missing jobs',async()=>{
  const {verifyDelivery}=await import('../scripts/verify-delivery.mjs');
  const evidence={head:'a'.repeat(40),base:'b'.repeat(40),tested:'c'.repeat(40),runId:7,attempt:2,
    event:'pull_request',prNumber:8,parents:['b'.repeat(40),'a'.repeat(40)],
    checkout:{head:'a'.repeat(40),base:'b'.repeat(40),tested:'c'.repeat(40),runId:7,attempt:2,event:'pull_request',prNumber:8},
    jobs:['check','presentation','engineering-posix'].map(name=>({name,status:'completed',conclusion:'success',run_attempt:2})),
    review:{reviewedHeadSha:'a'.repeat(40),reviewedBaseSha:'b'.repeat(40),reviewId:'external-session-123',conclusion:'pass',unresolved:[]}};
  assert.deepEqual(verifyDelivery(evidence),[]);
  for(const mutate of [e=>e.head='d'.repeat(40),e=>e.base='d'.repeat(40),e=>e.jobs.pop(),e=>e.jobs[0].conclusion='skipped',e=>e.attempt++,e=>e.parents.reverse(),e=>e.review.unresolved=['open bug'],e=>e.checkout.tested=e.head]) {
    const bad=structuredClone(evidence);mutate(bad);assert(verifyDelivery(bad).length>0);
  }
});
