// 最外层精确逆投影：仅还原 feat/combat-vfx-upgrade（战斗特效/拖牌手感）对列出文件的改动。
// 所有历史见证保持冻结；部分或未知字节原样交给既有严格守卫拒绝。
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/combat-vfx-upgrade-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'ea6445c08d0c178d2f41c297e672c9184513c04a38d097421584b9db83193265','complete exact combat VFX upgrade layer identity');
export const combatVfxUpgradeProof=JSON.parse(bytes);
assert.equal(combatVfxUpgradeProof.base,'e57df1d1f5f36d952c2360c8fc9add56e59d017c');
export function preCombatVfxUpgradeSource(path,source){
 const binding=combatVfxUpgradeProof.files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 const lines=normalized.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact combat VFX upgrade hunk and position: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const accepted=lines.join('\n');
 assert.equal(hash(accepted),binding.beforeSha256,'complete accepted develop source recovered: '+path);
 return accepted;
}
