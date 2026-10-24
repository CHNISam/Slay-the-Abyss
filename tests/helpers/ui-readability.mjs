// Semantic text groups only: decorative frames, images, hit areas and the
// deliberately overlapping status-detail rows do not belong to this contract.
export const visibleText = nodes => nodes.filter(node => node.kind === 'text' && node.visible && node.text.trim());
export function intersects(a, b) {
  return Math.abs(a[0] - b[0]) < (a[2] + b[2]) / 2 - 0.01 &&
    Math.abs(a[1] - b[1]) < (a[3] + b[3]) / 2 - 0.01;
}
export function textConflicts(nodes, role) {
  const selected = visibleText(nodes).map(node => ({ ...node, role: role(node.path) })).filter(node => node.role);
  const conflicts = [];
  for (let i = 0; i < selected.length; i++) for (let j = i + 1; j < selected.length; j++) {
    const a = selected[i], b = selected[j];
    // Individual card internals have their own approved layout. Compare cards
    // to headers/feedback/actions, not their overlapping transparent text frames.
    if (a.role === 'card' && b.role === 'card' || a.role === 'actor' && b.role === 'actor') continue;
    if (intersects(a.rect, b.rect)) conflicts.push(`${a.path} ${JSON.stringify(a.rect)} intersects ${b.path} ${JSON.stringify(b.rect)}`);
  }
  return conflicts;
}
export function capacityProblems(nodes, lineHeight = 40) {
  return visibleText(nodes).flatMap(node => {
    // Auto-size may reduce the configured font to its declared minimum. A
    // Chinese glyph occupies at most one em; ASCII needs only 0.6 em here.
    // This is a text-box budget, not a claim about the native font's ink.
    const font = node.minimum || node.font;
    const rows = node.text.split('\n').reduce((sum, line) => {
      const ems = [...line].reduce((n, ch) => n + (ch.codePointAt(0) > 0xff ? 1 : 0.6), 0);
      return sum + Math.max(1, Math.ceil(ems * font / node.size[0]));
    }, 0);
    return rows * lineHeight <= node.size[1] + 0.01 ? [] :
      [`${node.path}: ${JSON.stringify(node.text)} needs ${rows} native lines (${rows * lineHeight}), box height ${node.size[1]}`];
  });
}
export function rewardRole(path) {
  if (/^\/battlePanel\/(rewardStage|rewardList)\/(title|subtitle)$/.test(path)) return 'header';
  if (/^\/battlePanel\/(notice|potionReward)$/.test(path)) return 'feedback';
  if (/^\/battlePanel\/(goldReward|cardReward|claimPotion|stolenGold|skip|skipPotion|continue)\/.*(label|description|title)$/.test(path)) return 'action';
  if (/^\/battlePanel\/card\d+\/(name|type|label|cost)$/.test(path)) return 'card';
  return null;
}
export function adjacentRole(path) {
  if (/^\/menuPanel\/(title|tagline|summary|result\/(subtitle|detail|status))$/.test(path) ||
      /^\/menuPanel\/(start|settle)\/.*label$/.test(path)) return 'menu';
  if (/^\/mapPanel\/mapGroup\d+\/(title|notice)$/.test(path)) return 'map';
  if (/^\/nodePanel\/(title|notice|campView\/(rest|forge)\/(name|description))$/.test(path)) return 'node';
  if (/^\/battlePanel\/(title|notice)$/.test(path)) return 'battle';
  // Actor name/HP use transparent 40-high native frames at a smaller pitch.
  // Their glyph lines do not collide; only compare them with page feedback.
  if (/^\/battlePanel\/(hero\/(name|hp)|enemy\d+\/(name|hp|intent|intentLabel))$/.test(path)) return 'actor';
  return null;
}
