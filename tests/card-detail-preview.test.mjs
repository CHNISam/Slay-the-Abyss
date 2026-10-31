import test from 'node:test';
import assert from 'node:assert/strict';
import { runLua } from '../scripts/test-lua.mjs';
import {readFileSync} from 'node:fs';
const partitions=JSON.parse(readFileSync('tests/fixtures/card-detail-preview-partitions.json','utf8'));
for (const part of partitions.slices) test(`card details and upgrade previews preserve current instances and the entire run: groups ${part.first}-${part.last}`, () => {
 const result=runLua(part.path);
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,new RegExp(`CARD_DETAIL_PREVIEW_PASS ${part.last-part.first+1}\\b`));
 assert.deepEqual([...result.stdout.matchAll(/CARD_DETAIL_PREVIEW_CASE (\d+)/g)].map(match=>Number(match[1])),
  Array.from({length:part.last-part.first+1},(_,index)=>part.first+index));
});
