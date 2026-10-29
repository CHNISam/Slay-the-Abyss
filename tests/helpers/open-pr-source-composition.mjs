import {preBattleLifeSource} from './battle-life-source-inverse.mjs';
// Complete current composition and prior reviewed branch sources; test-only.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/open-pr-source-composition.json.gz',import.meta.url));
assert.equal(hash(bytes),'f8ab3e3556e7f5b4f2abbfb91ceb2e47c48940c259b1f21ed6e53f0513412034');
export const openPrSourceComposition=JSON.parse(gunzipSync(bytes));
for(const binding of Object.values(openPrSourceComposition.files)){
 assert.equal(hash(binding.current),binding.currentHash);
 for(const target of Object.values(binding.targets))assert.equal(hash(target.source),target.hash);
}
export function projectOpenPrSource(path,source,target){
 source=preBattleLifeSource(path,source);
 if(typeof source!=='string')return source;
 const binding=openPrSourceComposition.files[path],normalized=source.replaceAll('\r\n','\n');
 if(!binding||hash(normalized)!==binding.currentHash||!binding.targets[target])return source;
 return binding.targets[target].source;
}
