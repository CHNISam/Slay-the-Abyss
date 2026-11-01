import {preIntegrationSource} from './pr372-integration-source.mjs';
// 搓牌灵敏度切片的精确最外层逆投影。历史见证与其完整源哈希保持不变；
// 未知、部分或后续改动原样下传，仍由内层严格守卫拦截。
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
const bytes=normalize(readFileSync(new URL('./hand-fan-source-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'d1fed0343521b54bc6c9c5cc342f1b3d35d4cc05a23caf1067fe01a56c87b71d','complete hand-fan outer source identity');
export const handFanSourceLayer=JSON.parse(bytes);
assert.equal(handFanSourceLayer.schemaVersion,1);
assert.equal(handFanSourceLayer.baseCommit,'1bfca6261044b92f8065bb83668c358b0a2627da');
assert.deepEqual(Object.keys(handFanSourceLayer.files),['src/lua/abyss_battle_card_gestures.lua','src/lua/abyss_battle_render_state.lua']);
export function preHandFanSource(path,source){
 source=preIntegrationSource(path,source,'fan');
  const binding=handFanSourceLayer.files[path];
  if(!binding||typeof source!=='string')return source;
  const normalized=normalize(source);
  if(hash(normalized)!==binding.afterSha256)return source;
  const lines=normalized.split('\n');
  for(const hunk of [...binding.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact hand-fan inverse hunk and position: '+path);
    lines.splice(hunk.at,hunk.after.length,...hunk.before);
  }
  const previous=lines.join('\n');
  assert.equal(hash(previous),binding.beforeSha256,'complete pre-hand-fan source recovered: '+path);
  return previous;
}
