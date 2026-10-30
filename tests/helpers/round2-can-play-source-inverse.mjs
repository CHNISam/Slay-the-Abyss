import {preRound3CatalogSource} from './round3-catalog-source-inverse.mjs';
// Exact outer projection for the reviewed canPlay refactor. Historical
// snapshot-owner witnesses and their complete-source hashes stay immutable.
import assert from 'node:assert/strict';
import {preRelicRound2CompositionSource} from './relic-round2-composition.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/round2-can-play-source-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'05f0361bfbd23927261073033a88785289cc236f24a9baa3d688707461c4d11c');
export const round2CanPlayProof=JSON.parse(bytes);
assert.equal(round2CanPlayProof.schemaVersion,1);
assert.equal(round2CanPlayProof.base,'a7b03825');
assert.equal(round2CanPlayProof.path,'src/lua/abyss_combat.lua');
export function preRound2CanPlaySource(path,source){
 if(path===round2CanPlayProof.path)source=preRelicRound2CompositionSource(path,source,'round2');
 source=preRound3CatalogSource(path,source);
 if(path!==round2CanPlayProof.path||typeof source!=='string')return source;
 const normalized=normalize(source);
 // Unknown, partial and future edits must remain visible to inner guards.
 if(hash(normalized)!==round2CanPlayProof.afterSha256)return source;
 assert.equal(normalized.split(round2CanPlayProof.after).length,2,'exact complete canPlay delta');
 const original=normalized.replace(round2CanPlayProof.after,round2CanPlayProof.before);
 assert.equal(hash(original),round2CanPlayProof.beforeSha256,'complete pre-canPlay source identity');
 return original;
}
