import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {preRetirementSource} from './presentation-announcement-retirement.mjs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';

export const digest=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('docs/reviews/presentation-m3-integration-20261028.json.gz');
assert.equal(digest(bytes),'283c069f16c0e251ad2f8b563aa0ed92c28bd58cde126f0d077a064afc763359');
export const integration=JSON.parse(gunzipSync(bytes));
export function acceptedPresentationSource(path,source=existsSync(path)?readFileSync(path,'utf8'):null){
  let projected=preRetirementSource(path,source);
  if(path==='src/lua/abyss_node_ui.lua'){
    assert.equal(digest(projected),'12e780e07556b588444d5eebae3ffc003bdbe44d39cea6fb907649805990ba06',
      'unreviewed integrated presentation source drift: '+path);
    const added="mushrooms={name='蘑菇',body='发光的蘑菇覆盖了通道。',leave='你离开了蘑菇群。'},";
    assert.equal(projected.split(added).length,2,'one exact reviewed Mushrooms label');
    projected=projected.replace(added,'');
  }
  assert.equal(digest(projected.replaceAll('\r\n','\n')),integration.afterSha256[path],
    'unreviewed integrated presentation source drift: '+path);
  assert.equal(typeof integration.beforeSources[path],'string','accepted presentation source exists');
  return integration.beforeSources[path];
}
