import { nativeControls, nativeTheme } from './native-ui-theme.mjs';
import { controlsGuide } from './controls-guide-layout.mjs';

export function exitControls(theme = nativeTheme) {
  const { plate, text } = nativeControls(theme);
  const { color: c, font: f, space: s } = theme, l = theme.layout.exitMenu;
  // Native presets keep all four states visible on mouse, touch and controller.
  const button = (name, frame, label, primary = false) => {
    const size = frame.slice(2);
    const variants = {
      normal: [primary ? c.gold : c.panelRaised, primary ? c.textOnLight : c.goldBright, c.gold],
      hover: [primary ? c.goldBright : c.buttonHover, primary ? c.textOnLight : c.goldBright, c.goldBright],
      pressed: [c.goldDim, c.buttonPressedText, c.goldBright], disabled: [c.panelSunken, c.textMuted, c.line],
    };
    return { name, kind: 'container', position: frame.slice(0, 2), size, children: [
      { name: 'hit', kind: 'presetButton', size: [...size], focusable: true,
        states: Object.fromEntries(Object.keys(variants).map(state => [state, state])),
        children: Object.entries(variants).map(([state, [fill, ink, border]]) => ({
          name: state, kind: 'container', size: [...size],
          scale: state === 'pressed' ? [l.pressedScale, l.pressedScale] : [1, 1], children: [
            plate('border', [0, 0, ...size], border),
            plate('plate', [0, 0, ...size.map(value => value - s.border * 2)], fill),
            text('label', [0, 0, ...size.map((value, i) => value - l.buttonInset[i])], label, f.label, ink),
          ],
        })),
      },
    ] };
  };
  // Map.dc.html/Main.dc.html: a small dark circular menu with three short
  // strokes (M4 7h16 / M4 12h16 / M4 17h16). Reuse native disc/rect images;
  // the 48px native hit remains larger than the 36px artwork for touch/focus.
  const entry = button('open', l.entry, '菜单'), v = l.entryVisual;
  const entryPalettes = { normal: c.mapHeader.menuNormal, hover: c.mapHeader.menuHover,
    pressed: c.mapHeader.menuPressed, disabled: { fill: c.panelSunken, ink: c.textMuted, border: c.line } };
  for (const variant of entry.children[0].children) {
    const palette = entryPalettes[variant.name];
    const [border, face, label] = variant.children;
    border.image = face.image = theme.image.disc;
    border.size = [v.diameter, v.diameter]; border.colour = palette.border;
    face.size = [v.diameter - v.border * 2, v.diameter - v.border * 2]; face.colour = palette.fill;
    label.visible = false;
    for (let i = 0; i < 3; i++) variant.children.push(
      plate(`menuStroke${i + 1}`, [0, (1 - i) * v.lineStep, v.lineWidth, v.lineHeight], palette.ink));
  }
  const panel = l.panel, menu = theme.layout.runMenu;
  return [
    { name: 'exitEntry', kind: 'container', size: [...theme.canvas.base], children: [
      entry,
    ] },
    { name: 'exitPanel', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
      plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil),
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      plate('border', panel, c.goldDim),
      plate('face', [...panel.slice(0, 2), ...panel.slice(2).map(value => value - s.border * 2)], c.panel),
      // TASK-4.11: header row = title (left) + 操作说明 (right); a gold rule separates it
      // from the consequence body so no secondary control can sit on the warning text.
      text('title', l.title, '退出本局？', f.heading, c.goldBright),
      plate('rule', l.rule, c.goldDim),
      text('message', l.message, '退出将结束本局，并进入平台结算。\n当前进度不会保留。', f.body, c.text),
      // 局内存档需创作者 4 级；开放前用一行小字如实说明，不打扰玩家。
      { ...text('whyText', l.whyText, '', f.small, c.textMuted), visible: false },
      text('status', l.status, '', f.small, c.textDim),
      button('cancel', l.cancel, '继续游戏'),
      button('confirm', l.confirm, '退出并结算', true),
      button('help', l.help, '操作说明'),
      controlsGuide(theme),
    ] },
    { name: 'runMenu', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
      plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil),
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      plate('border', menu.panel, c.goldDim),
      plate('face', [...menu.panel.slice(0, 2), ...menu.panel.slice(2).map(value => value - s.border * 2)], c.panel),
      // TASK-4.16: 面板自身吞点击，只有面板外的空白（blocker）才关闭菜单。
      { name: 'catch', kind: 'cursorArea', position: menu.panel.slice(0, 2), size: menu.panel.slice(2), focusable: false },
      // 层级：标题 → 主操作「继续游戏」→ 次要查看 → 分隔线 → 破坏性「放弃本局」。
      text('title', menu.title, '暂停', f.heading, c.goldBright),
      button('resume', menu.resume, '继续游戏', true),
      button('help', menu.help, '操作说明'),
      // 未启程时整颗隐藏，不留灰色空头承诺；启程后出现并可进入。
      button('map', menu.map, '查看地图'),
      plate('rule', menu.rule, c.goldDim),
      button('abandon', menu.abandon, '放弃本局'),
      text('dismissHint', menu.dismissHint, '点空白处继续游戏', f.small, c.textMuted),
    ] },
  ];
}
