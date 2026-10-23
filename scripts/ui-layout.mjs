import { readFileSync } from 'node:fs';

// One source of tokens for both the native tree and its Lua controller.
export const theme = JSON.parse(readFileSync(new URL('../data/presentation/ui_theme.json', import.meta.url), 'utf8'));
const { color: c, font: f, image: im, layout: l, space: s } = theme;
const text = (name, x, y, w, h, content = '', fontSize = f.body, colour = c.text) => ({
  name, kind: 'text', position: [x, y], size: [w, h],
  text: { content, fontSize, colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: f.minimum },
});
const picture = (name, x, y, w, h, image, colour = c.text) => ({ name, kind: 'image', position: [x, y], size: [w, h], image, colour });
const panel = (name, x, y, w, h, colour) => picture(name, x, y, w, h, im.rect, colour);
const hit = (w, h) => ({ name: 'hit', kind: 'cursorArea', size: [w, h], focusable: true });

function button(name, position, size, label, primary = false, fontSize = f.heading) {
  const [w, h] = size;
  const variants = {
    normal: [primary ? c.geo : c.panelRaised, primary ? c.textOnLight : c.goldBright, c.gold],
    hover: [primary ? c.goldBright : c.panelRaised, primary ? c.textOnLight : c.goldBright, c.goldBright],
    pressed: [c.goldDim, c.text, c.goldBright], disabled: [c.panelSunken, c.textMuted, c.line],
  };
  return { name, kind: 'presetButton', position, size, focusable: true,
    states: Object.fromEntries(Object.keys(variants).map(key => [key, key])),
    children: Object.entries(variants).map(([state, [bg, ink, border]]) => ({ name: state, kind: 'container', size,
      scale: state === 'pressed' ? [0.96, 0.96] : [1, 1], children: [
        panel('border', 0, 0, w, h, border), panel('plate', 0, 0, w - s.border * 2, h - s.border * 2, bg),
        text('label', 0, 0, w - s.l, h - s.s, label, fontSize, ink),
      ] })),
  };
}

function unit(name, position, portrait, player = false) {
  const [bw, bh] = l.hpBar.size, bb = l.blockBadge;
  return { name, kind: 'container', position, size: [bw, 236], children: [
    panel('border', 0, 0, portrait + s.border * 2, portrait + s.border * 2, player ? c.goldDim : c.line),
    panel('plate', 0, 0, portrait, portrait, c.panelRaised),
    picture('portrait', 0, 0, portrait - s.l, portrait - s.l, theme.icon.player, c.geo),
    text('name', 0, -portrait / 2 - s.m, bw, l.nativeText.lineHeight, player ? '旅行者' : '', f.label, c.gold),
    panel('hpBorder', 0, -portrait / 2 - s.xxl - bh / 2, bw + s.border * 2, bh + s.border * 2, c.line),
    panel('hpTrack', 0, -portrait / 2 - s.xxl - bh / 2, bw, bh, c.hpTrack),
    { ...panel('hpGhost', 0, -portrait / 2 - s.xxl - bh / 2, bw, bh, c.hpGhost), mask: true, fill: {shape: 'horizontal', from: 'left', amount: 1} },
    { ...panel('hpFill', 0, -portrait / 2 - s.xxl - bh / 2, bw, bh, c.hp), mask: true, fill: {shape: 'horizontal', from: 'left', amount: 1} },
    text('hp', 0, -portrait / 2 - s.xxl - bh / 2, bw, l.nativeText.lineHeight, '', f.small),
    // Solid chip beside the bar: icon 102014 is half hollow, so digits on it were unreadable.
    panel('blockEdge', -bw / 2 - bb.gap - bb.size / 2, -portrait / 2 - s.xxl - bh / 2, bb.size + s.border * 2, bb.size + s.border * 2, c.panelSunken),
    panel('blockIcon', -bw / 2 - bb.gap - bb.size / 2, -portrait / 2 - s.xxl - bh / 2, bb.size, bb.size, c.block),
    text('block', -bw / 2 - bb.gap - bb.size / 2, -portrait / 2 - s.xxl - bh / 2, bb.size, l.nativeText.lineHeight, '', f.body, c.textOnLight),
    text('statuses', 0, -portrait / 2 - s.xxl - bh - s.l, bw + s.xl, l.nativeText.lineHeight, '', f.small, c.textDim),
    { ...picture('impact', 0, 0, portrait, portrait, im.diamond, c.geo), visible: false },
    { ...picture('shield', 0, 0, portrait, portrait, theme.icon.block, c.block), visible: false },
    { ...text('floating', 0, portrait / 2, bw + s.xxl, l.nativeText.lineHeight * 2, '', f.number, c.goldBright), visible: false },
    ...(!player ? [picture('intentIcon', -s.xl, l.intent.offsetY, l.intent.size, l.intent.size, theme.icon.intent.unknown, c.textDim),
      text('intent', s.l, l.intent.offsetY, 100, l.intent.size, '', f.number), hit(portrait, portrait)] : []),
  ] };
}

export function handPose(count, index, selected = false) {
  const [w, h] = l.card.size;
  const spacing = count <= 1 ? 0 : Math.max(l.hand.spacingMin, Math.min(l.hand.spacingMax, (l.hand.maxWidth - w) / (count - 1)));
  const distance = index - (count - 1) / 2;
  const scale = selected ? theme.motion.hoverScale : 1;
  // Keep complete rotated cards inside the safe area, including ten-card hands.
  const angle = -distance * l.hand.arcDegrees;
  const radians = Math.abs(angle) * Math.PI / 180;
  const halfHeight = (h * Math.cos(radians) + w * Math.sin(radians)) / 2;
  const floor = -theme.canvas.base[1] / 2 + theme.canvas.safe.y + halfHeight;
  return { position: [distance * spacing, Math.max(floor, l.hand.y - Math.abs(distance) * l.hand.arcDrop) + (selected ? theme.motion.hoverLift : 0)],
    rotation: selected ? 0 : angle, scale: [scale, scale] };
}

export function battleLayout() {
  const [width, height] = theme.canvas.base;
  const bar = l.topBar, y = bar.y, iconId = entry => (typeof entry === 'object' ? entry.id : entry);
  // Icon + number chips, as on the node top bar; the deck count lives on the shared deck button.
  const chip = (name, [x, w], colour, fontSize = f.body) => text(name, x, y, w, bar.height, '', fontSize, colour);
  const glyph = (name, [x, w], image, colour) => picture(name, x, y, w, w, iconId(image), colour);
  // Pile counts sit on a dark badge at the icon's inner corner, with a caption below.
  const pile = (name, icon, [x, py], caption, side) => {
    const b = l.pileBadge, [bx, by] = [x + side * b.offset[0], py + b.offset[1]];
    return [
      picture(`${name}Icon`, x, py, ...l.drawPile.size, icon, c.textDim),
      picture(`${name}BadgeRing`, bx, by, b.disc, b.disc, im.disc, c.goldDim),
      picture(`${name}Badge`, bx, by, b.disc - s.border * 2, b.disc - s.border * 2, im.disc, c.panelSunken),
      text(name, bx, by, b.disc, b.disc, '', f.label, c.goldBright),
      text(`${name}Label`, x + b.label[0], py + b.label[1], b.label[2], b.label[3], caption, f.small, c.textDim),
    ];
  };
  const controls = [
    panel('topBar', 0, y, width, bar.height, c.panelSunken),
    text('title', 0, y, 350, bar.height, '杀戮深渊 · 战斗', f.heading, c.gold),
    glyph('hpIcon', bar.hpIcon, theme.icon.hp, c.hp), chip('player', bar.hp),
    glyph('goldIcon', bar.goldIcon, theme.icon.gold, c.text), chip('piles', bar.gold, c.goldBright),
    glyph('exhaustIcon', bar.exhaustIcon, theme.icon.exhaust, c.textDim), chip('exhaust', bar.exhaust, c.textDim),
    unit('hero', l.player.position, l.player.portrait, true),
    text('notice', ...l.battleNotice.position, ...l.battleNotice.size, '', f.body, c.goldBright),
    text('statuses', -380, 194, 350, 26, '', f.small, c.textDim),
    // Outline ring + flat amber face; the Geo mark is a faint watermark so the digits stay clean.
    picture('energyRing', ...l.energy.position, l.energy.size + s.s, l.energy.size + s.s, im.disc, c.geoDeep),
    picture('energyDisc', ...l.energy.position, l.energy.size, l.energy.size, im.disc, c.energy),
    picture('energyIcon', ...l.energy.position, l.energy.size - s.xxl, l.energy.size - s.xxl, theme.icon.energy.id, c.geo),
    text('energy', ...l.energy.position, l.energy.size, l.energy.size, '0/0', f.numberLarge, c.textOnLight),
    ...pile('draw', theme.icon.drawPile, l.drawPile.position, '抽牌堆', 1),
    ...pile('discard', theme.icon.discardPile, l.discardPile.position, '弃牌堆', -1),
  ];
  for (let i = 0; i < l.battlePotions.count; i++) {
    controls.push(button(`potion${i + 1}`, l.battlePotions.origin.map((n, axis) => n + l.battlePotions.step[axis] * i),
      l.battlePotions.size, '空药水槽', false, f.small));
  }
  for (let i = 1; i <= 5; i++) controls.push(unit(`enemy${i}`, [l.enemyRow.xFrom + (i - 1) * 110, l.enemyRow.y], l.enemyRow.portrait));
  for (let i = 1; i <= 10; i++) {
    const [w, h] = l.card.size;
    controls.push({ name: `card${i}`, kind: 'container', size: [w, h], ...handPose(10, i - 1), children: [
      { ...picture('glow', 0, 0, w + s.s, h + s.s, im.glow, c.goldBright), visible: false },
      panel('border', 0, 0, w, h, c.rarity.basic), panel('plate', 0, 0, w - s.border * 2, h - s.border * 2, c.panel),
      panel('nameBand', 0, h / 2 - l.card.nameBand / 2 - s.border, w - s.border * 2, l.card.nameBand, c.panelRaised),
      text('name', l.card.costDisc / 2, h / 2 - l.card.nameBand / 2 - s.border, w - l.card.costDisc - s.s, l.card.nameBand, '', f.cardName),
      panel('artPlate', 0, h / 2 - l.card.nameBand - l.card.art / 2 - s.border, w - s.border * 2, l.card.art, c.cardType.attack),
      picture('art', 0, h / 2 - l.card.nameBand - l.card.art / 2 - s.border, 40, 40, theme.icon.cardArt.attack, c.text),
      text('type', 0, h / 2 - l.card.nameBand - l.card.art - l.card.typeLine / 2, w - s.s, l.nativeText.lineHeight, '', f.small, c.gold),
      text('label', 0, -h / 2 + l.card.textBox[1] / 2 + s.xs, ...l.card.textBox, '', f.card),
      picture('costDisc', -w / 2 + l.card.costDisc / 2, h / 2 - l.card.costDisc / 2, l.card.costDisc, l.card.costDisc, im.disc, c.energy),
      text('cost', -w / 2 + l.card.costDisc / 2, h / 2 - l.card.costDisc / 2, l.card.costDisc, l.card.costDisc, '', f.number, c.textOnLight),
      hit(w, h),
    ] });
  }
  controls.push(button('endTurn', l.endTurn.position, l.endTurn.size, '结束回合'),
    button('start', [0, -96], l.button.primary, '启程', true),
    button('continue', [0, -96], l.button.primary, '再战一场', true),
    panel('resultPlate', 0, 80, 800, 130, c.panelSunken),
    text('result', 0, 80, 780, 122, '', f.title, c.goldBright),
    button('skip', [0, -96], l.button.secondary, '跳过奖励'));
  controls.push({ name: 'dragLayer', kind: 'container', size: [width, height], visible: false, children: [
    { ...hit(width, height), focusable: false },
    panel('line', l.cardDrag.playArea[0], l.cardDrag.lineY, l.cardDrag.playArea[2], s.border, c.goldBright),
    text('hint', 0, l.cardDrag.lineY + s.xl, l.cardDrag.playArea[2], l.nativeText.lineHeight, '', f.body, c.goldBright),
    // Targeted cards dock below the line and aim with a dotted arc that ends on a reticle.
    ...Array.from({ length: l.cardDrag.aimDots }, (_, i) =>
      ({ ...picture(`aim${i + 1}`, 0, 0, l.cardDrag.aimDot[0], l.cardDrag.aimDot[0], im.diamond, c.goldBright), visible: false })),
    { ...picture('reticle', 0, 0, l.enemyRow.portrait, l.enemyRow.portrait, im.ring, c.goldBright), visible: false },
  ] });
  // Area attacks: one Geo shard band across the enemy row, scaled out from the landing point.
  const row = (l.enemyRow.xFrom + l.enemyRow.xTo) / 2;
  controls.push({ name: 'feedback', kind: 'container', size: [width, height], children: [
    { ...picture('sweep', row, l.enemyRow.y, l.enemyRow.xTo - l.enemyRow.xFrom + l.enemyRow.bossPortrait, s.xl, im.diamond, c.geo), visible: false },
    { name: 'playedCard', kind: 'container', size: l.card.size, visible: false, children: [
      panel('border', 0, 0, ...l.card.size, c.gold),
      panel('plate', 0, 0, l.card.size[0] - s.border * 2, l.card.size[1] - s.border * 2, c.cardType.attack),
      picture('art', 0, s.xl, l.card.art, l.card.art, theme.icon.cardArt.attack, c.goldBright),
      text('name', 0, -s.xxl, l.card.size[0] - s.s, l.nativeText.lineHeight * 2, '', f.cardName, c.text),
    ] },
    { ...panel('bannerPlate', 0, s.xxl, width / 2, l.nativeText.lineHeight * 2, c.panelSunken), visible: false },
    { ...text('banner', 0, s.xxl, width / 2, l.nativeText.lineHeight * 2, '', f.title, c.goldBright), visible: false },
  ] });
  return { name: 'AbyssBattle', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true, controls: [
    { ...panel('backdrop', 0, 0, width, height, c.backdrop), anchor: {min: [0.5, 0.5], max: [0.5, 0.5]} },
    { name: 'stage', kind: 'container', size: [width, height], children: controls },
  ] };
}
