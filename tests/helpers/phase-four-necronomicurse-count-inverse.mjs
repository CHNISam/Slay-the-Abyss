// Additive event curse coverage; preserve every original and Bell render assertion.
import {restoreExactFixtureHunks} from './exact-fixture-hunks.mjs';
export const phaseFourNecronomicurseCounts=Object.freeze({
 "path": "tests/lua/phase_four_presentation_render.lua",
 "beforeSha256": "28d64276d267ddc601c3e81e672a2e5f0ce042aab8b7c2e84c6c6b12c2f20e63",
 "afterSha256": "db8a0a2f911ad4e656b4c927d284bc3d446566398132dfdce9e44d3b5302e747",
 "hunks": [
  {
   "at": 22,
   "before": "  eq(#data.cards.cards,({ironclad=81,silent=91,defect=91,watcher=101})[id])",
   "after": "  eq(#data.cards.cards,({ironclad=82,silent=92,defect=92,watcher=102})[id])"
  },
  {
   "at": 54,
   "before": "local expected=0;for i=first,last do expected=expected+({162,182,182,202})[i]end",
   "after": "local expected=0;for i=first,last do expected=expected+({164,184,184,204})[i]end"
  }
 ]
});
export function prePhaseFourNecronomicurseCountSource(path,source){
 return restoreExactFixtureHunks(phaseFourNecronomicurseCounts,path,source);
}
