import {preIntegrationSource} from './pr372-integration-source.mjs';
// 最外层精确逆投影：仅还原 feat/combat-relics-hud（顶栏遗物托盘/溢出/入口胶囊）对列出文件的改动。
// 所有历史见证保持冻结；部分或未知字节原样交给既有严格守卫拒绝。
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/combat-relics-hud-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'38acee6d5598250bfe42ed578bcd2ecef30200677cbeabc55b59176521e91282','complete exact combat relics HUD layer identity');
export const combatRelicsHudProof=JSON.parse(bytes);
assert.equal(combatRelicsHudProof.base,'1fd94235a13d3b5b0b6c0011583652e97b44b650');
export function preCombatRelicsHudSource(path,source){
 source=preIntegrationSource(path,source,'hud');
 const binding=combatRelicsHudProof.files[path];
 if(!binding||typeof source!=='string')return source;
 const normalized=normalize(source);
 if(hash(normalized)!==binding.afterSha256)return source;
 const lines=normalized.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact combat relics HUD hunk and position: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const accepted=lines.join('\n');
 assert.equal(hash(accepted),binding.beforeSha256,'complete accepted develop source recovered: '+path);
 return accepted;
}
