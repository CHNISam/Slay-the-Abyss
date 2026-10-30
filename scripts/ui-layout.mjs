import { readFileSync } from 'node:fs';
import { cardFaceChildren } from './card-face.mjs';
import { potionSlotVisual } from './potion-slot-visual.mjs';
import { nativeFontSize } from './native-ui-theme.mjs';

// One source of tokens for both the native tree and its Lua controller.
export const theme = JSON.parse(readFileSync(new URL('../data/presentation/ui_theme.json', import.meta.url), 'utf8'));
const { color: c, font: f, image: im, layout: l, space: s } = theme;
const text = (name, x, y, w, h, content = '', fontSize = f.body, colour = c.text) => ({
  name, kind: 'text', position: [x, y], size: [w, h],
  text: { content, fontSize: nativeFontSize(fontSize, f.minimum), colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: nativeFontSize(f.minimum) },
});
const aligned = (control, align = 'left') => ({ ...control, text: { ...control.text, align } });
const picture = (name, x, y, w, h, image, colour = c.text) => ({ name, kind: 'image', position: [x, y], size: [w, h], image, colour });
const panel = (name, x, y, w, h, colour) => picture(name, x, y, w, h, im.rect, colour);
const hit = (w, h) => ({ name: 'hit', kind: 'cursorArea', size: [w, h], focusable: true });
const clickableImage = (image, target) => {
  const { name, position, size } = image;
  return { name, kind: 'container', position, size, children: [
    { ...image, name: 'image', position: [0, 0] }, target,
  ] };
};

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
    ...[-1, 1].flatMap(x => [-1, 1].flatMap(y => [
      { ...panel(`targetH${x}_${y}`, x * portrait / 2, y * portrait / 2, 20, 3, c.goldBright), visible: false },
      { ...panel(`targetV${x}_${y}`, x * portrait / 2, y * portrait / 2, 3, 20, c.goldBright), visible: false },
    ])),
    picture('portrait', 0, 0, portrait - s.l, portrait - s.l,
      player ? (typeof theme.icon.player === 'object' ? theme.icon.player.id : theme.icon.player) : theme.icon.geo,
      player ? c.buttonPressedText : c.geo),
    text('name', 0, -portrait / 2 - s.m, bw, l.nativeText.lineHeight, player ? '旅行者' : '', f.label, c.gold),
    panel('hpBorder', 0, -portrait / 2 - s.xxl - bh / 2, bw + s.border * 2, bh + s.border * 2, c.line),
    panel('hpTrack', 0, -portrait / 2 - s.xxl - bh / 2, bw, bh, c.hpTrack),
    { ...panel('hpGhost', 0, -portrait / 2 - s.xxl - bh / 2, bw, bh, c.hpGhost), mask: true, fill: {shape: 'horizontal', from: 'left', amount: 1} },
    { ...panel('hpFill', 0, -portrait / 2 - s.xxl - bh / 2, bw, bh, c.hp), mask: true, fill: {shape: 'horizontal', from: 'left', amount: 1} },
    text('hp', 0, -portrait / 2 - s.xxl - bh / 2, bw, l.nativeText.lineHeight, '', f.small),
    {...text('damagePreview',0,0,bw,l.nativeText.lineHeight,'',f.label,c.danger),visible:false},
    // Solid chip beside the bar: icon 102014 is half hollow, so digits on it were unreadable.
    panel('blockEdge', -bw / 2 - bb.gap - bb.size / 2, -portrait / 2 - s.xxl - bh / 2, bb.size + s.border * 2, bb.size + s.border * 2, c.panelSunken),
    panel('blockIcon', -bw / 2 - bb.gap - bb.size / 2, -portrait / 2 - s.xxl - bh / 2, bb.size, bb.size, c.block),
    text('block', -bw / 2 - bb.gap - bb.size / 2, -portrait / 2 - s.xxl - bh / 2, bb.size, l.nativeText.lineHeight, '', f.body, c.textOnLight),
    player ? statusRow(-portrait / 2 - s.xxl - bh - s.l) : {name:'statusRow',kind:'container',position:[0,0],size:[bw,l.statusIcon.size],children:[]},
    { ...picture('impact', 0, 0, portrait, portrait, im.diamond, c.geo), visible: false },
    { ...picture('shield', 0, 0, portrait, portrait, theme.icon.block, c.block), visible: false },
    { ...text('floating', 0, portrait / 2, bw + s.xxl, l.nativeText.lineHeight * 2, '', f.number, c.goldBright), visible: false },
    ...(!player ? [picture('intentIcon', -s.xl, l.intent.offsetY, l.intent.size, l.intent.size, theme.icon.intent.unknown, c.textDim),
      // Keep the existing secondary path, with full-sized horizontal peers.
      { ...picture('intentBadge', 0, l.intent.offsetY, l.intent.size, l.intent.size, theme.icon.intent.debuff, c.debuff), visible: false },
      { ...picture('intentExtra', 0, l.intent.offsetY, l.intent.size, l.intent.size, theme.icon.intent.buff, c.buff), visible: false },
      // Attack value (or a two-character kind name) reads left to right from the icon.
      aligned(text('intent', -s.xl + l.intent.size / 2 + s.xs + l.intent.valueWidth / 2, l.intent.offsetY, l.intent.valueWidth, l.nativeText.lineHeight, '', l.intent.numberSize)),
      aligned(text('intentLabel', -s.xl + l.intent.size / 2 + s.xs + l.intent.valueWidth / 2, l.intent.offsetY, l.intent.valueWidth, l.nativeText.lineHeight, '', f.label, c.textDim)),
      { ...hit(l.intent.size * 3, l.intent.size + s.s), name: 'intentHit', position: [0, l.intent.offsetY] }] : []),
    // Tapping a portrait opens that unit's status details (enemies also take targets).
    hit(portrait, portrait),
  ] };
}

export function enemyUnitTemplate(name = 'AbyssMonsterActor') {
  const actor = unit(name, [0, 0], l.enemyRow.crowdPortrait);
  // Original intent effects draw behind the icon, then above it but below damage text.
  for (const [name, before] of [['intentVfxBehind', 'intentIcon'], ['intentVfxAfter', 'intent']]) {
    actor.children.splice(actor.children.findIndex(child => child.name === before), 0,
      {name,kind:'container',position:[0,0],size:[...actor.size],visible:true,children:[]});
  }
  actor.children.find(child => child.name === 'intent').text.valign = 'top';
  return actor;
}

// One native power surface; runtime ports the original ordered, single-row placement.
// No preallocated power count and no wrapping policy belongs in this template.
export function enemyPowerTemplate(name = 'AbyssMonsterPower') {
  const si = l.statusIcon;
  const chip = {name,kind:'container',position:[0,0],size:[si.size,si.size],visible:false,children:[
    {...panel('edge',0,0,si.size+s.hairline*2,si.size+s.hairline*2,c.gold),visible:false},
    {...panel('body',0,0,si.size,si.size,c.panelSunken),visible:false},
    {...picture('icon',0,0,si.size,si.size,theme.icon.status.strength,c.text),visible:false},
    {...picture('badge',0,0,si.size,si.size,im.disc,c.panelSunken),visible:false},
    {...aligned(text('count',si.size/2,-si.size/2+si.gap,si.size,l.nativeText.lineHeight,'',f.small,c.text),'right'),visible:false},
    {...hit(si.minimumTouch,si.minimumTouch),position:[0,0],visible:false},
  ]};
  chip.children.find(child => child.name === 'count').text.valign = 'top';
  return chip;
}

// Status chips under the HP bar: icon with its stack count at the lower right, up to
// perRow x rows. Lua lays them out per column width; the hit opens the detail panel.
function statusRow(top) {
  const si = l.statusIcon, pitch = si.size + si.gap, [bw] = l.hpBar.size, height = si.rows * pitch;
  const icons = [], counts = [], frames = [], badges = [], targets = [];
  for (let i = 0; i < si.perRow * si.rows; i++) {
    const x = (i % si.perRow - (si.perRow - 1) / 2) * pitch, y = (si.rows - 1) * pitch / 2 - Math.floor(i / si.perRow) * pitch;
    frames.push({ ...panel(`edge${i + 1}`, x, y, si.size + s.hairline * 2, si.size + s.hairline * 2, c.gold), visible: false },
      { ...panel(`body${i + 1}`, x, y, si.size, si.size, c.panelSunken), visible: false });
    icons.push({ ...picture(`icon${i + 1}`, x, y, si.size, si.size, theme.icon.status.strength, c.text), visible: false });
    badges.push({ ...picture(`badge${i + 1}`, x, y, si.size, si.size, im.disc, c.panelSunken), visible: false });
    counts.push({ ...text(`count${i + 1}`, x + si.size / 2, y - si.size / 2 + si.gap, si.size, l.nativeText.lineHeight, '', f.small, c.text), visible: false });
    targets.push({ ...hit(si.minimumTouch, si.minimumTouch), name: `hit${i + 1}`, position: [0, 0], visible: false });
  }
  return { name: 'statusRow', kind: 'container', position: [0, top - (si.rows - 1) * pitch / 2], size: [bw, height],
    children: [{ name: 'backplates', kind: 'container', size: [bw, height], children: frames }, ...icons,
      { name: 'countBackplates', kind: 'container', size: [bw, height], children: badges }, ...counts,
      hit(bw, height), ...targets] };
}

// One shared detail card. Its full-stage hit swallows the next tap and closes it; the
// card's own hit turns pages, so every status stays reachable however many there are.
// Lua places every child: left-aligned hierarchy of unit -> HP/Block -> buff/debuff
// sections -> name and stacks (duration on the right) -> effect -> condition.
function statusInfo() {
  const [width, height] = theme.canvas.base, si = l.statusInfo, line = l.nativeText.lineHeight;
  const inner = si.width - si.pad * 2, textWidth = inner - si.icon - si.gap;
  const sections = [], rows = [];
  for (let i = 1; i <= si.sections; i++) {
    sections.push(panel(`sectionMark${i}`, 0, 0, s.xs, f.small, c.buff),
      aligned(text(`section${i}`, 0, 0, inner, line, '', f.small, c.buff)));
  }
  for (let i = 1; i <= si.rows; i++) {
    rows.push(picture(`icon${i}`, 0, 0, si.icon, si.icon, theme.icon.status.strength, c.buff),
      aligned(text(`name${i}`, 0, 0, textWidth, line, '', f.label, c.goldBright)),
      aligned(text(`tag${i}`, 0, 0, si.tagWidth, line, '', f.small, c.textDim), 'right'),
      aligned(text(`text${i}`, 0, 0, textWidth, line, '', f.small, c.text)),
      aligned(text(`note${i}`, 0, 0, textWidth, line, '', f.small, c.textDim)));
  }
  return { name: 'statusInfo', kind: 'container', size: [width, height], visible: false, children: [
    { ...hit(width, height), focusable: false },
    // Native image colours are RGB with a separate opacity (see native-ui-theme).
    { ...panel('shadow', 0, 0, si.width, si.width, c.backdropVeil.slice(0, 7)), opacity: parseInt(c.backdropVeil.slice(7), 16) / 255 },
    panel('border', 0, 0, si.width + s.border * 2, si.width + s.border * 2, c.goldDim),
    panel('plate', 0, 0, si.width, si.width, c.panelSunken),
    panel('accent', 0, 0, si.width, si.accent, c.gold),
    aligned(text('title', 0, 0, inner - si.tagWidth, line, '', f.body, c.goldBright)),
    aligned(text('tag', 0, 0, si.tagWidth, line, '', f.small, c.textDim), 'right'),
    picture('hpIcon', 0, 0, f.label, f.label, theme.icon.hp, c.hp),
    aligned(text('summary', 0, 0, inner, line, '', f.label, c.text)),
    picture('blockIcon', 0, 0, f.label, f.label, theme.icon.block, c.block),
    aligned(text('guard', 0, 0, inner / 2, line, '', f.label, c.block)),
    panel('rule', 0, 0, inner, s.hairline, c.line),
    ...sections,
    ...rows,
    text('more', 0, 0, inner, line, '', f.small, c.textDim),
    { ...hit(si.width, si.width), name: 'page' },
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
    const left = Math.max(-width / 2 + theme.canvas.safe.x,
      Math.min(x - l.drawPile.size[0] / 2, bx - b.disc / 2, x + b.label[0] - b.label[2] / 2));
    const right = Math.min(width / 2 - theme.canvas.safe.x,
      Math.max(x + l.drawPile.size[0] / 2, bx + b.disc / 2, x + b.label[0] + b.label[2] / 2));
    const bottom = Math.max(-height / 2 + theme.canvas.safe.y,
      Math.min(py - l.drawPile.size[1] / 2, by - b.disc / 2, py + b.label[1] - b.label[3] / 2));
    const top = Math.min(height / 2 - theme.canvas.safe.y,
      Math.max(py + l.drawPile.size[1] / 2, by + b.disc / 2, py + b.label[1] + b.label[3] / 2));
    return [
      clickableImage(picture(`${name}Icon`, x, py, ...l.drawPile.size, icon, c.textDim),
        { ...hit(right - left, top - bottom), position: [(left + right) / 2 - x, (bottom + top) / 2 - py] },
      ),
      picture(`${name}BadgeRing`, bx, by, b.disc, b.disc, im.disc, c.goldDim),
      picture(`${name}Badge`, bx, by, b.disc - s.border * 2, b.disc - s.border * 2, im.disc, c.panelSunken),
      text(name, bx, by, b.disc, l.nativeText.lineHeight, '', f.label, c.goldBright),
      text(`${name}Label`, x + b.label[0], py + b.label[1], b.label[2], b.label[3], caption, f.small, c.textDim),
    ];
  };
  const controls = [
    // Behind actors and hand: a distinct C-mode confirmation surface on open ground.
    { name: 'playArea', kind: 'container', position: l.cardDrag.playArea.slice(0, 2), size: l.cardDrag.playArea.slice(2), visible: false, children: [
      panel('line', 0, -l.cardDrag.playArea[3] / 2, l.cardDrag.playArea[2], s.border, c.goldBright),
      text('label', 0, -l.cardDrag.playArea[3] / 2 + s.xl, l.cardDrag.playArea[2], l.nativeText.lineHeight, '出牌区域 · 点击出牌', f.body, c.goldBright),
      hit(...l.cardDrag.playArea.slice(2)),
    ] },
    {name: 'topBar', kind: 'container', position: [0,y], size: [width,bar.height], children: [
      panel('steel',0,0,width,bar.height,c.panelSunken),
      panel('edge',0,-bar.height/2,width-80,1,c.goldDim),
      panel('leftRule',-156,0,32,1,c.gold), panel('rightRule',156,0,32,1,c.gold),
    ]},
    // Post-battle card pick: a framed stage that separates reward choosing from playing the hand.
    { name: 'rewardStage', kind: 'container', position: l.rewardPick.stage.slice(0, 2), size: l.rewardPick.stage.slice(2), visible: false, children: [
      panel('border', 0, 0, ...l.rewardPick.stage.slice(2), c.goldDim),
      panel('plate', 0, 0, l.rewardPick.stage[2] - s.border * 2, l.rewardPick.stage[3] - s.border * 2, c.panelSunken),
      text('title', l.rewardPick.title[0] - l.rewardPick.stage[0], l.rewardPick.title[1] - l.rewardPick.stage[1], l.rewardPick.title[2], l.rewardPick.title[3], '选择一张卡牌', f.display, c.goldBright),
      text('subtitle', l.rewardPick.subtitle[0] - l.rewardPick.stage[0], l.rewardPick.subtitle[1] - l.rewardPick.stage[1], l.rewardPick.subtitle[2], l.rewardPick.subtitle[3], '', f.body, c.textDim),
    ] },
    { name: 'rewardList', kind: 'container', position: l.battleRewards.stage.slice(0, 2), size: l.battleRewards.stage.slice(2), visible: false, children: [
      panel('border', 0, 0, ...l.battleRewards.stage.slice(2), c.goldDim),
      panel('plate', 0, 0, l.battleRewards.stage[2] - s.border * 2, l.battleRewards.stage[3] - s.border * 2, c.panelSunken),
      ...['title', 'subtitle'].map(name => text(name,
        l.battleRewards[name][0] - l.battleRewards.stage[0], l.battleRewards[name][1] - l.battleRewards.stage[1],
        ...l.battleRewards[name].slice(2), name === 'title' ? '战斗奖励' : '', name === 'title' ? f.display : f.body,
        name === 'title' ? c.goldBright : c.textDim)),
    ] },
    text('title', 0, y, 350, bar.height, '战斗', f.heading, c.gold),
    glyph('hpIcon', bar.hpIcon, theme.icon.hp, c.hp), chip('player', bar.hp),
    glyph('goldIcon', bar.goldIcon, theme.icon.gold, c.text), chip('piles', bar.gold, c.goldBright),
    clickableImage(glyph('exhaustIcon', bar.exhaustIcon, theme.icon.exhaust, c.textDim),
      { ...hit(bar.exhaust[0] + bar.exhaust[1] / 2 - bar.exhaustIcon[0] + bar.exhaustIcon[1] / 2, Math.max(44,bar.height)),
        position: [(bar.exhaust[0] + bar.exhaust[1] / 2 - bar.exhaustIcon[0] - bar.exhaustIcon[1] / 2) / 2,
          Math.min(0,height/2-theme.canvas.safe.y-y-Math.max(44,bar.height)/2)] },
    ), chip('exhaust', bar.exhaust, c.textDim),
    unit('hero', l.player.position, l.player.portrait, true),
    text('notice', ...l.battleNotice.position, ...l.battleNotice.size, '', f.body, c.goldBright),
    text('statuses', -380, 194, 350, 26, '', f.small, c.textDim),
    // Main 138–144: warm circular shell, inset amber face and white shadowed value.
    // Existing soft-disc material approximates, but does not reproduce, the CSS gradient.
    picture('energyRing', ...l.energy.position, l.energy.size, l.energy.size, im.disc, l.energy.rimColour),
    picture('energyDisc', ...l.energy.position, l.energy.size-l.energy.rim*2, l.energy.size-l.energy.rim*2, im.disc, l.energy.shellColour),
    {name:'energyIcon',kind:'container',position:l.energy.position,size:[l.energy.size,l.energy.size],children:[
      picture('face',0,0,l.energy.size-l.energy.faceInset*2,l.energy.size-l.energy.faceInset*2,im.disc,l.energy.faceColour),
      picture('light',0,0,l.energy.size-l.energy.faceInset*2,l.energy.size-l.energy.faceInset*2,im.discSoft,l.energy.lightColour),
      picture('core',0,0,l.energy.size-l.energy.elementInset*2,l.energy.size-l.energy.elementInset*2,theme.icon.energy.id,l.energy.elementColour),
      text('valueShadow',...l.energy.shadowOffset,l.energy.size,l.energy.size,'0/0',l.energy.numberSize,l.energy.shadowColour),
    ]},
    text('energy', ...l.energy.position, l.energy.size, l.energy.size, '0/0', l.energy.numberSize, l.energy.numberColour),
    ...pile('draw', theme.icon.drawPile, l.drawPile.position, '抽牌堆', 1),
    ...pile('discard', theme.icon.discardPile, l.discardPile.position, '弃牌堆', -1),
  ];
  const potionHelp = [];
  for (let i = 0; i < l.battlePotions.count; i++) {
    const potion = button(`potion${i + 1}`, l.battlePotions.origin.map((n, axis) => n + l.battlePotions.step[axis] * i),
      l.battlePotions.size, '空药水槽', false, f.small);
    // Main top-bar silhouettes: official bottle, not a second row of text buttons.
    for (const state of potion.children) {
      const label=state.children.find(c=>c.name==='label');label.visible=false;
      state.children=[...potionSlotVisual(theme,{border:state.children[0],plate:state.children[1],
        bottleSize:l.battlePotions.bottleSize,ink:c.goldBright}),label];
    }
    // Keep the original three direct paths. Extra bottles share the existing
    // full-canvas help group so the battle parent stays at 60 direct children.
    if (i < 3) controls.push(potion);
    else { potion.visible = false; potionHelp.push(potion); }
    const help = button(`potionHelp${i + 1}`, l.battlePotions.origin.map((n, axis) => n + l.battlePotions.step[axis] * i + l.battlePotions.helpOffset[axis]),
      l.battlePotions.helpSize, '说明', false, f.small);
    for(const state of help.children) {
      state.children[0].image=im.disc;
      state.children[1].image=im.disc;
      state.children.push(picture('bottle',0,0,28,28,theme.icon.potion.fire_potion,c.goldBright));
    }
    for (const state of help.children) state.children.find(c => c.name === 'label').size = [l.battlePotions.helpSize[0] - s.s, l.nativeText.lineHeight];
    help.visible = false;
    potionHelp.push(help);
  }
  const pop=l.potionPopup, ph=pop.minimumHeight;
  const potionAction=(name,width,label,primary)=>{
    const action=button(name,[0,0],[width,pop.actionHeight],label,primary,pop.font);
    for(const state of action.children)state.children.find(c=>c.name==='label').size[1]=l.nativeText.lineHeight;
    return action;
  };
  potionHelp.push({name:'potionPopup',kind:'container',position:[l.battlePotions.origin[0],pop.top-ph/2],
    size:[pop.width,ph],visible:false,children:[
      {...hit(...theme.canvas.base),name:'dismiss',position:[-l.battlePotions.origin[0],-(pop.top-ph/2)]},
      panel('border',0,0,pop.width,ph,c.goldDim),panel('plate',0,0,pop.width-2,ph-2,c.panelSunken),
      hit(pop.width,ph),
      aligned(text('title',0,0,pop.width-pop.padding*2,l.nativeText.lineHeight,'',pop.font,c.goldBright)),
      aligned(text('target',0,0,pop.targetWidth,l.nativeText.lineHeight,'',pop.font,c.textDim),'right'),
      aligned(text('effect',0,0,pop.width-pop.padding*2,l.nativeText.lineHeight,'',pop.font,c.text)),
      potionAction('use',120,'使用',true),
      potionAction('discard',64,'丢弃',false),
    ]});
  // Keep potion explanations in the existing full-canvas group. This avoids
  // exceeding the platform's 60 direct children when rewards and aiming coexist.
  for (let i = 1; i <= 2; i++) {
    const relic = button(`relicReward${i}`, l.battleRewards.rowOrigin, l.battleRewards.rowSize, '遗物', false, f.body);
    relic.visible = false;
    potionHelp.push(relic);
  }
  const emerald = button('emeraldKeyReward', l.battleRewards.rowOrigin, l.battleRewards.rowSize, '领取绿钥匙', false, f.body);
  emerald.visible = false;
  potionHelp.push(emerald);
  potionHelp.push(text('potionReward', ...l.battleRewards.potionLabel, '', f.body, c.goldBright));
  controls.push({name: 'potionHelp', kind: 'container', size: [width, height], children: potionHelp});
  // Actors are instantiated per creature identity; no fixed five-instance ceiling.
  controls.push({name:'actorLayer',kind:'container',position:[0,0],size:[width,height],children:[]});
  for (let i = 1; i <= 10; i++) {
    const [w, h] = l.card.size;
    controls.push({ name: `card${i}`, kind: 'container', size: [w, h], ...handPose(10, i - 1),
      children: cardFaceChildren(theme, 'battle') });
  }
  const turn=l.endTurn;
  const turnButton=button('endTurn',turn.position,turn.size,'结束回合',false,turn.numberSize);
  const hex=(name,w,h,colour)=>[
    panel(name,0,0,w-turn.wedge*2,h,colour),
    ...[-1,1].map(side=>({...picture(name+(side<0?'Left':'Right'),side*(w/2-turn.wedge/2),0,h,turn.wedge,100003,colour),rotation:side<0?90:-90})),
  ];
  for(const state of turnButton.children) {
    const label=state.children.find(c=>c.name==='label');
    label.text.colour=turn.textColour;
    state.children=[
      ...hex('border',...turn.size,turn.rimColour),
      ...hex('inner',turn.size[0]-turn.innerInset[0]*2,turn.size[1]-turn.innerInset[1]*2,turn.innerColour),
      ...hex('plate',turn.size[0]-turn.faceInset[0]*2,turn.size[1]-turn.faceInset[1]*2,turn.faceColour),
      label,
    ];
  }
  controls.push(turnButton,
    button('start', [0, -96], l.button.primary, '启程', true),
    button('continue', l.battleRewards.continue.slice(0, 2), l.battleRewards.continue.slice(2), '前往地图', true),
    panel('resultPlate', 0, 80, 800, 130, c.panelSunken),
    text('result', 0, 80, 780, 122, '', f.title, c.goldBright),
    button('skip', l.rewardPick.skip.slice(0, 2), l.rewardPick.skip.slice(2), '跳过卡牌'),
    button('goldReward', l.battleRewards.rowOrigin, l.battleRewards.rowSize, '金币', false, f.body),
    button('cardReward', l.battleRewards.rowOrigin, l.battleRewards.rowSize, '选择一张卡牌加入牌组', false, f.body),
    button('claimPotion', l.battleRewards.claimPotion, l.battleRewards.rowSize, '领取药水', false, f.body),
    button('stolenGold', l.battleRewards.rowOrigin, l.battleRewards.rowSize, '取回失金', false, f.body));
  controls.push({ name: 'dragLayer', kind: 'container', size: [width, height], visible: false, children: [
    { ...hit(width, height), focusable: false },
    panel('line', l.cardDrag.playArea[0], l.cardDrag.lineY, l.cardDrag.playArea[2], s.border, c.goldBright),
    text('hint', 0, l.cardDrag.lineY + s.xl, l.cardDrag.playArea[2], l.nativeText.lineHeight, '', f.body, c.goldBright),
    // Targeted cards dock below the line and aim with a dotted arc that ends on a reticle.
    ...Array.from({ length: l.cardDrag.aimDots }, (_, i) =>
      ({ ...picture(`aim${i + 1}`, 0, 0, l.cardDrag.aimDot[0], l.cardDrag.aimDot[0], im.diamond, c.goldBright), visible: false })),
    { ...picture('reticle', 0, 0, l.enemyRow.portrait, l.enemyRow.portrait, im.ring, c.goldBright), visible: false },
  ] });
  controls.push(statusInfo());
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
    // Ten fixed lightweight trails cover a full hand without allocating controls during play.
    ...Array.from({length: 10}, (_, i) => ({name: `cardTrail${i + 1}`, kind: 'container',
      size: l.card.size, visible: false, children: [
        panel('plate', 0, 0, ...l.card.size, c.cardType.attack),
        picture('art', 0, s.xl, l.card.art, l.card.art, theme.icon.cardArt.attack, c.goldBright),
        text('name', 0, -s.xxl, l.card.size[0] - s.s, l.nativeText.lineHeight * 2, '', f.cardName, c.text),
      ]})),
    { ...panel('deathShade', 0, 0, width, height, c.backdrop), visible: false },
    { ...panel('bannerPlate', 0, s.xxl, width / 2, l.nativeText.lineHeight * 2, c.panelSunken), visible: false },
    { ...text('banner', 0, s.xxl, width / 2, l.nativeText.lineHeight * 2, '', f.title, c.goldBright), visible: false },
  ] });
  return { name: 'AbyssBattle', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true, controls: [
    { ...panel('backdrop', 0, 0, width, height, c.backdrop), anchor: {min: [0.5, 0.5], max: [0.5, 0.5]} },
    { name: 'stage', kind: 'container', size: [width, height], children: controls },
  ] };
}
