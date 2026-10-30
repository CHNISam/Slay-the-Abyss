import {preCharacterLayoutSource} from './character-layout-source-inverse.mjs';
// Exact M4/delivery branch composition; old archives remain immutable.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update(`blob ${Buffer.byteLength(s)}\0`).update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/deck-delivery-source-composition.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'fad6258a3cf9b8d0c1062e960ae518ba6dc338bc591a6f2192f770aa0bc8d79b');
export const deckDeliveryProof=deepFreezeSourceProof(JSON.parse(bytes));
const proof=deckDeliveryProof;
assert.equal(proof.schemaVersion,1);assert.deepEqual(Object.keys(proof.targets),['delivery','deck']);
assert.equal(proof.targets.delivery.beforeCommit,'9c2067547cb378fb33827f63d54cf6394ef32f12');
assert.equal(proof.targets.delivery.afterCommit,'8504ac73f5cd6bff760e5abc234eacfec7c4ee7e');
assert.equal(proof.targets.deck.beforeCommit,'24fd070167d433fa6cbbb0c54d8844795b0c5608');
export const deckDeliveryPaths=Object.freeze(Object.keys(proof.targets.delivery.files));
assert.equal(deckDeliveryPaths.length,7);
assert.deepEqual(deckDeliveryPaths,[...deckDeliveryPaths].sort());
for(const target of Object.values(proof.targets))for(const [path,b]of Object.entries(target.files)){
 assert.ok(deckDeliveryPaths.includes(path));assert.match(b.beforeSha256,/^[a-f0-9]{64}$/);assert.match(b.afterSha256,/^[a-f0-9]{64}$/);
 assert.equal(b.afterSha256,proof.targets.delivery.files[path].afterSha256,'one real integrated source per path');
 let end=0,beforeEnd=0;for(const h of b.hunks){assert.ok(Number.isSafeInteger(h.at)&&h.at>=end&&Number.isSafeInteger(h.beforeAt)&&h.beforeAt>=beforeEnd);for(const line of [...h.before,...h.after])assert.ok(typeof line==='string'&&!/[\r\n]/.test(line));end=h.at+h.after.length;beforeEnd=h.beforeAt+h.before.length;}
}
export function preDeckDeliverySource(path,source,target='delivery',{readSource=p=>readFileSync(p,'utf8')}={}){
 source=preCharacterLayoutSource(path,source);
 assert.ok(proof.targets[target],'registered deck delivery target');
 const b=proof.targets[target].files[path];if(!b||typeof source!=='string')return source;
 const text=normalize(source);if(hash(text)!==b.afterSha256)return source;
 // Fresh linked reads are outside every existing pure-string cache.
 for(const linked of deckDeliveryPaths){let live;try{live=readSource(linked);}catch{assert.fail('deck delivery linked source missing: '+linked);}assert.equal(typeof live,'string','deck delivery linked source must exist: '+linked);assert.equal(hash(normalize(preCharacterLayoutSource(linked,live))),proof.targets.delivery.files[linked].afterSha256,'deck delivery linked source identity: '+linked);}
 assert.equal(blob(text),b.afterGitBlob);
 const lines=text.split('\n');assert.equal(lines.length,b.afterLines);
 for(const h of [...b.hunks].reverse()){assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after,'exact deck delivery hunk: '+path);lines.splice(h.at,h.after.length,...h.before);}
 const old=lines.join('\n');assert.equal(lines.length,b.beforeLines);assert.equal(hash(old),b.beforeSha256);assert.equal(blob(old),b.beforeGitBlob);
 const forward=[...lines];for(const h of [...b.hunks].reverse()){assert.deepEqual(forward.slice(h.beforeAt,h.beforeAt+h.before.length),h.before);forward.splice(h.beforeAt,h.before.length,...h.after);}
 assert.equal(forward.join('\n'),text,'exact deck delivery forward identity');return old;
}
