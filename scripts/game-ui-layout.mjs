import { battleLayout } from './ui-layout.mjs';
import { mapLayout } from './map-ui-layout.mjs';
import { nodeLayout } from './node-ui-layout.mjs';
import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

export function gameLayout(theme = nativeTheme) {
  const { text, plate, button } = nativeControls(theme);
  const layout = theme.layout.nativeMenu, { color, font } = theme;
  const battle = structuredClone(battleLayout());
  const battleControls = battle.controls.find(control => control.name === 'stage').children;
  const map = structuredClone(mapLayout(theme));
  const mapPanel = map.controls.find(control => control.name === 'stage').children.find(control => control.name === 'mapPanel');
  mapPanel.visible = false;
  return {
    name: 'SlayTheAbyss', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [
      { name: 'battlePanel', kind: 'container', size: [...theme.canvas.base], visible: false, children: battleControls },
      mapPanel,
      ...nodeLayout(theme).controls.map(control => ({ ...control, visible: false })),
      { name: 'menuPanel', kind: 'container', size: [...theme.canvas.base], children: [
        plate('backdrop', layout.backdrop, color.backdrop),
        text('title', layout.title, '杀戮深渊 · 荧 · 岩', font.display, color.gold),
        text('summary', layout.summary, '', font.heading),
        button('start', layout.start, '启程', { inset: layout.buttonInset, fontSize: font.heading, colour: color.gold }),
        { ...button('settle', layout.settle, '结束并结算', { inset: layout.buttonInset, states: true,
          fontSize: font.heading, colour: color.gold }), visible: false },
      ] },
    ],
  };
}
