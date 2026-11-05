// Historical source projection only; production delivery never imports this.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/ci-windows-shape-expansion.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'71c137c785a700850f09581a234caccdf375112ac15b0cb66dd939802d06bb50','complete approved Windows shape proof');
export const ciWindowsShapeProof=deepFreezeSourceProof(JSON.parse(bytes));
const proof=ciWindowsShapeProof;
assert.equal(hash(proof.beforeSource),proof.beforeSha256,'complete original thirteen-shard source');
assert.equal(hash(proof.afterSource),proof.afterSha256,'complete approved fourteen-shard source');
assert.equal(createHash('sha1').update(`blob ${Buffer.byteLength(proof.beforeSource)}\0`).update(proof.beforeSource).digest('hex'),proof.beforeGitBlob,'original shape Git blob');
export function preCiWindowsShapeSource(path,source){
 if(path!==proof.path||typeof source!=='string'||hash(source.replaceAll('\r\n','\n'))!==proof.afterSha256)return source;
 return proof.beforeSource;
}
