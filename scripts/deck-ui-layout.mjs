import { nativeControls, nativeTheme } from './native-ui-theme.mjs';
import { cardFaceChildren } from './card-face.mjs';

// Reserve a real native line below the unchanged card face for choice feedback.
const itemSize = theme => [theme.layout.deckView.itemSize[0], Math.max(theme.layout.deckView.itemSize[1],
  theme.layout.card.size[1] + theme.layout.nativeText.lineHeight)];

export function deckCardTemplate(theme = nativeTheme) {
  const { text } = nativeControls(theme);
  const { color: c, font: f, layout: l } = theme;
  const [w, h] = l.card.size;
  const size = itemSize(theme), line = l.nativeText.lineHeight;
  return { name: 'AbyssDeckCard', kind: 'container', size, children: [
    { name: 'face', kind: 'container', position: [0, (size[1] - h) / 2],
      size: [w, h], children: cardFaceChildren(theme, 'deck', false) },
    text('uid', [0, -size[1] / 2 + line / 2, w, line], '', f.small, c.textDim),
    {name:'hit',kind:'cursorArea',position:[0,(size[1]-h)/2],size:[w,h],focusable:true,visible:false},
  ] };
}

export function deckControls(theme = nativeTheme) {
  const { plate, text } = nativeControls(theme);
  const { layout: l, color: c, font: f, space: s } = theme;
  const button = (name, frame, label) => {
    const size = frame.slice(2);
    const variants = { normal: [c.panelRaised, c.goldBright, c.goldDim], hover: [c.panelRaised, c.goldBright, c.goldBright],
      pressed: [c.goldDim, c.text, c.goldBright], disabled: [c.panelSunken, c.textMuted, c.line] };
    return { name, kind: 'container', position: frame.slice(0, 2), size, children: [
      { name: 'hit', kind: 'presetButton', size, focusable: true,
        states: Object.fromEntries(Object.keys(variants).map(state => [state, state])),
        children: Object.entries(variants).map(([state, [background, ink, border]]) => ({
          name: state, kind: 'container', size, scale: state === 'pressed' ? [l.deckView.pressedScale, l.deckView.pressedScale] : [1, 1], children: [
            plate('border', [0, 0, ...size], border),
            plate('plate', [0, 0, ...size.map(value => value - s.border * 2)], background),
            text('label', [0, 0, ...size.map(value => value - s.s)], label, f.label, ink),
          ],
        })),
      },
    ] };
  };
  return [
    { name: 'deckEntry', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
      button('open', l.deckView.entry, '卡组'),
    ] },
    { name: 'deckPanel', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
      { ...plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil.slice(0, 7)),
        opacity: c.backdropVeil.length === 9 ? parseInt(c.backdropVeil.slice(7), 16) / 255 : 1 },
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      { name: 'grid', kind: 'grid', position: l.deckView.viewport.slice(0, 2), size: l.deckView.viewport.slice(2),
        itemTemplate: deckCardTemplate(theme).name, grid: { columns: l.deckView.columns, horizontal: false,
          itemSize: itemSize(theme), spacing: [...l.deckView.spacing], padding: [...l.deckView.padding], scrollbar: true } },
      text('title', l.deckView.title, '', f.heading, c.goldBright),
      { ...text('details', l.deckView.viewport, '', f.body, c.text), visible: false },
      { name: 'detailHit', kind: 'cursorArea', position: l.deckView.viewport.slice(0, 2),
        size: l.deckView.viewport.slice(2), focusable: true, visible: false },
      button('close', l.deckView.close, '关闭'),
      { ...button('previous', l.deckView.previous, '上一页'), visible: false },
      { ...button('next', l.deckView.next, '下一页'), visible: false },
      { ...text('pageHint', l.deckView.pageHint, '', f.small, c.textDim), visible: false },
    ] },
  ];
}
