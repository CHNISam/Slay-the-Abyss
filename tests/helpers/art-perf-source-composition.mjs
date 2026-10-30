// Integration-only outer projection. Both source branches and frozen witnesses
// keep their exact identities; unknown or partial edits remain unprojected.
import assert from 'node:assert/strict';
import {preRound3CatalogSource} from './round3-catalog-source-inverse.mjs';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/art-perf-source-composition.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'2aba05dd108700a04347a2f357c6663409f326d5e9e9a4cf050601912bd2ca4a','complete art/performance composition identity');
export const artPerfSourceComposition=JSON.parse(bytes);
assert.equal(artPerfSourceComposition.schemaVersion,1);
export function projectArtPerfSource(path,source,target){
  assert.ok(target==='art'||target==='perf','known art/performance target');
  source=preRound3CatalogSource(path,source);
  const binding=artPerfSourceComposition.files[path];
  if(!binding||typeof source!=='string')return source;
  const normalized=normalize(source);
  if(hash(normalized)!==binding.currentSha256)return source;
  const destination=binding.targets[target];
  if(destination.sha256===null)return null;
  const lines=normalized.split('\n');
  for(const hunk of [...destination.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.current.length),hunk.current,'exact art/performance composition hunk: '+path);
    lines.splice(hunk.at,hunk.current.length,...hunk.target);
  }
  const previous=lines.join('\n');
  assert.equal(hash(previous),destination.sha256,'complete original '+target+' source: '+path);
  return previous;
}
