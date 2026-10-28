import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';

export const digest=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('docs/reviews/presentation-m3-integration-20261028.json.gz');
assert.equal(digest(bytes),'283c069f16c0e251ad2f8b563aa0ed92c28bd58cde126f0d077a064afc763359');
export const integration=JSON.parse(gunzipSync(bytes));
export function acceptedPresentationSource(path,source=readFileSync(path,'utf8')){
  assert.equal(digest(source.replaceAll('\r\n','\n')),integration.afterSha256[path],
    'unreviewed integrated presentation source drift: '+path);
  assert.equal(typeof integration.beforeSources[path],'string','accepted presentation source exists');
  return integration.beforeSources[path];
}
