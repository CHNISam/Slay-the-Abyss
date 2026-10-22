import { battleLayout } from './ui-layout.mjs';
import { mapLayout } from './map-ui-layout.mjs';
import { nodeLayout } from './node-ui-layout.mjs';

export function gameLayout() {
  return {
    name: 'SlayTheAbyss', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [
      { name: 'battlePanel', kind: 'container', size: [1280, 720], children: battleLayout().controls },
      ...mapLayout().controls,
      ...nodeLayout().controls,
      { name: 'menuPanel', kind: 'container', size: [1280, 720], children: [
        { name: 'backdrop', kind: 'image', size: [1240, 680], image: 100001, colour: '#0F1117' },
        { name: 'title', kind: 'text', position: [0, 240], size: [1120, 64],
          text: { content: '杀戮深渊 · 荧 · 岩', fontSize: 36, colour: '#E3B866', align: 'centre', valign: 'middle' } },
        { name: 'summary', kind: 'text', position: [0, 30], size: [1080, 280],
          text: { content: '', fontSize: 24, colour: '#ECE6DA', align: 'centre', valign: 'middle', autoSize: true, minFontSize: 18 } },
        { name: 'start', kind: 'container', position: [0, -230], size: [320, 64], children: [
          { name: 'plate', kind: 'image', size: [320, 64], image: 100001, colour: '#272A36' },
          { name: 'label', kind: 'text', size: [304, 60], text: { content: '启程', fontSize: 26, colour: '#E3B866', align: 'centre', valign: 'middle' } },
          { name: 'hit', kind: 'cursorArea', size: [320, 64], focusable: true },
        ] },
      ] },
    ],
  };
}
