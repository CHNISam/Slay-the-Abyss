// Exact test-only outer epoch. No live reads, production fallback or cache.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/ci-complete-calibration.json.gz',import.meta.url));
assert.equal(hash(bytes),'c0b66bf5ffd13baaea0f9a035dd43636f7419a0b607cc4eab3f0c1f73155d5ab','complete approved TASK-75.6 source proof');
export const ciCompleteCalibrationProof=deepFreezeSourceProof(JSON.parse(gunzipSync(bytes)));
assert.deepEqual(Object.keys(ciCompleteCalibrationProof.files),['scripts/ci-test-timings.json','scripts/ci-quality-shape.mjs']);
for(const binding of Object.values(ciCompleteCalibrationProof.files)){
 assert.equal(hash(binding.beforeSource),binding.beforeSha256);assert.equal(hash(binding.afterSource),binding.afterSha256);
 assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(binding.beforeSource)}\0`).update(binding.beforeSource).digest('hex'),binding.beforeGitBlob);
}
const currentPlacementSha256=Object.freeze({
 'scripts/ci-test-timings.json':'1832a5f395318af201322666f31f601ffb183c0870fcc6fa62a5d8e48af0922d',
 'scripts/ci-quality-shape.mjs':'0d6c82c2a7e7db82e276eb563978d5253d9a225039329e171ed3f907f98609d1',
});
// This placement-only bridge returns the existing complete approved source.
// It adds no live owner, fixture dependency or permission-bearing cache.
export function preCurrentCiPlacementSource(path,source){
 if(!Object.hasOwn(currentPlacementSha256,path)||typeof source!=='string'||hash(source.replaceAll('\r\n','\n'))!==currentPlacementSha256[path])return source;
 return ciCompleteCalibrationProof.files[path].afterSource;
}
export function preCiCompleteCalibrationSource(path,source){
 source=preCurrentCiPlacementSource(path,source);
 const binding=ciCompleteCalibrationProof.files[path];
 if(!binding||typeof source!=='string'||hash(source.replaceAll('\r\n','\n'))!==binding.afterSha256)return source;
 return binding.beforeSource;
}
