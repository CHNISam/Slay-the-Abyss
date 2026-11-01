import {preEventProductionSource} from './event-production-source-inverse.mjs';
import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
// Strict test-only historical inverse: every current responsibility must match.
import assert from 'node:assert/strict';
import {readFileSync}from'node:fs';
import {createHash}from'node:crypto';
import {gunzipSync}from'node:zlib';
const digest=value=>createHash('sha256').update(value).digest('hex');
const normalize=value=>value.replaceAll('\r\n','\n');
const bytes=readFileSync('docs/reviews/node-ui-refactor-sources-20261029.json.gz');
assert.equal(digest(bytes),'8a9604c98c5e67462dbffd0a7141126bc325b35a529b17533324304f12aef9fa','reviewed Node UI source archive identity');
export const nodeUiRefactor=JSON.parse(gunzipSync(bytes));
assert.equal(digest(nodeUiRefactor.beforeSource),'e652685874fa6b42a1e8414d040e946bc4496678e79c6f4cf703e617ca77fca1','complete develop Node UI baseline');
export function preNodeUiRefactorSource(path,source,overrides={}){
 if(path!=='src/lua/abyss_node_ui.lua')return source;
 source=preAcceptedPr323Source(path,source);
 if(digest(normalize(source))===nodeUiRefactor.beforeSha256)return normalize(source);
 for(const [file,expected]of Object.entries(nodeUiRefactor.afterSha256)){
  const raw=file===path?source:Object.hasOwn(overrides,file)?overrides[file]:readFileSync(file,'utf8');
  const current=preAcceptedPr323Source(file,preEventProductionSource(file,raw));
  assert.equal(digest(normalize(current)),expected,'unreviewed integrated presentation source drift; unreviewed integrated retirement source drift; unreviewed Node UI refactor source drift: '+file);
 }
 return nodeUiRefactor.beforeSource;
}
