// One exact outer layer only: card body wrap estimate (CJK kinsoku + Latin
// word runs) and redundant upgraded cost prefix removal. Unknown or partial
// sources still reach the strict inner guards unchanged.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/card-desc-overflow-inverse.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'742bb674a53e886684070e20af13d3037264384295c29573db018c388eb847d1','complete card-desc-overflow layer identity');
export const cardDescOverflowLayer=JSON.parse(bytes);
export function preCardDescOverflowSource(path,source){
  const binding=cardDescOverflowLayer.files[path];
  if(!binding||typeof source!=='string')return source;
  source=source.replaceAll('\r\n','\n');
  if(hash(source)!==binding.afterSha256)return source;
  assert.equal(hash(binding.beforeSource),binding.beforeSha256,'complete pre card-desc-overflow source: '+path);
  return binding.beforeSource;
}
