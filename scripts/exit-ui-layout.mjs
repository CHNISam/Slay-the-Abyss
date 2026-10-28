import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

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
  const panel = l.panel;
  return [
    { name: 'exitEntry', kind: 'container', size: [...theme.canvas.base], children: [
      button('open', l.entry, '退出本局'),
    ] },
    { name: 'exitPanel', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
      plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil),
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      plate('border', panel, c.goldDim),
      plate('face', [...panel.slice(0, 2), ...panel.slice(2).map(value => value - s.border * 2)], c.panel),
      text('title', l.title, '退出本局？', f.heading, c.goldBright),
      text('message', l.message, '退出将结束本局，并进入平台结算。\n当前进度不会保留。', f.body, c.text),
      // 局内存档需创作者 4 级；开放前用一行小字如实说明，不打扰玩家。
      { ...text('whyText', l.whyText, '', f.small, c.textMuted), visible: false },
      text('status', l.status, '', f.small, c.textDim),
      button('cancel', l.cancel, '继续游戏'),
      button('confirm', l.confirm, '退出并结算', true),
    ] },
  ];
}
