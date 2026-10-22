import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

// Point-selection fallback, separate from the approved fan-hand composition.
export function battleLayout(theme = nativeTheme) {
  const { text, plate, hit, button, centred } = nativeControls(theme);
  const layout = theme.layout.nativeBattle, { color, font } = theme;
  const controls = [plate('backdrop', layout.backdrop, color.backdrop),
    text('title', layout.title, '杀戮深渊 · 旅行者', font.title, color.gold),
    text('player', layout.player), text('piles', layout.piles),
    text('notice', layout.notice, '先选择敌人，再点击手牌；结束回合后敌人按意图行动。'),
    text('statuses', layout.statuses, '', font.cardName),
  ];
  for (let i = 0; i < layout.enemy.count; i++) {
    const enemy = layout.enemy;
    controls.push({ name: `enemy${i + 1}`, kind: 'container',
      position: enemy.origin.map((value, axis) => value + i * enemy.step[axis]), size: [...enemy.size], children: [
        plate('plate', centred(enemy.size)), text('label', centred(enemy.labelSize)), hit(enemy.size),
      ] });
  }
  for (let i = 0; i < layout.card.count; i++) {
    const card = layout.card, cell = [i % card.columns, Math.floor(i / card.columns)];
    controls.push({ name: `card${i + 1}`, kind: 'container',
      position: card.origin.map((value, axis) => value + cell[axis] * card.step[axis]), size: [...card.size], children: [
        plate('plate', centred(card.size), color.panel), text('label', centred(card.labelSize)), hit(card.size),
      ] });
  }
  const action = (name, label) => button(name, layout[name], label,
    { inset: layout.buttonInset, fontSize: font.number, colour: color.gold });
  controls.push(action('endTurn', '结束回合'), action('start', '启程'), action('continue', '再战一场'),
    text('result', layout.result, '', font.heading, color.gold), action('skip', '跳过奖励'));
  return { name: 'AbyssBattle', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true, controls };
}
