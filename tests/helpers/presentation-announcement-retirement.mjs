import {preFormalEntrySource} from '../support/formal-entry-source-inverse.mjs';
import assert from 'node:assert/strict';
import {existsSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gunzipSync} from 'node:zlib';

const digest=value=>createHash('sha256').update(value).digest('hex');
const bytes=readFileSync('docs/reviews/m3-announcement-retirement-sources-20261028.json.gz');
assert.equal(digest(bytes),'0d31e4bb052cd578db29062e63708f739ff3e4719f75e50580b7ee119515959a');
export const retirementSources=JSON.parse(gunzipSync(bytes));
assert.equal(retirementSources.base,'b9d071e5dd8a8ebb1c5d71b4f0b5671b30a44527');
assert.equal(retirementSources.head,'d7fa6f219a1461cf2b461f03724fb00da79e621f');

// Test-only historical replay. Deleted controls never return to the live build.
// Complete identities are checked before projection; this is not a wildcard
// that can hide future changes in the old source or current interaction guards.
export function preRetirementSource(path,source=existsSync(path)?readFileSync(path,'utf8'):null){
 let normalized=source===null?null:preFormalEntrySource(path,source);
 if(!Object.hasOwn(retirementSources.beforeSources,path))return normalized;
 if(path==='src/lua/abyss_ui.lua'){
  // Historical replay only. The separate live OnStart fixture owns campaign
  // behavior; this exact inverse does not claim natural or platform coverage.
  assert.equal(normalized===null?null:digest(normalized),
   '4fdb5660a96f00b3d24bfa5388d5eb9c364183996679d0b7aaaf772af1319677',
   'unreviewed integrated retirement source drift: '+path);
  const enabled='{ music = music, campaign = true, experimentalCharacters =';
  assert.equal(normalized.split(enabled).length,2,'one exact formal campaign opt-in');
  normalized=normalized.replace(enabled,'{ music = music, experimentalCharacters =');
 }
 assert.equal(normalized===null?null:digest(normalized),retirementSources.afterSha256[path],
  'unreviewed integrated retirement source drift: '+path);
 const before=retirementSources.beforeSources[path];
 if(path==='data/presentation/ui_theme.json'){
  const theme=JSON.parse(normalized),old=JSON.parse(before);
  assert.equal(Object.hasOwn(theme.layout,'releaseNotes'),false,'announcement theme remains absent');
  assert.deepEqual(theme.layout.nativeMenu.codeVersion,old.layout.releaseNotes.menuVersion,'unchanged version geometry');
  const version=',\n      "codeVersion": [\n        0,\n        -300,\n        1120,\n        40\n      ]';
  assert.equal(normalized.split(version).length,2,'one exact relocated version geometry');
  const withoutVersion=normalized.replace(version,''),end='\n  }\n}\n';
  assert.ok(withoutVersion.endsWith(end),'complete theme closure and order');
  const start=before.indexOf(',\n    "releaseNotes": {');
  assert.ok(start>0,'immutable archive contains the retired theme');
  const block=before.slice(start,before.lastIndexOf('\n  }'));
  const projected=withoutVersion.slice(0,-end.length)+block+end;
  assert.equal(projected,before,'all non-announcement theme bytes and order retained');
  return projected;
 }
 if(path==='tests/lua/presentation_responsibilities_trace.lua'){
  const marker="print('PRESENTATION_NATIVE_TRACE '..trace.count..' '..string.format('%.0f',trace.hash))\n";
  assert.equal(normalized.split(marker).length,2,'one original strict trace completion');
  assert.equal(before.split(marker).length,2,'one frozen strict trace completion');
  assert.equal(normalized.split(marker)[0],before.split(marker)[0],'complete original scenario and native guards retained');
 }
 return before;
}
