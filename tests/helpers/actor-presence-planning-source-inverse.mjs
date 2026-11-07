// Exact planning-only epoch. No live reads, cache or historical measurement edits.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/actor-presence-planning-before.json.gz',import.meta.url));
assert.equal(hash(bytes),'e581fdaa5c12207b820b516decfbf07a6df2292f4c39c5d4e5bf7e865f0739c0');
export const presencePlanningBefore=gunzipSync(bytes).toString('utf8');
assert.equal(hash(presencePlanningBefore),'a5841ddaa53d8bc810f9c16ae342ed2de8cb5479bbcb073562d2c6c921ed1b24');
export const presencePlanningSha256='5d942af0c708da1d260c69cac85c753a7a163f17920c850739810c97e4b6bc74';
export function prePresencePlanningSource(path,source){
 if(path!=='scripts/ci-test-timings.json'||typeof source!=='string'||hash(source.replaceAll('\r\n','\n'))!==presencePlanningSha256)return source;
 return presencePlanningBefore;
}
