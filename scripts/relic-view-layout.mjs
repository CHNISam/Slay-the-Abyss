import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

// TASK-4.7 owned-relic art slots. Prototype topBar(): owned relics are 32px
// gold-rimmed discs in a 36px row; shop relics pair the same disc with name and
// text. Every disc binds theme.icon.relic[id]; placeholder ids stay swappable.
export function relicDisc(theme, name, size, ring, iconSize, position = [0, 0]) {
  const { plate } = nativeControls(theme);
  const c = theme.color, disc = (n, d, colour) => ({ ...plate(n, [0, 0, d, d], colour), image: theme.image.disc });
  return { name, kind: 'container', position, size: [size, size], children: [
    disc('rim', size, c.goldDim), disc('face', size - ring * 2, c.panelRaised),
    { ...disc('light', size - ring * 2, c.panelSunken), image: theme.image.discSoft },
    { name: 'icon', kind: 'image', position: [0, 0], size: [iconSize, iconSize], image: theme.icon.node.treasure.id ?? theme.icon.node.treasure, colour: c.geo },
  ] };
}

export function relicViewControls(theme = nativeTheme) {
  const { plate, text } = nativeControls(theme);
  const { color: c, font: f, layout: l, space: s } = theme, v = l.relicView;
  const left = (control) => ({ ...control, text: { ...control.text, align: 'left' } });
  const button = (name, frame, label) => {
    const size = frame.slice(2), variants = { normal: [c.panelRaised, c.goldBright, c.goldDim],
      hover: [c.panelRaised, c.goldBright, c.goldBright], pressed: [c.goldDim, c.text, c.goldBright],
      disabled: [c.panelSunken, c.textMuted, c.line] };
    return { name, kind: 'container', position: frame.slice(0, 2), size, children: [
      { name: 'hit', kind: 'presetButton', size, focusable: true,
        states: Object.fromEntries(Object.keys(variants).map(k => [k, k])),
        children: Object.entries(variants).map(([state, [fill, ink, border]]) => ({ name: state, kind: 'container', size, children: [
          plate('border', [0, 0, ...size], border), plate('plate', [0, 0, ...size.map(x => x - s.border * 2)], fill),
          text('label', [0, 0, ...size.map(x => x - s.s)], label, f.label, ink)] })) },
    ] };
  };
  const b = v.bar;
  const bar = Array.from({ length: b.count }, (_, i) => {
    const slot = relicDisc(theme, `slot${i + 1}`, b.disc, (b.disc - b.face) / 2, b.icon, [b.origin[0] + b.step * i, b.origin[1]]);
    slot.visible = false;
    slot.children.push({ name: 'hit', kind: 'cursorArea', size: [44, 44], focusable: true });
    return slot;
  });
  const [rw, rh] = v.row, discX = -rw / 2 + s.m + v.disc / 2;
  const rows = [];
  v.rows.forEach((y, r) => v.columns.forEach((x, col) => {
    rows.push({ name: `row${rows.length + 1}`, kind: 'container', position: [x, y], size: [rw, rh], visible: false, children: [
      plate('border', [0, 0, rw, rh], c.goldDim), plate('plate', [0, 0, rw - s.border * 2, rh - s.border * 2], c.panel),
      relicDisc(theme, 'slot', v.disc, v.discRing, v.icon, [discX, 0]),
      left(text('name', v.name, '', f.heading, c.goldBright)),
      { name: 'chip', kind: 'container', position: v.chip.slice(0, 2), size: v.chip.slice(2), visible: false, children: [
        { ...plate('border', [0, 0, ...v.chip.slice(2)], c.goldDim) },
        plate('plate', [0, 0, ...v.chip.slice(2).map(x => x - s.border * 2)], c.panelSunken),
        text('label', [0, 0, ...v.chip.slice(2)], '', f.small, c.goldBright)] },
      (d => ({ ...d, text: { ...d.text, valign: 'top' } }))(left(text('description', v.description, '', f.small, c.text))),
    ] });
  }));
  return [
    { name: 'relicBar', kind: 'container', size: [...theme.canvas.base], visible: false, children: bar },
    { name: 'relicPanel', kind: 'container', size: [...theme.canvas.base], visible: false, isolateNavigation: true, children: [
      { ...plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil.slice(0, 7)),
        opacity: c.backdropVeil.length === 9 ? parseInt(c.backdropVeil.slice(7), 16) / 255 : 1 },
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      plate('frame', [0, 0, ...v.panel.slice(2)], c.goldDim),
      plate('plate', [0, 0, ...v.panel.slice(2).map(x => x - s.border * 2)], c.panelSunken),
      text('title', v.title, '持有遗物', f.heading, c.goldBright),
      ...rows,
      { ...text('placeholder', [0, 0, 600, 48], '本局尚未获得遗物。', f.body, c.textDim), visible: false },
      button('close', v.close, '关闭'),
      { ...button('previous', v.previous, '上一页'), visible: false },
      { ...button('next', v.next, '下一页'), visible: false },
      { ...text('pageHint', v.pageHint, '', f.small, c.textDim), visible: false },
    ] },
  ];
}
