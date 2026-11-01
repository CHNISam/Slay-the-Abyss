import {preRound2CanPlaySource} from './round2-can-play-source-inverse.mjs';
// Exact integration-only layer; both prior source archives remain immutable.
import {preRelicCompletionSource} from './relic-completion-inverse.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/event-snapshot-composition.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'1d8bc385f5ed96025babf26c3a1af68ccb38d985332047ba8d865b67e45c6d0b');
export const eventSnapshotComposition=JSON.parse(bytes);
for(const binding of Object.values(eventSnapshotComposition.files))for(const target of ['current','event','snapshot'])assert.equal(hash(binding[target]),binding[target+'Hash']);
export function projectEventSnapshotSource(path,source,target){
 source=preRound2CanPlaySource(path,source);
 source=preRelicCompletionSource(path,source);
 if(typeof source!=='string')return source;
 const binding=eventSnapshotComposition.files[path],normalized=source.replaceAll('\r\n','\n');
 if(!binding||hash(normalized)!==binding.currentHash)return source;
 assert.ok(target==='event'||target==='snapshot');
 return binding[target];
}
