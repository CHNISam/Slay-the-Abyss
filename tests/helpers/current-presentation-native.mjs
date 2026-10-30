// Exact frozen current fixtures predate the mandatory dynamic actor engine.
// Supply the real generated-template mock, never project production or case bodies.
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
export const currentPresentationNativeFixtures=Object.freeze([
 'tests/lua/phase_four_presentation.lua',
 'tests/lua/phase_three_presentation.lua',
 'tests/lua/phase_three_presentation_slice_2.lua',
 'tests/lua/phase_three_presentation_slice_3.lua',
 'tests/lua/character_presentation.lua',
 ...Array.from({length:15},(_,i)=>`tests/lua/character_presentation_budget_${i+2}.lua`),
]);
const root=fileURLToPath(new URL('../../',import.meta.url));
const prelude=`local BattleUI=require('abyss_battle_ui')
local nativeBattleUI=BattleUI.new
BattleUI.new=function(stage,data,presentation,event,platform,...)
    local F=dofile('tests/lua/support/game_ui_fixture.lua')
    return nativeBattleUI(stage,data,presentation,event,F.withMonsterActors(platform),...)
end
`;
export function currentPresentationNativePrelude(script,{cwd=process.cwd()}={}){
 if(resolve(cwd)!==resolve(root)||!currentPresentationNativeFixtures.includes(script))return '';
 return prelude;
}
