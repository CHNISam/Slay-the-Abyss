import assert from 'node:assert/strict';
import {relicRound3Composition} from './relic-round3-composition.mjs';

// Reuse two exact, independently locked approved hunks. Selection refactors
// outside these policy sections need no new whole-file historical projection.
const binding=relicRound3Composition.targets.round3.files['src/lua/abyss_card_actions.lua'];
export function preRelicActionPolicySection(section,kind){
  const at={admission:14,victory:505}[kind];
  assert.notEqual(at,undefined,'known policy section');
  const hunk=assertHunk(binding.hunks.find(h=>h.at===at));
  const after=hunk.after.join('\n')+'\n';
  assert.equal(section.split(after).length-1,1,`exact single approved ${kind} hunk`);
  const index=section.indexOf(after);
  const before=hunk.before.length?hunk.before.join('\n')+'\n':'';
  return section.slice(0,index)+before+section.slice(index+after.length);
}
function assertHunk(hunk){assert(hunk,'locked policy hunk exists');return hunk;}
