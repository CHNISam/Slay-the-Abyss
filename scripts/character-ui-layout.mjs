import { cardFaceChildren } from './card-face.mjs';
import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

export function experimentalCharacterControls(theme = nativeTheme) {
  const { plate, text } = nativeControls(theme);
  const { color: c, font: f, space: s } = theme;
  function button(name, frame, label, layout, font = f.label, primary = false, bustId = null) {
    const size = frame.slice(2);
    const cb = layout.choiceBust || { size: 32, well: 32, labelBand: font + s.s };
    const bust = bustId ? cb.size : 0;
    // 头像卡：头像贴顶部内框填满（STS 式方形角色钮），名字落在底部名牌带，不再悬浮在大框中间。
    const bustY = size[1] / 2 - s.xs - cb.well / 2;
    const variants = {
      normal: primary ? [c.gold, c.textOnLight, c.goldBright] : [c.panelRaised, c.goldBright, c.goldDim],
      hover: primary ? [c.goldBright, c.textOnLight, c.goldBright] : [c.buttonHover, c.goldBright, c.goldBright],
      pressed: [c.goldDim, c.buttonPressedText, c.goldBright],
      disabled: [c.panelSunken, c.textMuted, c.line],
    };
    const labelFrame = bust
      ? [0, -size[1] / 2 + cb.labelBand / 2 + s.xs, size[0] - layout.buttonInset[0], cb.labelBand]
      : [0, 0, ...size.map((value, i) => value - layout.buttonInset[i])];
    return { name, kind: 'container', position: frame.slice(0, 2), size, children: [
      { name: 'hit', kind: 'presetButton', size: [...size], focusable: true,
        states: Object.fromEntries(Object.keys(variants).map(state => [state, state])),
        children: Object.entries(variants).map(([state, [fill, ink, border]]) => ({
          name: state, kind: 'container', size: [...size],
          scale: state === 'pressed' ? [layout.pressedScale, layout.pressedScale] : [1, 1],
          children: [plate('border', [0, 0, ...size], border),
            plate('plate', [0, 0, ...size.map(value => value - s.border * 2)], fill),
            ...(bust ? [plate('well', [0, bustY, cb.well, cb.well], c.panelSunken),
              { name: 'bust', kind: 'image', position: [0, bustY],
                size: [bust, bust], image: bustId, colour: c.buttonPressedText }] : []),
            text('label', labelFrame, label, font, ink)],
        })),
      },
      { ...plate('selected', [0, 0, ...size], c.goldBright), visible: false,
        size: [size[0], s.m], position: [0, -size[1] / 2 + s.s] },
    ] };
  }
  function panel(name, layout, title, hint, children, face = c.panel, rim = c.goldDim) {
    return { name, kind: 'container', size: [...theme.canvas.base], visible: false, children: [
      plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil),
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      plate('border', layout.panel, rim),
      plate('face', [...layout.panel.slice(0, 2), ...layout.panel.slice(2).map(value => value - s.border * 2)], face),
      text('title', layout.title, title, f.heading, c.goldBright),
      text('hint', layout.hint, hint, f.label, c.textDim), ...children,
    ] };
  }
  const l = theme.layout.characterSelect, q = theme.layout.combatChoice;
  const names = ['胡桃','阿蕾奇诺','芙宁娜','雷电将军'];
  const roles = ['hutao','arlecchino','furina','raiden'];
  const elementIds = ['ironclad','silent','defect','watcher'];
  const d = l.details;
  const left = control => ({ ...control, text: { ...control.text, align: 'left' } });
  const slots = theme.icon.heroSlots;
  const largePortrait = (name, entry, visible = false) => ({ name, kind: 'image', position: [0, 0],
    size: d.portrait.slice(2), image: entry.id, colour: c.buttonPressedText, visible });
  const tinted = (name, frame, colour, image, opacity) => {
    const control = plate(name, frame, colour);
    return { ...control, image, opacity: (control.opacity ?? 1) * opacity };
  };
  // 元素主题：每位角色/旅行者元素预置一层（立绘背后柔光 + 脚下地面光晕；不再用圆环），视图只切显隐。
  const themes = { name: 'themes', kind: 'container', size: [...theme.canvas.base], children:
    Object.entries(l.themes).map(([id, colour]) => ({ name: id, kind: 'container', size: [...theme.canvas.base], visible: false,
      children: [tinted('glow', l.glow, colour, theme.image.glow, 0.32), tinted('halo', l.halo, colour, theme.image.glow, 0.5)] })) };
  // STS CharacterSelectScreen 式：整屏无盒，左侧信息直接落在暗化地景上（scrim 只做可读性压暗）。
  const v = l.deckView;
  // 初始牌组卡面网格（STS「查看牌组」= 一张张卡面）：直接复用局内牌组的同一卡面（cardFaceChildren 'deck'），视图经 CardDisplay/CardSkin 填充。
  const miniCard = i => {
    const [cw, ch] = v.cardSize, col = i % v.columns, row = Math.floor(i / v.columns);
    const [w, h] = theme.layout.card.size;
    return { name: `deckCard${i + 1}`, kind: 'container', position: [v.origin[0] + col * v.step[0], v.origin[1] - row * v.step[1]],
      size: [cw, ch], visible: false, children: [
        { name: 'face', kind: 'container', size: [w, h], children: cardFaceChildren(theme, 'deck', false) },
      ] };
  };
  const deckView = { name: 'deckView', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
    { ...plate('veil', [0, 0, ...theme.canvas.base], c.backdrop), opacity: 0.94 },
    { name: 'catch', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
    text('title', v.title, '初始牌组', f.heading, c.goldBright),
    ...Array.from({ length: v.columns * v.rows }, (_, i) => miniCard(i)),
    text('overflow', v.overflow, '', f.label, c.textDim),
    button('close', v.close, '返回', l),
  ] };
  return [
    panel('characterPanel', l, '选择你的同行者', '查看初始信息，确认后开始冒险。', [
      themes,
      { ...plate('scrim', l.scrim, c.backdrop), image: theme.image.glowWide, opacity: 0.78 },
      { name: 'details', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
        // 立绘位只是定位框（无底色），人物站在主题地面光晕上。
        { name: 'portraitFrame', kind: 'container', position: d.portrait.slice(0, 2), size: d.portrait.slice(2), children: [] },
        tinted('floorShadow', d.floor, c.cardShadow, theme.image.glow, 0.55),
        { name: 'portraits', kind: 'container', position: d.portrait.slice(0, 2), size: d.portrait.slice(2), children: [
          ...elementIds.map(id => largePortrait(`traveler_${id}`, slots.large.traveler[id], id === 'ironclad')),
          ...roles.map(id => largePortrait(id, slots.large[id])),
        ] },
        text('portraitNote', d.portraitNote, '', f.small, c.textMuted),
        // 信息层级（STS）：名字 → 生命/金币 → 初始遗物（名+效果）→ 初始牌组摘要 + 查看牌组。
        left(text('name', d.name, '', f.title, c.goldBright)),
        left(text('stats', d.hp, '', f.heading, c.hp)),
        left(text('gold', d.gold, '', f.heading, c.gold)),
        left(text('relicTag', d.relicTag, '初始遗物', f.small, c.textDim)),
        left(text('relic', d.relic, '', f.body, c.goldBright)),
        left(text('relicText', d.relicText, '', f.label, c.text)),
        plate('deckRule', d.rule, c.goldDim),
        left(text('deckTitle', d.deckTitle, '', f.label, c.gold)),
        left(text('deckSummary', d.deckSummary, '', f.body, c.text)),
        button('deckOpen', d.deckButton, '查看牌组', l, f.label),
      ] },
      { name: 'elements', kind: 'container', size: [...theme.canvas.base], visible: false, children:
        l.elements.map((frame, i) => button(`element${i + 1}`, frame, ['岩', '风', '雷', '草'][i], l, f.small, false,
          null)) },
      ...l.choices.map((frame, i) => button(`character${i + 1}`, frame, names[i], l, f.small, false, slots.bust[roles[i]].id)),
      button('traveler', l.traveler, '旅行者·荧', l, f.small, false, slots.bust.traveler.ironclad.id),
      button('cancel', l.back, '返回', l),
      button('confirm', l.confirm, '开始冒险', l, f.heading, true),
      deckView,
    ], c.backdrop, c.backdrop),
    panel('choicePanel', q, '选择卡牌', '', [
      ...Array.from({ length: q.columns * q.rows }, (_, i) => {
        const control = button(`card${i + 1}`,
          [q.origin[0] + (i % q.columns) * q.step[0], q.origin[1] + Math.floor(i / q.columns) * q.step[1], ...q.cardSize], '', q, f.small);
        // One shared face, not four copies inside the native button states.
        control.children.unshift({ name: 'face', kind: 'container', size: [...theme.layout.card.size],
          children: cardFaceChildren(theme, 'deck', false) });
        control.children.push({ ...plate('orderPlate', q.orderBadge, c.panelSunken), visible: false },
          { ...text('order', [...q.orderBadge.slice(0, 3), theme.layout.nativeText.lineHeight], '', f.label, c.goldBright), visible: false });
        return control;
      }),
      text('status', q.status, '', f.label, c.textDim),
      button('before', q.before, '上一页', q), button('after', q.after, '下一页', q),
      button('confirm', q.confirm, '确认', q),
    ]),
  ];
}
