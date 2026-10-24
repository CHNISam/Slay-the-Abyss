import { readFileSync } from 'node:fs';
import { toLua } from './build-lua-data.mjs';

export const sfxCandidateIds = Object.freeze([
  40305, 40309, 40313, 40317, 40221, 40224, 51044, 51049, 20092, 20109, 20117, 20139,
]);

export function sfxAuditionCandidates(catalog) {
  return sfxCandidateIds.map((id, i) => {
    const row = catalog.rows.find(entry => entry[0] === id);
    if (!row || typeof row[1] !== 'string') throw Error(`Missing catalog sound ${id}`);
    return { code: i < 8 ? `A${i + 1}` : `D${i - 7}`, id, name: row[1],
      group: i < 8 ? 'attack' : 'death', volume: 65, status: '未试听', comment: '' };
  });
}

export function sfxAuditionController(candidates) {
  const rows = candidates.map(({ code, id, name, group, volume }) =>
    ({ code, id, name, group, volume, rating: '待定', tags: '' }));
  return `local rows = ${toLua(rows)}\n` + readFileSync(
    new URL('../tools/sfx-audition/controller.lua', import.meta.url), 'utf8');
}
