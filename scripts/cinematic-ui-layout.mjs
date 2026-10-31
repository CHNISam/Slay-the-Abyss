import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

// Presentation-only controls for the title vista, the opening cinematic and the
// shop merchant. Every picture is a tinted shape from the platform picture library;
// Lua moves, scales and recolours them and never reads rules from here.
function helpers(theme) {
  const controls = nativeControls(theme);
  const picture = (name, values, image, colour, extra = {}) => ({ name, kind: 'image',
    position: values.slice(0, 2), size: values.slice(2, 4), image, colour, ...extra });
  // Typed lines grow from a fixed left edge instead of re-centring every character.
  const leftText = (name, values, content, fontSize, colour, valign = 'middle') => {
    const control = controls.text(name, values, content, fontSize, colour);
    return { ...control, text: { ...control.text, align: 'left', valign } };
  };
  return { ...controls, picture, leftText };
}

export function vistaControl(theme = nativeTheme, name = 'vista') {
  const { picture, plate } = helpers(theme);
  const v = theme.layout.vista, c = theme.color, im = theme.image, tone = c.vista;
  const [sx, sy] = v.seal, centre = [0, 0];
  const seal = { name: 'seal', kind: 'container', position: [sx, sy], size: v.seal.slice(2), children: [
    picture('core', [...centre, v.seal[2] * 0.9, v.seal[3] * 0.9], im.glow, c.goldBright, { opacity: 0.55 }),
    picture('ring', [...centre, ...v.seal.slice(2)], im.ring, c.gold, { opacity: 0.8 }),
    picture('heart', [...centre, ...v.sealCore.slice(2)], im.disc, c.goldBright),
  ] };
  return { name, kind: 'container', size: v.cover.slice(2), children: [
    plate('sky', v.cover, tone.sky),
    picture('halo', v.halo, im.glowWide, c.geoDeep, { opacity: 0.32 }),
    ...v.beams.map((frame, i) => picture(`beam${i + 1}`, frame, im.beam, c.goldDim, { opacity: 0.16 })),
    picture('towerBack', v.towerBack, im.ruin, tone.far),
    picture('tower', v.tower, im.ruin, tone.mid),
    seal,
    ...v.shards.map((frame, i) => picture(`shard${i + 1}`, frame, im.shards, c.goldDim)),
    ...v.pillars.map((frame, i) => picture(`pillar${i + 1}`, frame, im.ruin, tone.near)),
    picture('wall', v.wall, im.ruinWall, tone.near),
    plate('ground', v.ground, tone.ground),
    picture('horizon', v.horizon, im.fadeLine, c.geoDeep, { opacity: 0.45 }),
    ...v.motes.map((at, i) => picture(`mote${i + 1}`, [...at, v.mote, v.mote], im.disc, c.goldBright)),
    picture('vignette', v.vignette, im.vignette, tone.shade, { opacity: 0.85 }),
  ] };
}

export function prologueControl(theme = nativeTheme) {
  const { picture, plate, text, leftText, button } = helpers(theme);
  const p = theme.layout.prologue, c = theme.color, im = theme.image, f = theme.font;
  const cover = theme.layout.vista.cover, [, , cw] = cover, half = theme.canvas.base[1] / 2;
  const [hx, hy, hw, hh] = p.hero;
  const hero = { name: 'hero', kind: 'container', position: [hx, hy], size: [hw, hh], visible: false, children: [
    picture('glow', [0, 0, p.heroGlow, p.heroGlow], im.glow, c.geo),
    picture('disc', [0, 0, hw, hh], im.disc, c.panelSunken),
    picture('ring', [0, 0, hw + theme.space.s, hh + theme.space.s], im.ring, c.gold),
    picture('icon', [0, 0, hw * 0.62, hh * 0.62], theme.icon.geo, c.geo),
  ] };
  const dots = [0, 1, 2].map(i => picture(`dot${i + 1}`, [(i - 1) * p.dots.step, p.dots.y, p.dots.size, p.dots.size], im.disc, c.goldDim));
  // The camera moves the vista; its vignette stays fixed to the screen instead.
  const vista = vistaControl(theme), vignette = vista.children.find(child => child.name === 'vignette');
  vista.children = vista.children.filter(child => child !== vignette);
  return { name: 'prologuePanel', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
    vista,
    vignette,
    hero,
    { ...plate('flash', cover, c.goldBright), visible: false },
    plate('barTop', [0, half - p.barHeight / 2, cw, p.barHeight], c.vista.shade),
    plate('barBottom', [0, -half + p.barHeight / 2, cw, p.barHeight], c.vista.shade),
    leftText('chapter', p.chapter, '', f.label, c.goldDim),
    leftText('line', p.line, '', f.title, c.text),
    ...dots,
    text('hint', p.hint, '点击继续', f.small, c.textMuted),
    { name: 'advance', kind: 'cursorArea', size: cover.slice(2), focusable: true },
    button('skip', p.skip, '跳过', { inset: theme.layout.nativeNode.buttonInset, fontSize: f.label,
      colour: c.goldBright, fill: c.panelSunken, border: c.goldDim }),
    plate('fade', cover, c.vista.shade),
  ] };
}

export function merchantControl(theme = nativeTheme) {
  // 移植 STS ShopScreen/Merchant/ShopSpeechBubble 的商人演出：站在毯子上的商人立像 +
  // 在他身旁随机左右翻转弹出的对白气泡（4s、0.3s 弹入/淡出、上下浮动、投影，点按提前收起）。
  const { picture, plate, text, leftText, hit } = helpers(theme);
  const m = theme.layout.merchant, c = theme.color, im = theme.image, tone = c.merchant;
  const [ox, oy] = m.frame, at = ([x, y, ...rest]) => [x - ox, y - oy, ...rest];
  const [fx, fy, fw, fh] = at(m.figure), [bw, bh] = m.bubble, t = m.tail;
  const portrait = { name: 'portrait', kind: 'container', position: [fx, fy], size: [fw, fh], children: [
    picture('aura', [0, 0, fw * 1.3, fh * 1.3], im.glow, c.geoDeep, { opacity: 0.3 }),
    picture('lanternGlow', [-fw * 0.34, -fh * 0.3, fw * 0.45, fw * 0.45], im.glow, tone.lantern, { opacity: 0.45 }),
    picture('bust', [0, 0, fw, fh], im.merchant, '#FFFFFF'),
  ] };
  const bubble = { name: 'bubble', kind: 'container', position: [fx + m.anchor[0] + m.adjust[0], fy + m.anchor[1] + m.adjust[1]], size: [bw, bh], visible: false, children: [
    { ...plate('shadow', [m.shadow, -m.shadow, bw, bh], tone.hood), opacity: 0.25 },
    plate('border', [0, 0, bw, bh], c.goldDim),
    { ...plate('panel', [0, 0, bw - 4, bh - 4], c.parchment), opacity: 0.97 },
    picture('tail', [t[0], t[1], t[2], t[2]], im.diamond, c.parchment),
    leftText('line', [0, 0, bw - theme.space.xl * 2, bh - theme.space.l], '', theme.font.body, c.panelSunken),
    picture('next', [bw / 2 - 14, -bh / 2 + 12, 12, 12], im.diamond, c.goldDim),
    // 点按气泡＝STS 悬停气泡：剩余时长缩到淡出时间；不承担任何商店操作。
    { name: 'talk', kind: 'container', position: [0, 0], size: [bw, bh], children: [hit([bw, bh])] },
  ] };
  return { name: 'merchant', kind: 'container', position: [ox, oy], size: m.frame.slice(2), visible: false, children: [
    // 去掉立像下的毯板（看似“木板上的断头”）；保留半身像本身不变。
    portrait,
    // 名牌置于立像右侧空地（毯外、价签下方），不压身体、货架与价签；STS 原版无名牌。
    { ...plate('nameplate', [at(m.name)[0], at(m.name)[1], 80, 22], tone.hood), opacity: 0.85 },
    text('name', at(m.name), '旧路商人', theme.font.small, c.goldBright),
    bubble,
  ] };
}
