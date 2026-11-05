import assert from 'node:assert/strict';
import {relicRound3Composition} from './relic-round3-composition.mjs';

// Reuse two exact, independently locked approved hunks. Selection refactors
// outside these policy sections need no new whole-file historical projection.
const binding=relicRound3Composition.targets.round3.files['src/lua/abyss_card_actions.lua'];
// TASK-74.18: exact inverse of the two same-module drain extractions. Keep
// the historical relic hunk and oracle intact; reject drift in either body.
const actionBody=`    local keep=retained[item.effect.op] or (M.reactionRetained(item.effect) or item.effect.op=='silentFinal' and require('abyss_silent_final_cards').allowedAfterVictory(item.effect))
    if item.effect.op=='enemyAction'then keep=combat.enemyActionRetained(item.effect)end
    if not outcome or outcome=="victory" and keep then M.apply(combat,state,item) end
`;
const refreshBody=`    -- Refresh observes the empty manager, then its draw joins this owner.
    local rare=require('abyss_rare_relics')
    return not outcome and not state.endTurnAfterCard and rare.owns(state,'unceasing_top')
        and rare.onRefreshHand(state,true)
`;
const extracted=`local function applyDrainedAction(combat,state,item,outcome)\n${actionBody}end
local function refreshDrainedHand(state,outcome)\n${refreshBody}end\n`;
const indent=body=>body.split('\n').map(line=>line?'        '+line:line).join('\n');
const drainHunks=[
  [extracted,''],
  ['            applyDrainedAction(combat,state,item,outcome)\n',indent(actionBody)],
  ['            local drew=refreshDrainedHand(state,outcome)\n',indent(refreshBody.replace('    return ','    local drew='))],
];
export function preDrainActionPolicySection(section){
  let projected=section;
  for(const [after,before] of drainHunks){
    assert.equal(projected.split(after).length-1,1,'exact single approved drain extraction');
    projected=projected.replace(after,before);
  }
  assert.doesNotMatch(projected,/\b(?:applyDrainedAction|refreshDrainedHand)\b/,'no extra extracted helper references');
  let restored=projected;
  for(const [after,before] of [...drainHunks].reverse()){
    if(before){
      assert.equal(restored.split(before).length-1,1,'unique original drain body');
      restored=restored.replace(before,after);
    }else{
      assert.equal(restored.split('function M.drain(combat,state)\n').length-1,1,'unique drain anchor');
      restored=restored.replace('function M.drain(combat,state)\n',after+'function M.drain(combat,state)\n');
    }
  }
  assert.equal(restored,section,'drain extraction roundtrip');
  return projected;
}
export function preRelicActionPolicySection(section,kind){
  if(kind==='victory')section=preDrainActionPolicySection(section);
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
