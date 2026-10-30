// Test-only exact outer projection. Frozen archives remain immutable.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/character-layout-source-inverse.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'8ecd9023a55806780fa70fa358d7e892d91257f64c0e360c8be88f22689c94eb');
export const characterLayoutProof=JSON.parse(bytes);
export function preCharacterLayoutSource(path,source){
 const b=characterLayoutProof.files[path];if(!b||typeof source!=='string')return source;
 const text=source.replaceAll('\r\n','\n');if(hash(text)!==b.afterSha256)return source;
 assert.equal(hash(b.beforeSource),b.beforeSha256);return b.beforeSource;
}
