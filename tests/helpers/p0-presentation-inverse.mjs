import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';
const hash=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('tests/fixtures/p0-accepted-presentation-inverses.json.gz');
assert.equal(hash(bytes),'6f74bc575b24e5c830119e0309b0311017cbeba5ad5cc6d1fdcc44f69a27e164');
export const p0Presentation=JSON.parse(gunzipSync(bytes));
export function preAcceptedPresentation(path,source){
  if(source===null)return source;
  source=source.replaceAll('\r\n','\n');
  const binding=p0Presentation.files[path];
  if(!binding || hash(source)===binding.beforeSha256)return source;
  assert.equal(hash(source),binding.afterSha256,'unreviewed integrated presentation source drift; unreviewed integrated retirement source drift: '+path);
  for(const edit of binding.edits){
    assert.equal(source.split(edit.after).length,2,'one exact reviewed presentation inverse hunk: '+path);
    source=source.replace(edit.after,edit.before);
  }
  assert.equal(hash(source),binding.beforeSha256,'complete original presentation source recovered: '+path);
  return source;
}
export function materializeHistoricalPresentation(directory){
  for(const path of Object.keys(p0Presentation.files))
    writeFileSync(join(directory,path),preAcceptedPresentation(path,readFileSync(path,'utf8')));
}
