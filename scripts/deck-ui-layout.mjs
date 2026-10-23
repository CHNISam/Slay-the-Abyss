import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

export function deckCardTemplate(theme = nativeTheme) {
  const { text, plate } = nativeControls(theme);
  const { color: c, font: f, layout: l, space: s } = theme;
  const [w, h] = l.card.size, d = l.card.costDisc;
  const image = (name, frame, id, colour) => ({ name, kind: 'image',
    position: frame.slice(0, 2), size: frame.slice(2), image: id, colour });
  const nameY = h / 2 - l.card.nameBand / 2 - s.border;
  const artY = h / 2 - l.card.nameBand - l.card.art / 2 - s.border;
  return { name: 'AbyssDeckCard', kind: 'container', size: [...l.deckView.itemSize], children: [
    { name: 'face', kind: 'container', position: [0, (l.deckView.itemSize[1] - h) / 2],
      size: [w, h], children: [
        plate('border', [0, 0, w, h], c.rarity.basic),
        plate('plate', [0, 0, w - s.border * 2, h - s.border * 2], c.panel),
        plate('nameBand', [0, nameY, w - s.border * 2, l.card.nameBand], c.panelRaised),
        text('name', [d / 2, nameY, w - d - s.s, l.card.nameBand], '', f.cardName),
        plate('artPlate', [0, artY, w - s.border * 2, l.card.art], c.cardType.attack),
        image('art', [0, artY, d, d], theme.icon.cardArt.attack, c.text),
        text('type', [0, h / 2 - l.card.nameBand - l.card.art - l.card.typeLine / 2, w - s.s, l.nativeText.lineHeight], '', f.small, c.gold),
        text('label', [0, -h / 2 + l.card.textBox[1] / 2 + s.xs, ...l.card.textBox], '', f.card),
        image('costDisc', [-w / 2 + d / 2, h / 2 - d / 2, d, d], theme.image.disc, c.energy),
        text('cost', [-w / 2 + d / 2, h / 2 - d / 2, d, d], '', f.number, c.textOnLight),
      ] },
    text('uid', [0, -l.deckView.itemSize[1] / 2 + l.deckView.uidHeight / 2, w, l.deckView.uidHeight], '', f.small, c.textDim),
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
          itemSize: [...l.deckView.itemSize], spacing: [...l.deckView.spacing], padding: [...l.deckView.padding], scrollbar: true } },
      text('title', l.deckView.title, '', f.heading, c.goldBright),
      button('close', l.deckView.close, '关闭'),
    ] },
  ];
}
