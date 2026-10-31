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

// Old-road merchant medallion (hooded elder + lantern); also reused as the Neow stand-in figure.
export function merchantPortrait(theme = nativeTheme, [px, py, pw, ph], name = 'portrait') {
  const { picture } = helpers(theme);
  const c = theme.color, im = theme.image, tone = c.merchant, b = theme.space.border;
  const r = pw / 2;
  // A hooded, bearded elder built from tinted discs and diamonds, kept inside the medallion.
  const portrait = { name, kind: 'container', position: [px, py], size: [pw, ph], children: [
    picture('aura', [0, 0, pw * 1.5, ph * 1.5], im.glow, c.geoDeep, { opacity: 0.5 }),
    picture('rim', [0, 0, pw + b * 2, ph + b * 2], im.disc, c.gold),
    picture('field', [0, 0, pw, ph], im.disc, c.vista.mid),
    picture('lanternGlow', [-r * 0.5, -r * 0.42, r * 1.1, r * 1.1], im.glow, tone.lantern, { opacity: 0.45 }),
    picture('robe', [0, -r * 0.6, r * 1.6, r * 0.8], im.disc, tone.robe),
    picture('hoodTip', [0, r * 0.5, r * 0.78, r * 0.86], im.diamond, tone.hood),
    picture('hood', [0, r * 0.1, r * 1.0, r * 1.08], im.disc, tone.hood),
    picture('face', [0, r * 0.02, r * 0.56, r * 0.52], im.disc, tone.face),
    picture('beard', [0, -r * 0.34, r * 0.5, r * 0.7], im.diamond, tone.beard),
    picture('eyeLeft', [-r * 0.12, r * 0.08, r * 0.1, r * 0.06], im.disc, c.goldBright),
    picture('eyeRight', [r * 0.12, r * 0.08, r * 0.1, r * 0.06], im.disc, c.goldBright),
    picture('lantern', [-r * 0.5, -r * 0.46, r * 0.2, r * 0.24], im.disc, tone.lantern),
  ] };
  return portrait;
}

export function merchantControl(theme = nativeTheme) {
  const { picture, plate, text, leftText, hit } = helpers(theme);
  const m = theme.layout.merchant, c = theme.color, im = theme.image, tone = c.merchant, b = theme.space.border;
  const [bx, by, bw, bh] = m.box, [px, py, pw, ph] = m.portrait;
  const portrait = merchantPortrait(theme, [px, py, pw, ph]);
  // Theme frames are in node-panel units; children sit relative to the merchant's own frame.
  const [fx, fy] = m.frame, at = ([x, y, ...rest]) => [x - fx, y - fy, ...rest];
  portrait.position = at(m.portrait).slice(0, 2);
  const [nx, ny, nw] = at(m.name), line = theme.layout.nativeText.lineHeight;
  return { name: 'merchant', kind: 'container', position: [fx, fy], size: m.frame.slice(2), visible: false, children: [
    plate('border', at([bx, by, bw + b * 2, bh + b * 2]), c.goldDim),
    { ...plate('panel', at(m.box), c.panelSunken), opacity: 0.96 },
    plate('accent', at([bx + pw / 2, by + bh / 2 - b, bw - pw - theme.space.xl, b]), c.gold),
    portrait,
    plate('namePlate', at(m.name), c.goldDim),
    text('name', [nx, ny, nw - theme.space.s, line], '旧路商人', theme.font.label, c.parchment),
    leftText('line', at(m.line), '', theme.font.body, c.text, 'top'),
    picture('next', at(m.next), im.diamond, c.gold),
    // Tapping the dialogue only reveals or advances text; it owns no shop action.
    { name: 'talk', kind: 'container', position: at(m.box).slice(0, 2), size: m.box.slice(2), children: [hit(m.box.slice(2))] },
  ] };
}
