// Shared native-control tree. All interactive content fits the 1280 x 720 phone canvas.
const ink = '#ede4cc', gold = '#d6b772';
const text = (name, x, y, w, h, content = '', fontSize = 20, colour = ink) => ({
  name, kind: 'text', position: [x, y], size: [w, h],
  text: { content, fontSize, colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: 12 },
});
const panel = (name, x, y, w, h, colour) => ({ name, kind: 'image', position: [x, y], size: [w, h], image: 100001, colour });
const hit = (name, w, h) => ({ name, kind: 'cursorArea', size: [w, h], focusable: true });
const button = (name, x, y, w, h, label) => ({ name, kind: 'container', position: [x, y], size: [w, h], children: [
  panel('plate', 0, 0, w, h, '#433c30'), text('label', 0, 0, w - 8, h - 4, label, 22, gold), hit('hit', w, h),
] });

export function battleLayout() {
  const controls = [panel('backdrop', 0, 0, 1260, 700, '#171f26'),
    text('title', 0, 313, 1160, 44, '杀戮深渊 · 旅行者', 30, gold),
    text('player', -230, 265, 700, 42), text('piles', 380, 265, 400, 42),
    text('notice', 0, 58, 1130, 46, '先选择敌人，再点击手牌；结束回合后敌人按意图行动。', 20),
    text('statuses', 0, 17, 1140, 35, '', 17),
  ];
  for (let i = 1; i <= 5; i++) controls.push({ name: `enemy${i}`, kind: 'container',
    position: [-472 + (i - 1) * 236, 165], size: [220, 140], children: [
      panel('plate', 0, 0, 220, 140, '#303a40'), text('label', 0, 0, 208, 132, '', 18), hit('hit', 220, 140),
    ] });
  for (let i = 1; i <= 10; i++) controls.push({ name: `card${i}`, kind: 'container',
    position: [-464 + ((i - 1) % 5) * 232, -80 - Math.floor((i - 1) / 5) * 151], size: [218, 140], children: [
      panel('plate', 0, 0, 218, 140, '#38443e'), text('label', 0, 0, 204, 132, '', 19), hit('hit', 218, 140),
    ] });
  controls.push(button('endTurn', 438, -326, 250, 44, '结束回合'),
    button('start', 0, -70, 320, 60, '启程'),
    button('continue', 0, -250, 320, 60, '再战一场'),
    text('result', 0, 168, 1110, 130, '', 26, gold),
    button('skip', 0, -326, 250, 44, '跳过奖励'));
  return { name: 'AbyssBattle', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true, controls };
}
