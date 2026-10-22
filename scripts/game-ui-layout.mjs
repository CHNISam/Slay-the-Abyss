import { battleLayout } from './ui-layout.mjs';
import { mapLayout } from './map-ui-layout.mjs';
import { nodeLayout } from './node-ui-layout.mjs';
import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

export function gameLayout(theme = nativeTheme) {
  const { text, plate, button } = nativeControls(theme);
  const layout = theme.layout.nativeMenu, { color, font } = theme;
  return {
    name: 'SlayTheAbyss', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [
      { name: 'battlePanel', kind: 'container', size: [...theme.canvas.base], children: battleLayout(theme).controls },
      ...mapLayout(theme).controls,
      ...nodeLayout(theme).controls,
      { name: 'menuPanel', kind: 'container', size: [...theme.canvas.base], children: [
        plate('backdrop', layout.backdrop, color.backdrop),
        text('title', layout.title, '杀戮深渊 · 荧 · 岩', font.display, color.gold),
        text('summary', layout.summary, '', font.heading),
        button('start', layout.start, '启程', { inset: layout.buttonInset, fontSize: font.heading, colour: color.gold }),
      ] },
    ],
  };
}
