import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

export function experimentalCharacterControls(theme = nativeTheme) {
  const { plate, text } = nativeControls(theme);
  const { color: c, font: f, space: s } = theme;
  function button(name, frame, label, layout, font = f.label) {
    const size = frame.slice(2);
    const variants = {
      normal: [c.panelRaised, c.goldBright, c.goldDim],
      hover: [c.buttonHover, c.goldBright, c.goldBright],
      pressed: [c.goldDim, c.buttonPressedText, c.goldBright],
      disabled: [c.panelSunken, c.textMuted, c.line],
    };
    return { name, kind: 'container', position: frame.slice(0, 2), size, children: [
      { name: 'hit', kind: 'presetButton', size: [...size], focusable: true,
        states: Object.fromEntries(Object.keys(variants).map(state => [state, state])),
        children: Object.entries(variants).map(([state, [fill, ink, border]]) => ({
          name: state, kind: 'container', size: [...size],
          scale: state === 'pressed' ? [layout.pressedScale, layout.pressedScale] : [1, 1],
          children: [plate('border', [0, 0, ...size], border),
            plate('plate', [0, 0, ...size.map(value => value - s.border * 2)], fill),
            text('label', [0, 0, ...size.map((value, i) => value - layout.buttonInset[i])], label, font, ink)],
        })),
      },
      { ...plate('selected', [0, 0, ...size], c.goldBright), visible: false,
        size: [size[0], s.border], position: [0, -size[1] / 2 + s.border] },
    ] };
  }
  function panel(name, layout, title, hint, children) {
    return { name, kind: 'container', size: [...theme.canvas.base], visible: false, children: [
      plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil),
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      plate('border', layout.panel, c.goldDim),
      plate('face', [...layout.panel.slice(0, 2), ...layout.panel.slice(2).map(value => value - s.border * 2)], c.panel),
      text('title', layout.title, title, f.heading, c.goldBright),
      text('hint', layout.hint, hint, f.label, c.textDim), ...children,
    ] };
  }
  const l = theme.layout.characterSelect, q = theme.layout.combatChoice;
  const names = ['胡桃','阿蕾奇诺','芙宁娜','雷电将军'];
  const d = l.details;
  return [
    panel('characterPanel', l, '选择同行者', '请选择一位同行者。', [
      { name: 'details', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
        plate('portraitFrame', d.portrait, c.panelSunken),
        { name: 'portrait', kind: 'image', position: d.portrait.slice(0, 2), size: d.portrait.slice(2),
          image: theme.icon.characterPortraits.traveler.id },
        text('portraitNote', d.portraitNote, '', f.label, c.textDim),
        text('name', d.name, '', f.heading, c.goldBright),
        text('stats', d.stats, '', f.body, c.text),
        text('relic', d.relic, '', f.body, c.gold),
        text('deckTitle', d.deckTitle, '', f.label, c.textDim),
        ...d.cards.map((frame, i) => text(`card${i + 1}`, frame, '', f.body, c.text)),
      ] },
      { name: 'elements', kind: 'container', size: [...theme.canvas.base], visible: false, children:
        l.elements.map((frame, i) => button(`element${i + 1}`, frame, ['岩', '风', '雷', '草'][i], l, f.body)) },
      ...l.choices.map((frame, i) => button(`character${i + 1}`, frame, names[i], l, f.body)),
      button('traveler',l.traveler,'旅行者·荧',l),
      button('cancel', l.back, '返回', l),
      button('confirm', l.confirm, '确认开始冒险', l),
    ]),
    panel('choicePanel', q, '选择卡牌', '', [
      ...Array.from({ length: q.columns * q.rows }, (_, i) => button(`card${i + 1}`,
        [q.origin[0] + (i % q.columns) * q.step[0], q.origin[1] + Math.floor(i / q.columns) * q.step[1], ...q.cardSize], '', q, f.small)),
      text('status', q.status, '', f.label, c.textDim),
      button('before', q.before, '上一页', q), button('after', q.after, '下一页', q),
      button('confirm', q.confirm, '确认', q),
    ]),
  ];
}
