import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

// TASK-4.16: 操作说明按「场景」分三栏扫读（战斗 / 地图与药水 / 顶栏资源），
// 每行先写动作，再写触屏·鼠标做法；手柄另起一行统一说明，避免六宫格信息堆砌。
export const guideSections = [
  { name: 'battle', title: '战斗', rows: [
    ['出牌', '把牌往上拖到目标松手；或点牌再点目标'],
    ['取消', '拖回手牌区松手，或再点一次原牌'],
    ['看详情', '触屏按住 / 鼠标悬停牌或状态'],
    ['结束回合', '点击右下角「结束回合」'],
  ] },
  { name: 'map', title: '地图与药水', rows: [
    ['选路线', '上下拖动地图，点亮起的节点前进'],
    ['看地图', '启程后，菜单里「查看地图」'],
    ['用药水', '点顶栏药水看效果，再选目标使用'],
    ['商店', '先点商品查看详情，再确认购买'],
  ] },
  { name: 'resources', title: '顶栏资源', rows: [
    ['生命', '归零即本局失败，战斗间不会自动回满'],
    ['金币', '在商店购买卡牌、遗物、药水'],
    ['遗物', '常驻被动效果，点图标看说明'],
    ['牌库', '查看本局完整牌组'],
  ] },
];
const iconId = icon => typeof icon === 'object' && icon ? icon.id : icon;
export const guideIcons = theme => [theme.icon.hp, theme.icon.gold, theme.icon.info, theme.icon.deck].map(iconId);

export function controlsGuide(theme = nativeTheme) {
  const { plate, text, button } = nativeControls(theme);
  const l = theme.layout.nativeGuide, { color: c, font: f } = theme;
  const icons = guideIcons(theme);
  const section = (s, i) => ({ name: s.name, kind: 'container', position: [l.columns[i], l.sectionY], size: [...l.sectionSize], children: [
    plate('face', [0, 0, ...l.sectionSize], c.panelSunken),
    text('title', l.sectionTitle, s.title, f.heading, c.goldBright),
    plate('rule', l.sectionRule, c.goldDim),
    ...s.rows.flatMap(([action, how], r) => {
      const y = l.rowTop - r * l.rowStep, iconed = s.name === 'resources' && icons[r] != null;
      return [
        ...(iconed ? [{ name: `icon${r + 1}`, kind: 'image', position: [l.rowIconX, y], size: [l.rowIcon, l.rowIcon], image: icons[r] }] : []),
        text(`action${r + 1}`, [l.actionX, y, l.actionWidth, l.rowHeight], action, f.label, c.goldBright),
        text(`how${r + 1}`, [l.howX, y - l.howDrop, l.howWidth, l.rowHeight], how, f.small, c.text),
      ];
    }),
  ] });
  return { name: 'guide', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
    { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
    plate('border', l.panel, c.goldDim),
    plate('face', [...l.panel.slice(0, 2), ...l.panel.slice(2).map(n => n - theme.space.border * 2)], c.panel),
    { name: 'catch', kind: 'cursorArea', position: l.panel.slice(0, 2), size: l.panel.slice(2), focusable: false },
    text('title', l.title, '操作说明', f.title, c.goldBright),
    ...guideSections.map(section),
    text('pad', l.footer, '手柄：方向键移动焦点 · 确认键操作 · 返回键取消 / 打开菜单', f.label, c.textDim),
    text('dismissHint', l.dismissHint, '点空白处或「返回菜单」关闭', f.small, c.textMuted),
    button('close', l.close, '返回菜单', { inset: [theme.space.s, theme.space.s], border: c.goldDim }),
  ] };
}
