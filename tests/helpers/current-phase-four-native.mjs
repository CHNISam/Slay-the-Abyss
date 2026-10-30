// Current full-card render witnesses are byte-frozen. Supply only the explicit
// native engine boundary their platform predates; do not project rules or data.
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
export const currentPhaseFourNativeFixtures = Object.freeze([
  'tests/lua/phase_four_presentation_render.lua',
  'tests/lua/phase_four_presentation_render_slice_2.lua',
  'tests/lua/phase_four_presentation_render_slice_3.lua',
  'tests/lua/phase_four_presentation_render_slice_4.lua',
]);
const root=fileURLToPath(new URL('../../',import.meta.url));
const prelude=`local BattleUI=require('abyss_battle_ui')
local nativeBattleUI=BattleUI.new
BattleUI.new=function(stage,data,presentation,event,platform,...)
    local F=dofile('tests/lua/support/game_ui_fixture.lua')
    return nativeBattleUI(stage,data,presentation,event,F.withMonsterActors(platform),...)
end
`;
export function currentPhaseFourNativePrelude(script,{cwd=process.cwd()}={}) {
  if(resolve(cwd)!==resolve(root)||!currentPhaseFourNativeFixtures.includes(script))return '';
  return prelude;
}
