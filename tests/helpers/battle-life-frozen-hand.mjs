// These pre-existing, byte-guarded cases start after the current opening-hand
// animation settles. Every render and interpolation still executes production.
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export const frozenBattleHandFixtures = Object.freeze([
  'tests/lua/battle_ui.lua', 'tests/lua/battle_ui_slice_2.lua',
  'tests/lua/battle_ui_slice_3.lua', 'tests/lua/battle_ui_slice_4.lua',
  'tests/lua/battle_ui_slice_5.lua', 'tests/lua/battle_ui_slice_6.lua',
  'tests/lua/battle_ui_slice_7.lua', 'tests/lua/card_input_port.lua',
  'tests/lua/card_input_port_slice_2.lua', 'tests/lua/card_input_port_slice_3.lua',
  ...Array.from({length: 8}, (_, index) =>
    `tests/lua/card_help_release${index === 0 ? '' : '_slice_' + (index + 1)}.lua`),
]);
const root = fileURLToPath(new URL('../../', import.meta.url));
const prelude = `local CardView=require('abyss_battle_card_view')
local createCardView=CardView.new
CardView.new=function(view,...)
    local instance=createCardView(view,...)
    local renderCards=instance.renderCards
    local settledBattle
    instance.renderCards=function(...)
        local result=renderCards(...)
        local battle=view.run and view.run.combat
        if battle and battle~=settledBattle and not view.displayBattle then
            settledBattle=battle
            for _=1,80 do instance.update(1/60)end
        end
        return result
    end
    return instance
end
`;

export function frozenBattleHandPrelude(script, {cwd = process.cwd()} = {}) {
  if (resolve(cwd) !== resolve(root) || !frozenBattleHandFixtures.includes(script)) return '';
  return prelude;
}
