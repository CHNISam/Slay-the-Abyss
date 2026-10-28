import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

// Controls.dc.html's six instruction tiles, with copy limited to shipped inputs.
export function controlsGuide(theme = nativeTheme) {
  const { plate, text, button } = nativeControls(theme);
  const l = theme.layout.nativeGuide, { color: c, font: f } = theme;
  const icons = [theme.icon.node.combat, theme.icon.back, theme.icon.info,
    theme.icon.potion.fire_potion, theme.icon.map, theme.icon.confirm];
  const tips = [
    ['出牌', '拖牌到合法目标松手。\n也可点选卡牌，再点目标\n或出牌区确认。'],
    ['取消', '拖回手牌区松手，\n或再次点选原牌取消。'],
    ['看详情', '鼠标悬停、触屏按住\n查看牌和状态说明。\n牌库可查看完整牌组。'],
    ['用药水', '点顶栏药水查看效果。\n选定合法目标后使用；\n取消不会消耗药水。'],
    ['地图', '鼠标或触屏上下拖动。\n手柄用方向选择节点，\n箭头翻看，◆回到当前位置。'],
    ['手柄与回合', '方向移动焦点，确认操作，\n返回键取消或打开菜单。\n出牌后选择「结束回合」。'],
  ];
  return { name: 'guide', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
    plate('border', l.panel, c.goldDim),
    plate('face', [...l.panel.slice(0, 2), ...l.panel.slice(2).map(n => n - theme.space.border * 2)], c.panel),
    text('title', l.title, '操作说明', f.title, c.goldBright),
    ...tips.map(([title, body], i) => ({ name: `tip${i + 1}`, kind: 'container',
      position: [l.columns[i % 3], l.rows[Math.floor(i / 3)]], size: [...l.tileSize], children: [
        plate('face', [0, 0, ...l.tileSize], c.panelSunken),
        { name: 'icon', kind: 'image', position: l.tileIcon.slice(0, 2), size: l.tileIcon.slice(2),
          image: icons[i], colour: c.goldBright },
        text('title', l.tileTitle, title, f.heading, c.goldBright),
        text('body', l.tileBody, body, f.label, c.textDim),
      ] })),
    text('footer', l.footer, '触屏先选商品，再确认购买；鼠标可悬停查看，点击购买。', f.label, c.textDim),
    button('close', l.close, '返回菜单', { inset: [theme.space.s, theme.space.s], border: c.goldDim }),
  ] };
}
