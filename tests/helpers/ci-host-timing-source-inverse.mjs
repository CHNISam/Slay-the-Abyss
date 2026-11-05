// One exact placement-only calibration. Foreign epochs and mutations remain
// visible to the existing historical guards; no live owner is read or cached.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/ci-host-timing-calibration.json.gz',import.meta.url));
assert.equal(hash(bytes),'70cf6cbf502ed85cf7884095cb603a92f910e9b6cb5b311cee2b4b0f1118659f','complete approved Host timing source proof');
export const ciHostTimingProof=deepFreezeSourceProof(JSON.parse(gunzipSync(bytes)));
const proof=ciHostTimingProof;
assert.equal(proof.path,'scripts/ci-test-timings.json');
assert.equal(hash(proof.beforeSource),proof.beforeSha256,'complete pre-calibration timing source');
assert.equal(hash(proof.afterSource),proof.afterSha256,'complete approved calibration timing source');
assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(proof.beforeSource)}\0`).update(proof.beforeSource).digest('hex'),proof.beforeGitBlob,'original timing Git blob');
export function preCiHostTimingSource(path,source){
 if(path!==proof.path||typeof source!=='string')return source;
 if(hash(normalize(source))!==proof.afterSha256)return source;
 return proof.beforeSource;
}
